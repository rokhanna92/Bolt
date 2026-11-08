import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'box.dart';
import 'common.dart';
import 'tap.dart';

/// The colors to draw with on the surface below: dark cards or cream paper.
/// Widgets that read [Tone.of] look right on both without being told.
class Tone {
  const Tone._({
    required this.paper,
    required this.text,
    required this.soft,
    required this.muted,
    required this.line,
    required this.well,
    required this.accent,
  });

  /// On the page and on dark cards: the app's usual colors.
  factory Tone.dark() => Tone._(
    paper: false,
    text: BoltColors.text,
    soft: BoltColors.textSoft,
    muted: BoltColors.muted,
    line: BoltColors.lineSoft,
    well: BoltColors.surface2,
    accent: BoltColors.neon,
  );

  /// On paper: ink text, and the accent deepened until it reads.
  factory Tone.paper() => Tone._(
    paper: true,
    text: BoltColors.paperInk,
    soft: BoltColors.paperSoft,
    muted: BoltColors.paperMuted,
    line: BoltColors.paperLine,
    well: BoltColors.paperWell,
    accent: BoltColors.deepen(BoltColors.neon, BoltColors.paper),
  );

  final bool paper;
  final Color text;
  final Color soft;
  final Color muted;
  final Color line;
  final Color well;
  final Color accent;

  static Tone of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ToneScope>()?.tone ?? Tone.dark();
}

class _ToneScope extends InheritedWidget {
  const _ToneScope({required this.tone, required super.child});

  final Tone tone;

  @override
  bool updateShouldNotify(_ToneScope old) => old.tone.paper != tone.paper;
}

/// Cream panel for planning and data. Text without a color turns ink.
class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = BoltRadii.hero,
    this.watermark,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// A giant faint glyph in the corner, like the first letter of a day.
  final String? watermark;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.paper();
    return BoltBox(
      color: BoltColors.paper,
      radius: radius,
      clip: watermark != null,
      child: _ToneScope(
        tone: tone,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: tone.text),
          child: Stack(
            children: [
              if (watermark case final w?) Watermark(w, color: BoltColors.paperInk.withAlpha(0x10)),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dark field lit by a context color: rank, body, heat or the accent.
/// In Apex it blends two colors; elsewhere it glows with one.
class Stage extends StatelessWidget {
  const Stage({
    super.key,
    required this.color,
    required this.child,
    this.blend,
    this.padding = const EdgeInsets.all(20),
    this.radius = BoltRadii.hero,
    this.watermark,
  });

  final Color color;

  /// The second color Apex blends in. Defaults to the accent.
  final Color? blend;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? watermark;

  @override
  Widget build(BuildContext context) {
    final second = blend ?? BoltColors.neon;
    final rich = BoltColors.rich && !BoltColors.blue;
    return BoltBox(
      color: BoltColors.surface1,
      radius: radius,
      clip: true,
      gradient: rich
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(color.withAlpha(0x38), BoltColors.surface1),
                BoltColors.surface1,
                Color.alphaBlend(second.withAlpha(0x22), BoltColors.surface1),
              ],
              stops: const [0, .55, 1],
            )
          : null,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withAlpha(BoltColors.blue ? 0 : (rich ? 0x55 : 0x30)), color.withAlpha(0)],
                  ),
                ),
              ),
            ),
          ),
          if (watermark case final w?) Watermark(w, color: color.withAlpha(0x1C)),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// A giant faint glyph bleeding off the bottom right of a [Stack].
class Watermark extends StatelessWidget {
  const Watermark(this.text, {super.key, required this.color, this.size = 150});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Positioned(
    right: -8,
    bottom: -size * .28,
    child: IgnorePointer(
      child: ExcludeSemantics(
        child: Text(text, style: BoltText.display(size, color: color, height: 1)),
      ),
    ),
  );
}

/// The top of a screen: back button, a small label, the display title and
/// an optional line under it.
class PageHead extends StatelessWidget {
  const PageHead({super.key, required this.title, this.kicker, this.sub, this.onBack, this.trailing, this.size = 38});

  final String title;
  final String? kicker;
  final String? sub;
  final VoidCallback? onBack;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null || kicker != null || trailing != null) ...[
          Row(
            children: [
              if (onBack case final b?) ...[BackBox(onTap: b), const SizedBox(width: 12)],
              if (kicker case final k?) Expanded(child: Kicker(k, maxLines: 1)) else const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
        ],
        Text(title, style: BoltText.display(size, color: tone.text)),
        if (sub case final s?) ...[
          const SizedBox(height: 8),
          Text(s, style: BoltText.a(13, color: tone.muted, height: 1.4)),
        ],
      ],
    );
  }
}

/// A heading inside a screen with an optional line of help under it.
class Section extends StatelessWidget {
  const Section(this.title, {super.key, this.sub, this.trailing});

  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: BoltSpace.section, bottom: BoltSpace.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(title, style: BoltText.headline(21, color: tone.text)),
              ),
              ?trailing,
            ],
          ),
          if (sub case final s?) ...[
            const SizedBox(height: 4),
            Text(s, style: BoltText.a(12, color: tone.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// A hero number with its unit stacked small beside it: "18.4 tonnes lifted".
class BigFigure extends StatelessWidget {
  const BigFigure(this.value, {super.key, this.unit, this.size = 64, this.color});

  final String value;
  final String? unit;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: BoltText.display(size, color: color ?? tone.text, height: .9)),
          ),
        ),
        if (unit case final u?) ...[
          const SizedBox(width: 8),
          Padding(
            padding: EdgeInsets.only(bottom: size * .1),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(u, style: BoltText.a(12, weight: 700, color: tone.soft, height: 1.2)),
            ),
          ),
        ],
      ],
    );
  }
}

/// A panel of rows split by hairlines, the grouped list of settings-style
/// screens. Follows the tone it sits on.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    return BoltBox(
      color: tone.paper ? BoltColors.paperWell : BoltColors.surface1,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: tone.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row that opens something: title, an optional line under it, and a
/// chevron or [trailing]. [lead] sits on the left.
class LinkRow extends StatelessWidget {
  const LinkRow({super.key, required this.title, this.sub, this.onTap, this.lead, this.trailing, this.titleColor});

  final String title;
  final String? sub;
  final VoidCallback? onTap;
  final Widget? lead;
  final Widget? trailing;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (lead case final l?) ...[l, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: BoltText.a(14, weight: 800, color: titleColor ?? tone.text)),
                if (sub case final s?) ...[
                  const SizedBox(height: 2),
                  Text(s, style: BoltText.a(12, color: tone.muted, height: 1.35)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          trailing ?? BoltIcon('chevron', size: 13, color: tone.accent),
        ],
      ),
    );
    return onTap == null ? row : Tap(onTap: onTap!, child: row);
  }
}

/// A tile that opens a page, lit by [color]: a short title, one line, and
/// an arrow in the corner. Two of them side by side read as a choice.
class DoorTile extends StatelessWidget {
  const DoorTile({super.key, required this.title, required this.color, required this.onTap, this.sub});

  final String title;
  final String? sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    scale: .97,
    child: Stage(
      color: color,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Text('↗', style: BoltText.a(16, weight: 800, color: color, height: 1)),
          ),
          const SizedBox(height: 14),
          Text(title, style: BoltText.headline(17, color: BoltColors.text)),
          if (sub case final s?) ...[
            const SizedBox(height: 4),
            Text(s, style: BoltText.a(11, color: BoltColors.muted, height: 1.35)),
          ],
        ],
      ),
    ),
  );
}
