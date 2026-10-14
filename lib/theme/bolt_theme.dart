import 'package:flutter/material.dart';

import 'text_styles.dart';
import 'tokens.dart';

/// Material 3, dark only, themed down to the prototype: no ripples, ink
/// background, neon selection.
ThemeData buildBoltTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: BoltText.archivo,
    scaffoldBackgroundColor: BoltColors.ink,
    canvasColor: BoltColors.ink,
    colorScheme: const ColorScheme.dark(
      primary: BoltColors.neon,
      onPrimary: BoltColors.ink,
      secondary: BoltColors.neon,
      onSecondary: BoltColors.ink,
      error: BoltColors.warn,
      onError: BoltColors.ink,
      surface: BoltColors.ink,
      onSurface: BoltColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: BoltColors.neon,
      selectionColor: Color(0x55C6FF1A),
      selectionHandleColor: BoltColors.neon,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: BoltColors.text,
      displayColor: BoltColors.text,
      fontFamily: BoltText.archivo,
    ),
  );
}
