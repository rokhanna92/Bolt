import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../theme/text_styles.dart';

const _fonts = {
  BoltText.archivo: 'assets/fonts/Archivo-Variable.ttf',
  BoltText.mono: 'assets/fonts/JetBrainsMono-Variable.ttf',
};

/// Flutter downloads Bolt's fonts once at startup. On a bad connection one can
/// fail, and every screen then silently draws in Roboto with a different
/// layout. So a missing font is fetched again: the splash waits a little for
/// it, and if it comes later the screens redraw by themselves.
Future<void> ensureFonts() async {
  final missing = {
    for (final e in _fonts.entries)
      if (!_isLoaded(e.key)) e.key: e.value,
  };
  if (missing.isEmpty) return;
  final all = Future.wait([for (final e in missing.entries) _fetch(e.key, e.value)]);
  await all.timeout(const Duration(seconds: 20), onTimeout: () => const []);
}

/// A family that did not load falls back, measuring the same as one that
/// does not exist.
bool _isLoaded(String family) {
  double width(String f) {
    final p = TextPainter(
      text: TextSpan(
        text: 'Hamburgefonstiv 0123',
        style: TextStyle(fontFamily: f, fontSize: 40),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  return width(family) != width('bolt-no-such-font');
}

Future<void> _fetch(String family, String asset) async {
  for (var wait = 1; wait < 60; wait *= 2) {
    try {
      final bytes = await rootBundle.load(asset).timeout(const Duration(seconds: 30));
      await ui.loadFontFromList(bytes.buffer.asUint8List(), fontFamily: family);
      return;
    } catch (_) {
      await Future<void>.delayed(Duration(seconds: wait));
    }
  }
}
