import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Design tokens from `Bolt UI.html`. One accent (neon) plus warn for injuries.
/// The grey and blue theme is built for reading: a blue page, black cards, and
/// white and grey for text and buttons, because that blue is too dark to read on
/// black. So [neon] means "the accent", which is white there.
abstract final class BoltColors {
  /// The grey and blue theme. Set from settings; the app rebuilds on a change.
  static bool blue = false;

  /// The accent, the page behind everything and text on the accent, for every
  /// theme but grey and blue. Set from settings by `applyTheme`.
  static Color accent = const Color(0xFFC6FF1A);
  static Color pageTint = ink;
  static Color onAccent = ink;

  static const ink = Color(0xFF0A0B09);

  /// A planned day on the blue theme's black calendar. White text reads 7:1 on it.
  static const blueCell = Color(0xFF2B3BE5);

  static const surface1 = Color(0xFF141612);
  static const surface2 = Color(0xFF1C1F19);
  static const sheet = Color(0xFF111310);
  static const line = Color(0xFF2E332A);
  static const lineSoft = Color(0xFF23271F);
  static const divider = Color(0xFF1E221B);
  static const text = Color(0xFFF1F4EC);
  static const textSoft = Color(0xFFC9CEC2);
  static Color get muted => blue ? const Color(0xFFD6D6D6) : const Color(0xFF9CA393);
  static Color get muted2 => blue ? const Color(0xFFC8C8C8) : const Color(0xFF80877A);
  // The dimmest grey for text: 4.5:1 on cards. muted4 is too dark for text.
  static Color get muted3 => blue ? const Color(0xFFBDBDBD) : const Color(0xFF7A8172);
  static const muted4 = Color(0xFF5E6558);
  static Color get neon => blue ? const Color(0xFFFFFFFF) : accent;
  static Color get warn => blue ? const Color(0xFFC8C8C8) : const Color(0xFFFF7A45);

  /// The background of every page.
  static Color get page => blue ? const Color(0xFF00008E) : pageTint;

  /// A glow around something lit up. None on the blue page, where it only blurs.
  static Color glow(int alpha) => blue ? const Color(0x00000000) : neon.withAlpha(alpha);

  /// Text and icons on a [neon] fill.
  static Color get onNeon => blue ? const Color(0xFF000000) : onAccent;

  // Secondary shades the prototype uses for handles, faded numbers and
  // locked badge rings.
  static const handle = Color(0xFF3A3F35);
  static const lineFaint = Color(0xFF262A22);
  static const scannerBg = Color(0xFF050605);
  static const scannerWell = Color(0xFF1A1D17);

  /// Apex, the colorful theme: stages blend two context colors instead of
  /// tinting with one. Set by `applyTheme`.
  static bool rich = false;

  // Paper: cream panels for planning and data, the same in every theme.
  static const paper = Color(0xFFEEEAE0);
  static const paperWell = Color(0xFFE1DCCF);
  static const paperInk = Color(0xFF12140F);
  static const paperSoft = Color(0xFF34372F);
  static const paperMuted = Color(0xFF5C6055);
  static const paperLine = Color(0xFFD2CDBF);

  // Context colors. Each means one thing on every screen and in every theme:
  // rank for strength and tiers, body for recovery and readiness, heat for
  // warm notes. When the theme's accent sits too close, a neighbour stands in.
  static const _violet = Color(0xFFB79AFF);
  static const _gold = Color(0xFFFFD36E);
  static const _mint = Color(0xFF7EDCC4);
  static const _sky = Color(0xFF8CC8FF);
  static const _apricot = Color(0xFFFFBB91);
  static const _rose = Color(0xFFFF9AB0);

  static Color get rank => _clashes(_violet) ? _gold : _violet;
  static Color get body => _clashes(_mint) ? _sky : _mint;
  static Color get heat => _clashes(_apricot) ? _rose : _apricot;

  static bool _clashes(Color c) {
    final a = HSLColor.fromColor(accent);
    if (blue || a.saturation < .3) return false;
    final d = (a.hue - HSLColor.fromColor(c).hue).abs();
    return math.min(d, 360 - d) < 35;
  }

  /// [c] darkened until it reads 4.5:1 on [bg], for accent text on paper.
  static Color deepen(Color c, Color bg) {
    double ratio(Color x) {
      final a = x.computeLuminance() + .05, b = bg.computeLuminance() + .05;
      return a > b ? a / b : b / a;
    }

    var h = HSLColor.fromColor(c);
    while (ratio(h.toColor()) < 4.5 && h.lightness > .05) {
      h = h.withLightness(h.lightness - .02);
    }
    return h.toColor();
  }
}

/// Spacing on the page: side gutter, gaps between sections and inside them.
abstract final class BoltSpace {
  static const gutter = 20.0;
  static const section = 28.0;
  static const block = 14.0;
  static const gap = 10.0;
  static const tight = 6.0;
}

abstract final class BoltRadii {
  static const card = 16.0;
  static const hero = 24.0;
  static const sheet = 28.0;
  static const cell = 12.0;
  static const pill = 99.0;
}
