import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/themes.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// Pick a theme: five ready-made ones, each shown as a little phone in its
/// colors, and a sixth tile to make your own.
class ThemeScreen extends ConsumerWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(boltProvider).settings;
    final store = ref.read(boltProvider.notifier);
    final insets = MediaQuery.paddingOf(context);
    final active = s.blue ? 'blue' : s.theme;
    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 40 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Text(tx('Theme'), style: BoltText.display(24)),
              ],
            ),
            const SizedBox(height: 22),
            Kicker(tx('THEMES'), size: 10),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .78,
              children: [
                for (final t in kThemes)
                  _Tile(
                    name: tx(t.name),
                    on: active == t.id,
                    preview: _Preview(accent: t.accent, page: t.page),
                    onTap: () {
                      Haptics.play(Feel.tap);
                      store.setTheme(t.id);
                    },
                  ),
                _Tile(
                  name: active == kOwnTheme ? tx('Your own') : tx('Create your own'),
                  on: active == kOwnTheme,
                  preview: active == kOwnTheme
                      ? _Preview(accent: Color(s.ownAccent), page: Color(s.ownPage))
                      : const _Rainbow(),
                  onTap: () => context.push('/theme/own'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A theme as a tile: its preview with the name under it. The one in use
/// has an accent border.
class _Tile extends StatelessWidget {
  const _Tile({required this.name, required this.on, required this.preview, required this.onTap});

  final String name;
  final bool on;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    scale: .96,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: BoltColors.surface1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? BoltColors.neon : BoltColors.lineSoft, width: on ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: preview),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BoltText.a(13, weight: 800, color: on ? BoltColors.neon : BoltColors.text),
          ),
        ],
      ),
    ),
  );
}

/// A little Today in a theme's colors: a greeting, a card with a bar and a
/// button.
class _Preview extends StatelessWidget {
  const _Preview({required this.accent, required this.page});

  final Color accent;
  final Color page;

  @override
  Widget build(BuildContext context) {
    final on = textOn(accent);
    Widget line(double w, Color c, [double h = 6]) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
    );
    return Container(
      color: page,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(34, accent.withAlpha(0xB3), 4),
          const SizedBox(height: 6),
          line(70, BoltColors.text, 9),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BoltColors.surface1,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withAlpha(0x59)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line(28, accent, 4),
                  const SizedBox(height: 6),
                  line(56, BoltColors.textSoft, 6),
                  const SizedBox(height: 4),
                  line(40, BoltColors.muted4, 5),
                  const Spacer(),
                  Container(
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
                    child: line(26, on, 4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == 0 ? accent : BoltColors.muted4, shape: BoxShape.circle),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "make your own" tile: a ring of every hue around a plus.
class _Rainbow extends StatelessWidget {
  const _Rainbow();

  @override
  Widget build(BuildContext context) => Container(
    color: BoltColors.ink,
    alignment: Alignment.center,
    child: Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: _hues),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 66,
        height: 66,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: BoltColors.ink, shape: BoxShape.circle),
        child: Text('+', style: BoltText.a(30, weight: 700, color: BoltColors.text)),
      ),
    ),
  );
}

/// Every hue round the wheel, back to red.
final _hues = [for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h % 360.0, 1, 1).toColor()];

/// Make your own theme: a main color and a background, each picked on a
/// wheel or from quick swatches, with a live preview. Save puts it on.
class OwnThemeScreen extends ConsumerStatefulWidget {
  const OwnThemeScreen({super.key});

  @override
  ConsumerState<OwnThemeScreen> createState() => _OwnThemeScreenState();
}

class _OwnThemeScreenState extends ConsumerState<OwnThemeScreen> {
  late final _s = ref.read(boltProvider).settings;
  late var _accent = HSVColor.fromColor(Color(_s.ownAccent));
  late var _page = HSVColor.fromColor(Color(_s.ownPage));

  /// Picking the background instead of the main color.
  var _bg = false;

  /// Backgrounds stay this dark so the white text on them reads.
  static const _pageValue = .13;

  static const _accents = [
    Color(0xFFC6FF1A),
    Color(0xFF00E5FF),
    Color(0xFF2F7BFF),
    Color(0xFFB57BFF),
    Color(0xFFFF4FA3),
    Color(0xFFFF3B3B),
    Color(0xFFFF9F1A),
    Color(0xFFFFE14D),
  ];
  static const _pages = [
    Color(0xFF0A0B09),
    Color(0xFF000000),
    Color(0xFF0A0F1F),
    Color(0xFF0D0A15),
    Color(0xFF100A0D),
    Color(0xFF14090A),
    Color(0xFF0A140E),
    Color(0xFF16130A),
  ];

  void _pick(HSVColor c) {
    setState(() => _bg ? _page = c.withValue(_pageValue) : _accent = c.withValue(1));
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final accent = _accent.toColor();
    final page = _page.toColor();
    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 40 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Expanded(child: Text(tx('Your own theme'), style: BoltText.display(24))),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 150,
                height: 190,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _Preview(accent: accent, page: page),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: BoltColors.surface1, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  for (final (b, label, c) in [(false, tx('Main color'), accent), (true, tx('Background'), page)])
                    Expanded(
                      child: Tap(
                        onTap: () => setState(() => _bg = b),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 42,
                          decoration: BoxDecoration(
                            color: _bg == b ? BoltColors.surface2 : null,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _bg == b ? BoltColors.neon : const Color(0x00000000)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: BoltColors.line),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(label, style: BoltText.a(13, weight: 800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: _Wheel(value: _bg ? _page : _accent, dark: _bg, onChanged: _pick),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in _bg ? _pages : _accents)
                  Tap(
                    onTap: () {
                      Haptics.play(Feel.tick);
                      setState(() => _bg ? _page = HSVColor.fromColor(c) : _accent = HSVColor.fromColor(c));
                    },
                    scale: .9,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == (_bg ? page : accent).toARGB32() ? BoltColors.text : BoltColors.line,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 26),
            NeonButton(
              label: tx('Save theme'),
              color: accent,
              textColor: textOn(accent),
              onTap: () {
                Haptics.play(Feel.success);
                ref.read(boltProvider.notifier).setOwnTheme(accent.toARGB32(), page.toARGB32());
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A color wheel: hue round the edge, white in the middle. Tap or drag to
/// pick. With [dark] it shows the dark shades backgrounds are made from.
class _Wheel extends StatelessWidget {
  const _Wheel({required this.value, required this.dark, required this.onChanged});

  final HSVColor value;
  final bool dark;
  final ValueChanged<HSVColor> onChanged;

  static const _size = 250.0;

  void _at(Offset p) {
    const r = _size / 2;
    final d = p - const Offset(r, r);
    final hue = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
    final sat = (d.distance / r).clamp(0.0, 1.0);
    onChanged(HSVColor.fromAHSV(1, hue, sat, value.value));
  }

  @override
  Widget build(BuildContext context) {
    const r = _size / 2;
    final a = value.hue * math.pi / 180;
    final dot = Offset(r + math.cos(a) * value.saturation * r, r + math.sin(a) * value.saturation * r);
    return GestureDetector(
      onPanDown: (d) => _at(d.localPosition),
      onPanUpdate: (d) => _at(d.localPosition),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: _hues),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)]),
              ),
            ),
            // Backgrounds come from the dark end, so the wheel shows that.
            if (dark)
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xC7000000)),
              ),
            Positioned(
              left: dot.dx - 14,
              top: dot.dy - 14,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: value.toColor(),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
