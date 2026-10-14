import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/bolt_store.dart';
import '../features/badges/unlock_overlay.dart';
import '../features/gym/scanner_overlay.dart';
import '../features/learn/exercise_sheet.dart';
import '../features/plan/day_sheet.dart';
import '../features/profile/injury_sheet.dart';
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
