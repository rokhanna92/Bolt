import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/bolt_store.dart';
import '../core/units.dart';
import '../data/level.dart';
import '../data/rank.dart';
import '../data/rules.dart';
import '../data/models/bolt_data.dart';
import '../data/models/session.dart';
import '../features/badges/unlock_overlay.dart';
import '../features/gym/scanner_overlay.dart';
import '../features/learn/exercise_sheet.dart';
import '../features/plan/day_sheet.dart';
import '../features/profile/injury_sheet.dart';
import '../features/rank/rank_screen.dart';
import '../features/workouts/muscle_builder.dart';
import '../features/workouts/split_sheet.dart';
import '../features/workouts/workout_picker.dart';
import '../widgets/bolt_sheet.dart';
import '../services/haptics.dart';
import '../widgets/moment_overlay.dart';
import '../widgets/rank_emblem.dart';
import 'router.dart';
import 'ui_state.dart';

NavigatorState get _root => rootNavigatorKey.currentState!;

/// Centre button: trainees land on the gym screen, then the scanner opens.
/// [manual] checks in or out straight away, without the camera.
void openScanner(BuildContext context, WidgetRef ref, {bool fromShortcut = false, bool manual = false}) {
  if (ref.read(boltProvider).account?.isTrainee ?? false) {
    ref.read(moveFromProvider.notifier).set(null);
    context.go('/gym');
  }
  _root.push(ScannerRoute(fromShortcut: fromShortcut, manual: manual));
}

/// The quick screen's fast workout: an engine day built on the spot for
/// cardio, the muscle builder for weights. Either lands on today and opens.
Future<void> startFastWorkout({required bool cardio}) async {
  final store = _store;
  final k = store.today;
  if (cardio) {
    final ex = workoutForMuscles(const ['cardio'], math.Random());
    await showUnlocks(store.useMuscles(Account.ownerId, k, const ['cardio'], ex));
  } else {
    final b = await _buildFromMuscles();
    if (b == null) return;
    await showUnlocks(store.useMuscles(Account.ownerId, k, b.muscles, b.ex, save: b.save));
  }
  openWorkout(k);
}

/// The app icon's long-press shortcuts: scan the plaque, today's workout or
/// gym time. Ignored before onboarding and on coach screens.
void openShortcut(String what) {
  final context = rootNavigatorKey.currentContext;
  final a = _container.read(boltProvider).account;
  if (context == null || a == null || !a.isTrainee) return;
  _container.read(moveFromProvider.notifier).set(null);
  switch (what) {
    case 'scan':
      context.go('/gym');
      _root.push(ScannerRoute(fromShortcut: true));
    case 'workout':
      final store = _store;
      final k = store.today;
      final s = store.plan(a.id)[k];
      context.go('/today');
      // Nothing to start (rest day, waiting for OK, done): Today shows why.
      if (s != null && (s.status == SessionStatus.approved || s.status == SessionStatus.moved)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => openWorkout(k));
      }
    case 'gym':
      context.go('/gym');
  }
}

/// Badge unlocks on one overlay, then a new level if there is one.
Future<void> showUnlocks(List<String> ids) async {
  if (ids.isNotEmpty) await _root.push(UnlockRoute(ids));
  final l = _store.levelUp();
  if (l != null) await _root.push(MomentRoute(levelMoment(l)));
  await showRankUp();
}

/// The level-up moment: the level and what the next one takes.
Moment levelMoment(int l) => Moment(
  kicker: tx('LEVEL UP'),
  big: '$l',
  unit: tx('LEVEL'),
  title: tx('ATHLETE LEVEL'),
  sub: tx('{n} XP to level {next}.', {'n': xpToNext(l), 'next': l + 1}),
);

/// A new rank, when a workout or a new max lifts it: the emblem, confetti
/// and what the next division takes.
Future<void> showRankUp() async {
  final step = _store.rankUp();
  if (step == null) return;
  final d = _container.read(boltProvider);
  final t = _store.tr(d.account!.id);
  final next = nextStep(rankOf(t, _store.plan(t.id)), t.body);
  await _root.push(
    MomentRoute(
      Moment(
        kicker: tx('RANK UP'),
        big: '',
        art: RankEmblem(step: step, size: 150),
        unit: '',
        title: rankText(step),
        feel: Feel.record,
        confetti: true,
        sub: step >= kAtlas
            ? tx('Atlas. Maybe once in a thousand years. There is nothing above this.')
            : next == null
            ? tx('No single lift gets you there now: raise all three together.')
            : tx('Next: {rank} · +{kg} on {lift}', {
                'rank': rankText(step + 1),
                'kg': fmtWeight(next.$2, metric: d.settings.kg),
                'lift': tx(next.$1),
              }),
      ),
    ),
  );
}

void showDaySheet(String k) => showBoltSheet<void>(_root.context, (_) => DaySheet(dayKey: k));

/// Switch to Plan on [k]'s month and open its day sheet.
void openPlanDay(BuildContext context, WidgetRef ref, String? k) {
  if (k != null) ref.read(planMonthProvider.notifier).set(pk(k));
  context.go('/plan');
  if (k != null) WidgetsBinding.instance.addPostFrameCallback((_) => showDaySheet(k));
}

void showExerciseSheet(String name) =>
    showBoltSheet<void>(_root.context, (_) => ExerciseSheet(name: name), maxHeight: .84);

void showInjurySheet(String tid) => showBoltSheet<void>(_root.context, (_) => InjurySheet(tid: tid));

/// Day [k]'s workout page: its exercises and weights with a big START, or
/// the sets when it is already going.
void openWorkout(String k) => _root.context.push('/workout/$k');

ProviderContainer get _container => ProviderScope.containerOf(_root.context, listen: false);
BoltStore get _store => _container.read(boltProvider.notifier);

Future<MuscleBuild?> _buildFromMuscles({bool libraryOnly = false, String? forName}) => showBoltSheet<MuscleBuild>(
  _root.context,
  (_) => MuscleBuilderSheet(libraryOnly: libraryOnly, forName: forName),
  maxHeight: .92,
);

/// Change the workout on a planned day: any template, or one built from
/// muscles on the spot.
Future<void> changeDayWorkout(String tid, String k) async {
  final store = _store;
  final s = store.plan(tid)[k];
  final pick = await showBoltSheet<String>(_root.context, (_) => WorkoutPickerSheet(selected: s?.tpl), maxHeight: .92);
  if (pick == null) return;
  if (pick != PickResult.muscles) {
    await showUnlocks(store.setTemplate(tid, k, pick));
    return;
  }
  final own = tid == Account.ownerId;
  final b = await _buildFromMuscles(forName: own ? null : firstName(store.tr(tid).name));
  if (b != null) await showUnlocks(store.useMuscles(tid, k, b.muscles, b.ex, save: b.save));
}

/// Library: build a template from muscles and open it in the editor.
Future<void> newTemplateFromMuscles() async {
  final b = await _buildFromMuscles(libraryOnly: true);
  if (b == null) return;
  final id = _store.templateFromMuscles(b.muscles, b.ex);
  _store.toast(tx('Saved to your Library'));
  rootNavigatorKey.currentContext!.push('/editor/tpl/$id');
}

/// Split editor: the workout for weekday [wd], a rest day, or a new one from
/// muscles saved to the Library.
Future<void> pickSplitDay(String splitId, int wd) async {
  final store = _store;
  final cur = _container.read(boltProvider).splits[splitId]?.days[wd];
  final pick = await showBoltSheet<String>(
    _root.context,
    (_) => WorkoutPickerSheet(selected: cur, rest: true),
    maxHeight: .92,
  );
  if (pick == null) return;
  if (pick == PickResult.rest) return store.setSplitDay(splitId, wd, null);
  if (pick != PickResult.muscles) return store.setSplitDay(splitId, wd, pick);
  final b = await _buildFromMuscles(libraryOnly: true);
  if (b != null) store.setSplitDay(splitId, wd, store.templateFromMuscles(b.muscles, b.ex));
}

void showSplitSheet(String tid) => showBoltSheet<void>(_root.context, (_) => SplitSheet(tid: tid), maxHeight: .92);
