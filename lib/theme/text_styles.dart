import 'package:flutter/painting.dart';

/// Text helpers. Both families are variable fonts, so weight and width are
/// passed as [FontVariation]s; `fontWeight` is set too so fallback fonts and
/// semantics still see the right weight.
abstract final class BoltText {
  static const archivo = 'Archivo';
  static const mono = 'JetBrains Mono';

  /// CSS `line-height: normal` for each font (ascent + descent from its
  /// typo metrics). Flutter's own default renders taller on Android.
  static const _archivoNormal = 1.088;
  static const _monoNormal = 1.32;

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
      // Explicit 0, or Material's default text theme adds 0.25 px per glyph.
      letterSpacing: (spacing ?? 0) * size,
      height: height ?? _archivoNormal,
      // CSS splits line-height leading evenly above and below the glyphs.
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// JetBrains Mono for labels, numbers, timers and dates.
  static TextStyle m(double size, {double weight = 400, Color? color, double? spacing, double? height}) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      fontWeight: _weight(weight),
      fontVariations: [FontVariation.weight(weight)],
      color: color,
      letterSpacing: (spacing ?? 0) * size,
      height: height ?? _monoNormal,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static FontWeight _weight(double w) {
    final i = ((w / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[i];
  }
}
