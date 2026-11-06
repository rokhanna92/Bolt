import 'package:flutter/painting.dart';

import '../data/models/settings.dart';
import 'tokens.dart';

/// A ready-made look: its accent and the page behind everything.
class ThemeChoice {
  const ThemeChoice(this.id, this.name, this.accent, this.page);

  final String id;
  final String name;
  final Color accent;
  final Color page;
}

/// The five ready-made themes. Grey and blue is its own reading theme
/// ([BoltColors.blue]); the rest swap the accent and tint the page.
const kThemes = [
  ThemeChoice('neon', 'Neon', Color(0xFFC6FF1A), BoltColors.ink),
  ThemeChoice('blue', 'Grey and blue', Color(0xFFFFFFFF), Color(0xFF00008E)),
  ThemeChoice('pink', 'Pink', Color(0xFFFF4FA3), Color(0xFF100A0D)),
  ThemeChoice('purple', 'Purple', Color(0xFFB57BFF), Color(0xFF0D0A15)),
  ThemeChoice('silver', 'Silver', Color(0xFFD5DAE1), Color(0xFF000000)),
];

/// Your own theme's id in settings.
const kOwnTheme = 'own';

/// Ink or white, whichever reads better on [c].
Color textOn(Color c) => c.computeLuminance() > .186 ? BoltColors.ink : const Color(0xFFFFFFFF);

/// The theme in [s] as the colors the app draws with.
void applyTheme(AppSettings s) {
  BoltColors.blue = s.blue;
  final (accent, page) = s.theme == kOwnTheme
      ? (Color(s.ownAccent), Color(s.ownPage))
      : switch (kThemes.where((t) => t.id == s.theme).firstOrNull) {
          final t? => (t.accent, t.page),
          null => (kThemes.first.accent, kThemes.first.page),
        };
  BoltColors.accent = accent;
  BoltColors.pageTint = page;
  BoltColors.onAccent = textOn(accent);
}

/// The name of the theme in [s], in English for `tx`.
String themeName(AppSettings s) {
  if (s.blue) return 'Grey and blue';
  if (s.theme == kOwnTheme) return 'Your own';
  return kThemes.where((t) => t.id == s.theme).firstOrNull?.name ?? 'Neon';
}
