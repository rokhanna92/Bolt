import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/bolt_store.dart';
import '../data/models/bolt_data.dart';
import '../widgets/bolt_nav_bar.dart';
import '../widgets/common.dart';
import 'actions.dart';

/// Tab scaffold for one role: the active tab plus the bottom nav. Tabs keep
/// their state; switching replays the screen-enter fade.
class BoltShell extends ConsumerWidget {
  const BoltShell({super.key, required this.shell, required this.role});

  final StatefulNavigationShell shell;
  final Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final id = d.account?.id ?? '';
    final trainee = role == Role.trainee;
    final name = trainee
        ? (ref.read(boltProvider.notifier).trOrNull(id)?.name ?? '')
        : ref.read(boltProvider.notifier).co(id).name;
    final items = trainee
        ? [
            NavItem(label: tx('Today'), icon: 'barbell'),
            NavItem(label: tx('Plan'), icon: 'calendar'),
            NavItem(label: tx('Atlas'), icon: 'book'),
            NavItem(label: tx('Me'), initials: initials(name)),
          ]
        : [
            NavItem(label: tx('Trainees'), icon: 'group', pillWidth: 56),
            NavItem(label: tx('Schedule'), icon: 'schedule'),
            NavItem(label: tx('Library'), icon: 'plate', pillWidth: 56),
            NavItem(label: tx('Profile'), initials: initials(name), pillWidth: 56),
          ];
    // Trainee branches: today, plan, gym, learn, me. Coach branches: roster,
    // schedule, library, profile, calendar. The gym and the calendar have no
    // tab of their own; the centre button opens them.
    final branchOf = trainee ? const [0, 1, 3, 4] : const [0, 1, 2, 3];
    final centre = trainee ? 2 : 4;
    final active = branchOf.indexOf(shell.currentIndex);
    return BoltPage(
      child: Stack(
        children: [
          Positioned.fill(
            child: _TabFade(index: shell.currentIndex, child: shell),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BoltNavBar(
              items: items,
              active: active,
              scanActive: shell.currentIndex == centre,
              centerIcon: trainee ? 'scan' : 'calendar',
              centerLabel: trainee ? null : tx('Calendar'),
              onTap: (i) {
                if (branchOf[i] != shell.currentIndex) HapticFeedback.selectionClick();
                shell.goBranch(branchOf[i], initialLocation: branchOf[i] == shell.currentIndex);
              },
              onScan: trainee ? () => openScanner(context, ref) : () => shell.goBranch(centre),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabFade extends StatefulWidget {
  const _TabFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Transform.translate(offset: Offset(0, 8 * (1 - _a.value)), child: child),
        child: widget.child,
      ),
    );
  }
}
