import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../core/format.dart';
import '../features/profile/language_picker.dart';
import '../services/updater.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/box.dart';
import '../widgets/common.dart';
import '../widgets/tap.dart';

@JS('navigator.standalone')
external bool? get _iosStandalone;

// Set up in web/index.html, because the browser offers this before Flutter runs.
@JS('boltCanInstall')
external bool _canInstall();

@JS('boltInstall')
external JSPromise<JSBoolean> _install();

enum _Phone { iphoneSafari, iphoneOther, android, other }

_Phone _phone() {
  final nav = web.window.navigator;
  final ua = nav.userAgent;
  // iPads call themselves Macs, but Macs have no touch screen.
  final ios = RegExp(r'iPhone|iPad|iPod').hasMatch(ua) || (ua.contains('Macintosh') && nav.maxTouchPoints > 1);
  if (ios) {
    return RegExp(r'CriOS|FxiOS|EdgiOS|OPiOS|YaBrowser|DuckDuckGo').hasMatch(ua)
        ? _Phone.iphoneOther
        : _Phone.iphoneSafari;
  }
  return ua.contains('Android') ? _Phone.android : _Phone.other;
}

/// True on a phone that has Bolt open in a browser tab, not installed. Its
/// data would stay behind in that tab, so it is worth installing first.
bool shouldGuideInstall() =>
    _phone() != _Phone.other && web.window.matchMedia('(display-mode: browser)').matches && _iosStandalone != true;

/// What someone sees after scanning a friend's code: how to get Bolt on the
/// home screen, for the phone they are holding.
class InstallGuide extends StatefulWidget {
  const InstallGuide({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  State<InstallGuide> createState() => _InstallGuideState();
}

class _InstallGuideState extends State<InstallGuide> {
  final _kind = _phone();
  late final _onOffer = ((web.Event _) => setState(() {})).toJS;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    web.window.addEventListener('boltcaninstall', _onOffer);
  }

  @override
  void dispose() {
    web.window.removeEventListener('boltcaninstall', _onOffer);
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: web.window.location.origin));
    if (mounted) setState(() => _copied = true);
  }

  /// The newest release's APK, or the release page if GitHub cannot say.
  Future<void> _downloadApk() async {
    var url = 'https://github.com/rokhanna92/Bolt/releases/latest';
    try {
      final res = await web.window.fetch(kReleasesApi.toJS).toDart;
      final json = jsonDecode((await res.text().toDart).toDart);
      url = pickApk((json as Map)['assets'])?.url ?? url;
    } catch (_) {}
    web.window.location.href = url;
  }

  /// Numbered steps in one card, so they read as a single short task.
  Widget _steps(List<(String, IconData?)> steps) => BoltBox(
    color: BoltColors.surface1,
    radius: 18,
    child: Column(
      children: [
        for (final (i, (text, icon)) in steps.indexed)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: i == steps.length - 1
                ? null
                : const BoxDecoration(
                    border: Border(bottom: BorderSide(color: BoltColors.divider)),
                  ),
            child: Row(
              children: [
                BoltBox(
                  width: 26,
                  height: 26,
                  borderBox: true,
                  circle: true,
                  stroke: Stroke(BoltColors.neon, 1.5),
                  alignment: Alignment.center,
                  child: Text('${i + 1}', style: BoltText.m(12, weight: 700, color: BoltColors.neon)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: BoltText.a(14, weight: 600, color: BoltColors.text, height: 1.35)),
                ),
                if (icon != null) ...[const SizedBox(width: 10), Icon(icon, size: 22, color: BoltColors.neon)],
              ],
            ),
          ),
      ],
    ),
  );

  Widget _hint(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
  );

  List<Widget> _forThisPhone() {
    final open = tx('Open Bolt from your home screen and type your key.');
    return switch (_kind) {
      _Phone.iphoneOther => [
        _steps([(tx('Copy the link below and paste it into Safari.'), null), (tx('Follow the steps there.'), null)]),
        const SizedBox(height: 14),
        NeonButton(label: _copied ? tx('Copied') : tx('Copy the link'), height: 54, onTap: _copy),
      ],
      // The browser offers the install itself: one button, nothing to explain.
      _Phone.android when _canInstall() => [
        NeonButton(
          label: tx('Install Bolt'),
          height: 54,
          onTap: () => _install().toDart.then((_) {}, onError: (_) {}),
        ),
        const SizedBox(height: 12),
        _hint(tx('Then open Bolt from your home screen and type your key.')),
      ],
      _Phone.android => [
        _steps([
          (tx('Tap the menu at the top right of your browser.'), Icons.more_vert),
          (tx('Tap Install app or Add to Home screen.'), null),
          (open, null),
        ]),
      ],
      _ => [
        _steps([
          (tx('Tap the Share button in Safari.'), Icons.ios_share),
          (tx('Scroll down and tap Add to Home Screen.'), Icons.add_box_outlined),
          (tx('Tap Add at the top right.'), null),
          (open, null),
        ]),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    // The guide sits above the app's pages, so it brings its own Material:
    // without one Flutter draws all text red with a yellow underline.
    return Material(
      color: BoltColors.page,
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, insets.top + 20, 20, insets.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BoltBox(
                        width: 44,
                        height: 44,
                        radius: 13,
                        color: BoltColors.neon,
                        alignment: Alignment.center,
                        child: BoltIcon('bolt', size: 26, color: BoltColors.onNeon),
                      ),
                      const Spacer(),
                      const LanguagePicker(compact: true),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(tx('Get Bolt on your phone'), style: BoltText.display(37, color: BoltColors.text, height: 1.08)),
                  const SizedBox(height: 10),
                  Text(
                    tx('It takes a few seconds, then Bolt opens full screen like any app.'),
                    style: BoltText.a(15, color: BoltColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 26),
                  ..._forThisPhone(),
                  const Spacer(),
                  const SizedBox(height: 26),
                  if (_kind == _Phone.android) ...[
                    Tap(
                      onTap: _downloadApk,
                      child: BoltBox(
                        color: BoltColors.surface1,
                        radius: 16,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx('Get the full Android app'),
                                    style: BoltText.a(14, weight: 800, color: BoltColors.text),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    tx('Adds reminders and widgets. Your phone asks you to allow the install.'),
                                    style: BoltText.a(12, color: BoltColors.muted, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Chevron(size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    tx('No key yet? Ask the owner of Bolt for one.'),
                    textAlign: TextAlign.center,
                    style: BoltText.a(12, color: BoltColors.muted),
                  ),
                  Tap(
                    onTap: widget.onSkip,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        tx('Continue in the browser'),
                        textAlign: TextAlign.center,
                        style: BoltText.a(13, weight: 700, color: BoltColors.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
