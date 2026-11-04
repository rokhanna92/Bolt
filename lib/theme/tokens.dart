import 'package:flutter/painting.dart';

/// Design tokens from `Bolt UI.html`. One accent (neon) plus warn for injuries.
/// Those two follow the theme in settings; black and white stay the same.
abstract final class BoltColors {
  /// The grey and #0000FF theme. Set from settings; the app rebuilds on a change.
  static bool blue = false;

  static const ink = Color(0xFF0A0B09);
  static const surface1 = Color(0xFF141612);
  static const surface2 = Color(0xFF1C1F19);
  static const sheet = Color(0xFF111310);
  static const line = Color(0xFF2E332A);
  static const lineSoft = Color(0xFF23271F);
  static const divider = Color(0xFF1E221B);
  static const text = Color(0xFFF1F4EC);
  static const textSoft = Color(0xFFC9CEC2);
  static const muted = Color(0xFF9CA393);
  static const muted2 = Color(0xFF80877A);
  // The dimmest grey for text: 4.5:1 on cards. muted4 is too dark for text.
  static const muted3 = Color(0xFF7A8172);
  static const muted4 = Color(0xFF5E6558);
  static Color get neon => blue ? const Color(0xFF0000FF) : const Color(0xFFC6FF1A);
  static Color get warn => blue ? const Color(0xFF9E9E9E) : const Color(0xFFFF7A45);

  /// Text and icons on a [neon] fill: blue needs white, neon needs ink.
  static Color get onNeon => blue ? const Color(0xFFFFFFFF) : ink;

  // Secondary shades the prototype uses for handles, faded numbers and
  // locked badge rings.
  static const handle = Color(0xFF3A3F35);
  static const lineFaint = Color(0xFF262A22);
  static const scannerBg = Color(0xFF050605);
  static const scannerWell = Color(0xFF1A1D17);
}

abstract final class BoltRadii {
  static const card = 16.0;
  static const hero = 24.0;
  static const sheet = 28.0;
  static const cell = 12.0;
  static const pill = 99.0;
}
