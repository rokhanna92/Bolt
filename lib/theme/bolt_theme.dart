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
    scaffoldBackgroundColor: BoltColors.page,
    canvasColor: BoltColors.page,
    colorScheme: ColorScheme.dark(
      primary: BoltColors.neon,
      onPrimary: BoltColors.onNeon,
      secondary: BoltColors.neon,
      onSecondary: BoltColors.onNeon,
      error: BoltColors.warn,
      onError: BoltColors.ink,
      surface: BoltColors.page,
      onSurface: BoltColors.text,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: BoltColors.neon,
      selectionColor: BoltColors.neon.withAlpha(0x55),
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
