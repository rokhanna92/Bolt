import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/bolt_store.dart';
import '../data/models/bolt_data.dart';
import '../features/admin/admin_screen.dart';
import '../features/badges/badges_screen.dart';
import '../features/coach_calendar/calendar_screen.dart';
import '../features/coach_profile/coach_profile_screen.dart';
import '../features/coach_roster/roster_screen.dart';
import '../features/coach_schedule/schedule_screen.dart';
import '../features/coach_trainee/trainee_detail_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/gym/gym_screen.dart';
import '../features/key/key_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/library/library_screen.dart';
import '../features/measurements/measurements_screen.dart';
import '../features/progress/history_screen.dart';
import '../features/progress/lift_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/progress/wrap_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/plaque/plaque_screen.dart';
import '../features/plates/plate_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/me_screen.dart';
import '../features/rank/rank_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/today/today_screen.dart';
import '../features/workout/summary_screen.dart';
import '../features/workout/workout_screen.dart';
import '../features/workouts/split_editor_screen.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// The editor, plaque, Atlas (/guide) and settings are shared: solo users and
// trainees plan for themselves too. Their Library is the /workouts tab.
const _traineeOnly = {'today', 'plan', 'gym', 'workouts', 'badges', 'me', 'workout', 'wrap', 'history', 'rank'};
const _coachOnly = {'roster', 'schedule', 'profile', 'trainee', 'calendar'};

/// Pushed screens: fade in and rise 10 px (350 ms, easeOut).
Page<void> _enter(GoRouterState state, Widget child) => CustomTransitionPage<void>(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 350),
  reverseTransitionDuration: const Duration(milliseconds: 250),
  transitionsBuilder: (context, animation, secondary, child) {
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, c) => Transform.translate(offset: Offset(0, 10 * (1 - a.value)), child: c),
        child: child,
      ),
    );
  },
);

Page<void> _tab(GoRouterState state, Widget child) => NoTransitionPage<void>(key: state.pageKey, child: child);

final routerProvider = Provider<GoRouter>((ref) {
  // Bumped whenever the owner, their role or the key gate changes, so the
  // redirect below runs again. The data itself is mutated in place, so a
  // counter is what changes, not the account object.
  final auth = ValueNotifier<int>(0);
  ref.listen(boltProvider.select((d) => (d.account?.role, d.account?.id, d.settings.keyGen)), (_, _) {
    auth.value++;
  });
  ref.onDispose(auth.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final a = ref.read(boltProvider).account;
      final loc = state.matchedLocation;
      if (a == null) return loc == '/welcome' ? null : '/welcome';
      if (ref.read(boltProvider.notifier).needsKey) return loc == '/key' ? null : '/key';
      if (loc == '/key') return a.isTrainee ? '/today' : '/roster';
      final home = a.isTrainee ? '/today' : '/roster';
      if (loc == '/' || loc == '/welcome') return home;
      final seg = state.uri.pathSegments.isEmpty ? '' : state.uri.pathSegments.first;
      if (a.isTrainee && _coachOnly.contains(seg)) return home;
      if (!a.isTrainee && _traineeOnly.contains(seg)) return home;
      if (seg == 'admin' && !a.admin) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/welcome'),
      GoRoute(
        path: '/key',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const KeyScreen(),
          transitionsBuilder: (context, a, s, child) => FadeTransition(opacity: a, child: child),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionsBuilder: (context, a, s, child) => FadeTransition(opacity: a, child: child),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BoltShell(shell: shell, role: Role.trainee),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/today', pageBuilder: (c, s) => _tab(s, const TodayScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/plan', pageBuilder: (c, s) => _tab(s, const PlanScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/gym', pageBuilder: (c, s) => _tab(s, const GymScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/workouts', pageBuilder: (c, s) => _tab(s, const LibraryScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/me', pageBuilder: (c, s) => _tab(s, const MeScreen()))],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => BoltShell(shell: shell, role: Role.coach),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/roster', pageBuilder: (c, s) => _tab(s, const RosterScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/schedule', pageBuilder: (c, s) => _tab(s, const ScheduleScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/library', pageBuilder: (c, s) => _tab(s, const LibraryScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', pageBuilder: (c, s) => _tab(s, const CoachProfileScreen()))],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/calendar', pageBuilder: (c, s) => _tab(s, const CoachCalendarScreen()))],
          ),
        ],
      ),
      GoRoute(
        path: '/workout/:key',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, WorkoutScreen(dayKey: s.pathParameters['key']!)),
      ),
      GoRoute(
        path: '/trainee/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, TraineeDetailScreen(tid: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/editor/tpl/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, EditorScreen(target: TemplateTarget(s.pathParameters['id']!))),
      ),
      GoRoute(
        path: '/editor/day/:tid/:key',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) =>
            _enter(s, EditorScreen(target: DayTarget(s.pathParameters['tid']!, s.pathParameters['key']!))),
      ),
      GoRoute(
        path: '/summary/:key',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, SummaryScreen(dayKey: s.pathParameters['key']!)),
      ),
      GoRoute(
        path: '/progress',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const ProgressScreen()),
      ),
      GoRoute(
        path: '/wrap',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, WrapScreen(season: int.tryParse(s.uri.queryParameters['season'] ?? ''))),
      ),
      GoRoute(
        path: '/lift/:name',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) =>
            _enter(s, LiftScreen(name: s.pathParameters['name']!, tid: s.uri.queryParameters['tid'])),
      ),
      GoRoute(
        path: '/admin',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const AdminScreen()),
      ),
      GoRoute(
        path: '/rank',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const RankScreen()),
      ),
      GoRoute(
        path: '/history',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, HistoryScreen(tpl: s.uri.queryParameters['tpl'])),
      ),
      GoRoute(
        path: '/measurements',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const MeasurementsScreen()),
      ),
      GoRoute(
        path: '/measurements/:tid',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, MeasurementsScreen(tid: s.pathParameters['tid'])),
      ),
      GoRoute(
        path: '/split/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, SplitEditorScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/guide',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const LearnScreen()),
      ),
      GoRoute(
        path: '/badges',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const BadgesScreen()),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const SettingsScreen()),
      ),
      GoRoute(
        path: '/plates',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, PlateScreen(kg: double.tryParse(s.uri.queryParameters['kg'] ?? ''))),
      ),
      GoRoute(
        path: '/plaque',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const PlaqueScreen()),
      ),
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/edit-profile/:tid',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _enter(s, EditProfileScreen(tid: s.pathParameters['tid'])),
      ),
    ],
  );
});
