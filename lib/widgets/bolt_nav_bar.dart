import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// scanner for people who train, the calendar for coaches. Icons only; the
/// labels are read out to screen readers.
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

  /// Fixed label for screen readers; null says check in or scan out.
  final String? centerLabel;

  /// Solid strip under the icons, above the safe area.
  static const height = 52.0;

  /// Fade above the strip; taps pass through it to the page.
  static const _fade = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: height + _fade + bottom,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height + bottom,
            child: const ColoredBox(color: BoltColors.ink),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _fade,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [BoltColors.ink, Color(0x000A0B09)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: bottom,
            height: height,
            child: Row(
              children: [
                Expanded(child: _tab(0)),
                Expanded(child: _tab(1)),
                const Spacer(),
                Expanded(child: _tab(2)),
                Expanded(child: _tab(3)),
              ],
            ),
          ),
          // The raised button sits a little above the icons.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 6,
            child: Center(
              child: _ScanSlot(onTap: onScan, highlighted: scanActive, icon: centerIcon, fixedLabel: centerLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final it = items[i];
    final on = active == i;
    final c = on ? BoltColors.neon : BoltColors.muted;
    return Semantics(
      label: it.label,
      selected: on,
      child: Tap(
        onTap: () => onTap(i),
        child: Center(
          child: AnimatedContainer(
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
        ),
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
    final inGym = ref.watch(boltProvider.select((d) => d.gymIn[d.account?.id] != null));
    final label = fixedLabel ?? (inGym ? tx('Tap to scan out') : tx('Check in'));
    return Semantics(
      label: label,
      selected: highlighted,
      child: Tap(
        onTap: onTap,
        scale: .92,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BoltColors.neon,
            borderRadius: BorderRadius.circular(20),
            // Glows brighter while its screen is open.
            boxShadow: [
              BoxShadow(
                color: highlighted ? const Color(0x99C6FF1A) : const Color(0x59C6FF1A),
                blurRadius: highlighted ? 30 : 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: BoltIcon(icon, size: 26, color: BoltColors.ink),
        ),
      ),
    );
  }
}
