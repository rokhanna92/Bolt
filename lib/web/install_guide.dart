import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../core/format.dart';
import '../features/profile/language_picker.dart';
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

  List<Widget> _steps(List<(String, IconData?)> steps) => [
    for (final (i, (text, icon)) in steps.indexed) ...[
      if (i > 0) const SizedBox(height: 10),
      BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text('${i + 1}', style: BoltText.m(14, weight: 700, color: BoltColors.neon)),
            ),
            Expanded(child: Text(text, style: BoltText.a(14, weight: 600, height: 1.35))),
            if (icon != null) ...[const SizedBox(width: 10), Icon(icon, size: 24, color: BoltColors.neon)],
          ],
        ),
      ),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final open = tx('Open Bolt from your home screen and type your key.');
    return ColoredBox(
      color: BoltColors.page,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 24, 20, insets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'BOLT',
                    style: BoltText.a(42, weight: 900, color: BoltColors.neon, width: 112, spacing: -.02),
                  ),
                ),
                const LanguagePicker(compact: true),
              ],
            ),
            const SizedBox(height: 18),
            Text(tx('Get Bolt on your phone'), style: BoltText.a(28, weight: 900, width: 112, spacing: -.02)),
            const SizedBox(height: 6),
            Text(
              tx(
                'It takes a few seconds. Bolt then opens full screen like any app, and your data stays on your phone.',
              ),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            ...switch (_kind) {
              _Phone.iphoneOther => [
                ..._steps([
                  (tx('Copy the link below and paste it into Safari.'), null),
                  (tx('Follow the steps there.'), null),
                ]),
                const SizedBox(height: 12),
                NeonButton(label: _copied ? tx('Copied') : tx('Copy the link'), height: 52, onTap: _copy),
              ],
              _Phone.android => [
                if (_canInstall()) ...[
                  NeonButton(
                    label: tx('Install Bolt'),
                    height: 52,
                    onTap: () => _install().toDart.then((_) {}, onError: (_) {}),
                  ),
                  const SizedBox(height: 14),
                ],
                ..._steps([
                  (tx('Tap the menu at the top right of your browser.'), Icons.more_vert),
                  (tx('Tap Install app or Add to Home screen.'), null),
                  (open, null),
                ]),
              ],
              _ => _steps([
                (tx('Tap the Share button in Safari.'), Icons.ios_share),
                (tx('Scroll down and tap Add to Home Screen.'), Icons.add_box_outlined),
                (tx('Tap Add at the top right.'), null),
                (open, null),
              ]),
            },
            const SizedBox(height: 14),
            Text(
              tx('No key yet? Ask the owner of Bolt for one.'),
              textAlign: TextAlign.center,
              style: BoltText.a(12, color: BoltColors.muted),
            ),
            const SizedBox(height: 18),
            Tap(
              onTap: widget.onSkip,
              child: Padding(
                padding: const EdgeInsets.all(10),
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
    );
  }
}
