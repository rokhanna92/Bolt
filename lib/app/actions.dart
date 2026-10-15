import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/bolt_store.dart';
import '../data/models/bolt_data.dart';
import '../features/badges/unlock_overlay.dart';
import '../features/gym/scanner_overlay.dart';
import '../features/learn/exercise_sheet.dart';
import '../features/plan/day_sheet.dart';
import '../features/profile/injury_sheet.dart';
import '../features/workouts/muscle_builder.dart';
import '../features/workouts/split_sheet.dart';
import '../features/workouts/workout_picker.dart';
import '../widgets/bolt_sheet.dart';
import 'router.dart';
import 'ui_state.dart';

NavigatorState get _root => rootNavigatorKey.currentState!;

/// Centre button: trainees land on the gym screen, then the scanner opens.
void openScanner(BuildContext context, WidgetRef ref) {
  if (ref.read(boltProvider).account?.isTrainee ?? false) {
    ref.read(moveFromProvider.notifier).set(null);
    context.go('/gym');
  }
  _root.push(ScannerRoute());
}

/// Badge unlock overlays, one after another.
Future<void> showUnlocks(List<String> ids) async {
  for (final id in ids) {
    await _root.push(UnlockRoute(id));
  }
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

void startWorkout(BuildContext context, WidgetRef ref, String k) {
  ref.read(boltProvider.notifier).startWorkout(k);
  context.push('/workout/$k');
}

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
  _store.toast('Saved to your Library');
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
