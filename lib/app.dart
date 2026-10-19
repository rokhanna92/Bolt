import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/actions.dart';
import 'app/router.dart';
import 'core/format.dart';
import 'data/bolt_store.dart';
import 'data/level.dart';
import 'data/models/session.dart';
import 'data/rules.dart';
import 'features/progress/recovery_card.dart' show readyMuscles;
import 'services/home_widget.dart';
import 'services/notice_board.dart';
import 'services/shortcuts.dart';
import 'theme/bolt_theme.dart';
import 'widgets/toast.dart';

class BoltApp extends ConsumerStatefulWidget {
  const BoltApp({super.key});

  @override
  ConsumerState<BoltApp> createState() => _BoltAppState();
}

class _BoltAppState extends ConsumerState<BoltApp> with WidgetsBindingObserver {
  Timer? _minute;
  Timer? _widgetDebounce;
  DateTime? _boardAt;

  /// The owner's notices.json: reminder times and pushes. Read when Bolt
  /// opens and again on return after a quarter of an hour.
  Future<void> _refreshBoard() async {
    final last = _boardAt;
    if (last != null && DateTime.now().difference(last).inMinutes < 15) return;
    _boardAt = DateTime.now();
    final b = await ref.read(noticeBoardProvider).fetch();
    if (b != null && mounted) ref.read(boltProvider.notifier).applyBoard(b);
  }

  /// What the home screen widget shows: today's workout or rest day, the
  /// gym clock while checked in, level and streak. From 3 days off it turns
  /// orange; the days-off line goes ahead a week so it shows even when Bolt
  /// stays closed.
  void _pushWidget() {
    final d = ref.read(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final a = d.account;
    final today = store.today;
    var kicker = tx('TODAY'), title = 'Bolt', sub = '', footer = '';
    final off = <String, Object?>{};
    if (a != null && a.isTrainee) {
      final t = store.trOrNull(a.id);
      final plan = t == null ? const <String, Session>{} : store.plan(t.id);
      final s = plan[today];
      if (s == null || s.status == SessionStatus.draft) {
        title = tx('REST DAY');
      } else {
        title = tx(s.title);
        sub = s.status == SessionStatus.done
            ? tx('Logged · {log}', {'log': logText(s.log)})
            : '${plural(s.ex.length, 'exercise')} · ${plural(s.totalSets, 'set')}';
      }
      if (t != null) {
        footer =
            '${tx('LVL')} ${levelOf(xpOf(t.stats)).level} · ${tx('Streak {n}', {'n': plural(currentStreak(t.stats, store.now), 'week')})}';
        final visits = d.visits[t.id] ?? const [];
        for (var i = -7; i <= 7; i++) {
          final day = addDays(store.now, i);
          final n = i < 0 || d.gymIn[a.id] != null || t.stats.away.contains(dk(monday(day)))
              ? 0
              : daysOff(plan, visits, t.stats.rest, day);
          off['off_${dk(day)}'] = n >= 3 ? tx('{days} OFF', {'days': plural(n, 'day').toUpperCase()}) : null;
        }
        if (off['off_$today'] case final String k) {
          kicker = k;
          if (s == null || s.status == SessionStatus.draft) title = tx('TRAIN TODAY');
          final ready = readyMuscles(plan, today);
          if (ready.isNotEmpty) sub = tx('Fully recovered: {muscles}.', {'muscles': ready.join(', ')});
        }
      }
    } else if (a != null) {
      kicker = tx('TRAINEES');
      title = plural(d.trainees.where((x) => x.id != a.id).length, 'trainee');
    }
    HomeWidget.update({
      'date': today,
      'kicker': kicker,
      'title': title,
      'sub': sub,
      'footer': footer,
      'scan': tx('SCAN'),
      'stale': tx("Open Bolt for today's plan"),
      'gymSince': d.gymIn[a?.id]?.checkInTime().millisecondsSinceEpoch ?? 0,
      'offTitle': tx('TRAIN TODAY'),
      ...off,
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final store = ref.read(boltProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.autoCloseStale();
      // Saves from before levels start counting where they stand.
      if (ref.read(boltProvider).settings.levelSeen == null) store.levelUp();
      // A rank that rose since last time, from an update or a backup, gets
      // its moment; a save from before ranks only remembers where it stands.
      if (ref.read(boltProvider).settings.rankSeen == null) {
        store.rankUp();
      } else {
        showRankUp();
      }
      store.syncSessionReminders();
      store.syncBroadcasts();
      store.syncGymTimer();
      _refreshBoard();
      AppShortcuts.listen(openShortcut);
      _pushWidget();
    });
    // Keep the home screen widget in step with every change.
    ref.listenManual(boltProvider, (_, _) {
      _widgetDebounce?.cancel();
      _widgetDebounce = Timer(const Duration(milliseconds: 600), _pushWidget);
    });
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => store.autoCloseStale());
  }

  @override
  void dispose() {
    _minute?.cancel();
    _widgetDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(repositoryProvider).flush();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(boltProvider.notifier).autoCloseStale();
      _refreshBoard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: tx('Bolt'),
      debugShowCheckedModeBanner: false,
      theme: buildBoltTheme(),
      routerConfig: ref.watch(routerProvider),
      // The layout is pixel-tuned to the prototype; allow larger system text
      // but cap it so fixed-size controls keep their shape.
      // A language change rebuilds every screen, constant widgets included.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(ref.watch(boltProvider.select((d) => d.settings.lang))),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: Stack(children: [child!, const ToastLayer()]),
        ),
      ),
    );
  }
}
