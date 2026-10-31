import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models/session.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'box.dart';
import 'motion.dart';
import 'tap.dart';

/// Page root: ink background, light status bar, Material ancestor for text.
/// Content that scrolls up passes under [StatusScrim], not under the clock.
class BoltPage extends StatelessWidget {
  const BoltPage({super.key, required this.child, this.color = BoltColors.ink, this.scrim = true});

  final Widget child;
  final Color color;

  /// False for pages that place their own [StatusScrim].
  final bool scrim;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Material(
        color: color,
        child: scrim
            ? Stack(
                children: [
                  Positioned.fill(child: child),
                  StatusScrim(color: color),
                ],
              )
            : child,
      ),
    );
  }
}

/// The page color behind the status bar, fading out just below it.
class StatusScrim extends StatelessWidget {
  const StatusScrim({super.key, this.color = BoltColors.ink});

  final Color color;

  static const _fade = 14.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top == 0) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: top + _fade,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, top / (top + _fade), 1],
              colors: [color, color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable screen body with the prototype's padding (20 sides, 20 top,
/// 92 bottom to clear the nav) below the status bar.
class ScreenScroll extends StatefulWidget {
  const ScreenScroll({
    super.key,
    required this.children,
    this.top = 20,
    this.bottom = 92,
    this.controller,
    this.stagger = false,
  });

  final List<Widget> children;
  final double top;
  final double bottom;
  final ScrollController? controller;

  /// Cards rise in one after another when the screen first shows. Cards
  /// that come later appear in place.
  final bool stagger;

  @override
  State<ScreenScroll> createState() => _ScreenScrollState();
}

class _ScreenScrollState extends State<ScreenScroll> {
  late bool _intro = widget.stagger;

  @override
  void initState() {
    super.initState();
    if (_intro) WidgetsBinding.instance.addPostFrameCallback((_) => _intro = false);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    var k = 0;
    return SingleChildScrollView(
      controller: widget.controller,
      padding: EdgeInsets.fromLTRB(20, pad.top + widget.top, 20, widget.bottom + pad.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.stagger
            ? [
                for (final c in widget.children)
                  FadeSlideIn(
                    play: _intro,
                    delay: Duration(milliseconds: 40 * math.min(c is SizedBox ? k : k++, 5)),
                    child: c,
                  ),
              ]
            : widget.children,
      ),
    );
  }
}

/// Small uppercase mono label, e.g. "PLAN", "GYM TIME".
class Kicker extends StatelessWidget {
  const Kicker(
    this.text, {
    super.key,
    this.size = 11,
    this.color = BoltColors.muted,
    this.spacing = .12,
    this.weight = 400,
    this.maxLines,
  });

  final String text;
  final double size;
  final Color color;
  final double spacing;
  final double weight;

  /// Cuts the label with an ellipsis instead of wrapping when set.
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
    style: BoltText.m(size, color: color, spacing: spacing, weight: weight),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.size = 17});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text, style: BoltText.a(size, weight: 800));
}

/// Square outlined icon button: back, prev/next, settings.
class SquareButton extends StatelessWidget {
  const SquareButton({
    super.key,
    required this.onTap,
    this.label,
    this.child,
    this.size = 40,
    this.radius = 12,
    this.fontSize = 18,
  });

  final VoidCallback onTap;
  final String? label;
  final Widget? child;
  final double size;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: BoltBox(
        width: size,
        height: size,
        radius: radius,
        stroke: const Stroke(BoltColors.line),
        alignment: Alignment.center,
        child: child ?? Text(label ?? '', style: BoltText.a(fontSize, color: BoltColors.text, height: 1)),
      ),
    );
  }
}

class BackBox extends StatelessWidget {
  const BackBox({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SquareButton(onTap: onTap, label: '‹', size: 42, fontSize: 20);
}

/// Initials in a circle, filled neon or outlined.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.ini,
    this.size = 44,
    this.fontSize = 14,
    this.fill,
    this.ring,
    this.ringWidth = 1.5,
    this.color,
    this.weight = 800,
  });

  final String ini;
  final double size;
  final double fontSize;
  final Color? fill;
  final Color? ring;
  final double ringWidth;
  final Color? color;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return BoltBox(
      width: size,
      height: size,
      circle: true,
      color: fill,
      stroke: ring == null ? Stroke.none : Stroke(ring!, ringWidth),
      alignment: Alignment.center,
      child: Text(
        ini,
        style: BoltText.a(
          fontSize,
          weight: weight,
          color: color ?? (fill != null ? BoltColors.ink : BoltColors.text),
          height: 1,
        ),
      ),
    );
  }
}

/// Neon primary button.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
    this.radius = 16,
    this.fontSize = 15,
    this.color = BoltColors.neon,
    this.textColor = BoltColors.ink,
    this.scale = .97,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double radius;
  final double fontSize;
  final Color color;
  final Color textColor;
  final double scale;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // No onTap means it cannot be pressed yet: grey, so it never looks ready.
    final on = onTap != null;
    return Tap(
      onTap: onTap,
      scale: on ? scale : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: on ? color : BoltColors.line, borderRadius: BorderRadius.circular(radius)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BoltText.a(fontSize, weight: 800, color: on ? textColor : BoltColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined button (1.5 px).
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 52,
    this.radius = 16,
    this.fontSize = 14,
    this.color = BoltColors.neon,
    this.borderColor,
    this.borderWidth = 1.5,
    this.weight = 800,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final double weight;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: BoltBox(
        height: height,
        radius: radius,
        stroke: Stroke(borderColor ?? color, borderWidth),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: BoltText.a(fontSize, weight: weight, color: color),
        ),
      ),
    );
  }
}

class ChipStyle {
  const ChipStyle(this.bg, this.fg, this.stroke);

  final Color bg;
  final Color fg;
  final Stroke stroke;
}

/// `CHIP` in the prototype: pill colors per session status.
ChipStyle chipFor(SessionStatus s) => switch (s) {
  SessionStatus.done => const ChipStyle(BoltColors.neon, BoltColors.ink, Stroke(BoltColors.neon)),
  SessionStatus.approved => const ChipStyle(BoltColors.surface2, BoltColors.neon, Stroke(BoltColors.line)),
  SessionStatus.pending => const ChipStyle(Colors.transparent, BoltColors.neon, Stroke.dashed(BoltColors.neon)),
  SessionStatus.moved => const ChipStyle(Colors.transparent, BoltColors.text, Stroke(BoltColors.text)),
  SessionStatus.draft => const ChipStyle(Colors.transparent, BoltColors.textSoft, Stroke.dashed(BoltColors.muted2)),
};

/// Trainee wording for a status.
String traineeLabel(SessionStatus s) => switch (s) {
  SessionStatus.done => tx('Done'),
  SessionStatus.approved => tx('Confirmed'),
  SessionStatus.pending => tx('Needs your OK'),
  SessionStatus.moved => tx('Moved by you'),
  SessionStatus.draft => '',
};

/// Status pill.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.status,
    required this.label,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final SessionStatus status;
  final String label;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = chipFor(status);
    return BoltBox(
      color: c.bg,
      stroke: c.stroke,
      radius: BoltRadii.pill,
      padding: padding,
      child: Text(label, maxLines: 1, style: BoltText.a(fontSize, weight: 700, color: c.fg)),
    );
  }
}

/// Custom stroke icon exported from the prototype.
class BoltIcon extends StatelessWidget {
  const BoltIcon(this.name, {super.key, this.size = 24, this.color = BoltColors.text});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );
}

/// Neon dot with the pulsing ring (`vPulse`, 1.6 s).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.size = 10});

  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: BoltColors.neon,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: BoltColors.neon.withValues(alpha: .6 * (1 - _c.value)),
              spreadRadius: 12 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small outlined circle (how-to "i", swap) inside a 44 px hit area, so
/// rows of them line up and stay easy to hit.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.onTap, required this.child, this.size = 28, this.label});

  static const hit = 44.0;

  final VoidCallback onTap;
  final Widget child;
  final double size;

  /// Read out to screen readers.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Tap(
        onTap: onTap,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: BoltBox(
              width: size,
              height: size,
              circle: true,
              borderBox: true,
              stroke: const Stroke(BoltColors.line),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The neon "i" that opens an exercise's how-to.
class InfoIcon extends StatelessWidget {
  const InfoIcon({super.key, required this.onTap, this.size = 28});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) => CircleIconButton(
    onTap: onTap,
    size: size,
    label: tx('How to'),
    child: Text('i', style: BoltText.a(size * .46, weight: 800, color: BoltColors.neon, height: 1)),
  );
}

/// Mono "›" chevron in neon.
class Chevron extends StatelessWidget {
  const Chevron({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Text('›', style: BoltText.a(size, color: BoltColors.neon, height: 1));
}

/// Three stat tiles in a row, all as tall as the tallest, so a label that
/// wraps does not leave the row jagged.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// Stat tile: a mono label over the number, so the label reads as a heading
/// and never as "1 SESSIONS". [labelFirst] false puts the number on top.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    this.valueSize = 28,
    this.valueWeight = 900,
    this.valueColor = BoltColors.text,
    this.labelFirst = true,
    this.gap = 4,
  });

  final String value;
  final String label;
  final double valueSize;
  final double valueWeight;
  final Color valueColor;
  final bool labelFirst;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final v = RollText(
      value,
      maxLines: 1,
      style: BoltText.a(valueSize, weight: valueWeight, color: valueColor),
    );
    final l = Kicker(label, size: 9, spacing: .1);
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: labelFirst ? [l, SizedBox(height: gap), v] : [v, SizedBox(height: gap), l],
      ),
    );
  }
}

/// On/off switch from the prototype's settings rows (46 x 26).
class BoltSwitch extends StatelessWidget {
  const BoltSwitch({super.key, required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 46,
      height: 26,
      decoration: BoxDecoration(color: on ? BoltColors.neon : BoltColors.line, borderRadius: BorderRadius.circular(99)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: on ? BoltColors.ink : BoltColors.muted, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
