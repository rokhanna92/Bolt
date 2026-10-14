import 'dart:ui' show FontVariation;

import 'package:flutter/painting.dart';

/// Text helpers. Both families are variable fonts, so weight and width are
/// passed as [FontVariation]s; `fontWeight` is set too so fallback fonts and
/// semantics still see the right weight.
abstract final class BoltText {
  static const archivo = 'Archivo';
  static const mono = 'JetBrains Mono';

  /// Archivo. [width] is the CSS `font-stretch` percentage (100 = normal).
  /// [spacing] is letter spacing in em, like the prototype's CSS.
  static TextStyle a(
    double size, {
    double weight = 400,
    double width = 100,
    Color? color,
    double? spacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: archivo,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation.weight(weight), FontVariation.width(width)],
      color: color,
      letterSpacing: spacing == null ? null : spacing * size,
      height: height,
    );
  }

  /// JetBrains Mono for labels, numbers, timers and dates.
  static TextStyle m(
    double size, {
    double weight = 400,
    Color? color,
    double? spacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation.weight(weight)],
      color: color,
      letterSpacing: spacing == null ? null : spacing * size,
      height: height,
    );
  }

  static FontWeight _weight(double w) {
    final i = ((w / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[i];
  }
}
