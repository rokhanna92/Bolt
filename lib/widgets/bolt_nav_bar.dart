import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/tick.dart';
import '../core/format.dart';
import '../data/bolt_store.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'common.dart';
import 'tap.dart';

class NavItem {
  const NavItem({required this.label, this.icon, this.initials, this.pillWidth = 52});

  final String label;
  final String? icon;

  /// Shown in a small ring instead of an icon (Me / Profile).
  final String? initials;
  final double pillWidth;
}

/// Five-slot bottom nav with the raised neon button in the middle: the gym
/// scanner for people who train, the calendar for coaches.
class BoltNavBar extends ConsumerWidget {
  const BoltNavBar({
    super.key,
    required this.items,
    required this.active,
    required this.onTap,
    required this.onScan,
    this.scanActive = false,
    this.centerIcon = 'scan',
    this.centerLabel,
  });

  /// Four tabs; the scan button sits between the second and third.
  final List<NavItem> items;

  /// Index into [items], or -1 when no tab is highlighted.
  final int active;
  final ValueChanged<int> onTap;
  final VoidCallback onScan;

  /// The centre button's screen is open (gym or calendar).
  final bool scanActive;
  final String centerIcon;

  /// Fixed label; null shows "Check in" or the time in the gym.
  final String? centerLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 84 + bottom,
      padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [BoltColors.ink, BoltColors.ink, Color(0x000A0B09)],
          stops: [0, .7, 1],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _tab(0)),
          Expanded(child: _tab(1)),
          Expanded(
            child: _ScanSlot(onTap: onScan, highlighted: scanActive, icon: centerIcon, fixedLabel: centerLabel),
          ),
          Expanded(child: _tab(2)),
          Expanded(child: _tab(3)),
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final it = items[i];
    final on = active == i;
    final c = on ? BoltColors.neon : BoltColors.muted;
    return Tap(
      onTap: () => onTap(i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: it.pillWidth,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? const Color(0x24C6FF1A) : const Color(0x00C6FF1A),
              borderRadius: BorderRadius.circular(99),
            ),
            child: it.initials != null
                ? Container(
                    width: 25.6,
                    height: 25.6,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c, width: 1.8),
                    ),
                    child: Text(it.initials!, style: BoltText.a(8, weight: 900, color: c, height: 1)),
                  )
                : BoltIcon(it.icon!, color: c),
          ),
          const SizedBox(height: 4),
          Text(
            it.label,
            maxLines: 1,
            softWrap: false,
            style: BoltText.a(11, weight: 700, color: on ? BoltColors.text : BoltColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ScanSlot extends ConsumerWidget {
  const _ScanSlot({required this.onTap, required this.highlighted, required this.icon, this.fixedLabel});

  final VoidCallback onTap;
  final bool highlighted;
  final String icon;
  final String? fixedLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(boltProvider.select((d) => d.account?.id));
    final g = ref.watch(boltProvider).gymIn[id];
    final label = fixedLabel ?? (g == null ? tx('Check in') : dur(g.elapsedMinutes(watchNow(ref))));
    return Tap(
      onTap: onTap,
      scale: .92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // In the prototype the button is pulled up 18 px with a negative
          // margin; laying out its full height lands it in the same spot.
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: BoltColors.neon,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x59C6FF1A), blurRadius: 24, offset: Offset(0, 6))],
            ),
            child: BoltIcon(icon, size: 26, color: BoltColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: BoltText.m(
              10,
              weight: 700,
              color: highlighted || (fixedLabel == null && g != null) ? BoltColors.text : BoltColors.muted,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
