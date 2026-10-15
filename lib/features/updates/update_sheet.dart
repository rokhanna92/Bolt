import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';

import '../../services/updater.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

final updaterProvider = Provider<Updater>((ref) => Updater());

final installedProvider = FutureProvider<Installed>((ref) => ref.read(updaterProvider).installed());

/// "App" section on the profile: the installed version and the update button.
class UpdateCard extends ConsumerWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedProvider).value;
    void open() => showBoltSheet<void>(context, (_) => const UpdateSheet());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(tx('App')),
        const SizedBox(height: 10),
        Tap(
          onTap: open,
          child: BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(installed?.label ?? tx('Bolt'), style: BoltText.a(15, weight: 800)),
                      const SizedBox(height: 2),
                      Text(
                        tx('Get the newest version without reinstalling'),
                        style: BoltText.a(12, color: BoltColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                BoltBox(
                  color: BoltColors.neon,
                  radius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(tx('Update'), style: BoltText.a(13, weight: 800, color: BoltColors.ink)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _Step { checking, upToDate, failed, found, downloading, permission, installing }

/// Check, download, allow installs once, then Android's installer.
class UpdateSheet extends ConsumerStatefulWidget {
  const UpdateSheet({super.key});

  @override
  ConsumerState<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends ConsumerState<UpdateSheet> with WidgetsBindingObserver {
  _Step _step = _Step.checking;
  String _message = '';
  Release? _release;
  File? _apk;
  double _progress = 0;

  Updater get _updater => ref.read(updaterProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from "Install unknown apps": carry on if it is now allowed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _step == _Step.permission) _install();
  }

  Future<void> _check() async {
    setState(() => _step = _Step.checking);
    final r = await _updater.check();
    if (!mounted) return;
    setState(() {
      switch (r) {
        case UpToDate():
          _step = _Step.upToDate;
        case UpdateFound(:final release):
          _release = release;
          _step = _Step.found;
        case CheckFailed(:final message):
          _message = message;
          _step = _Step.failed;
      }
    });
  }

  Future<void> _download() async {
    setState(() {
      _step = _Step.downloading;
      _progress = 0;
    });
    try {
      _apk = await _updater.download(
        _release!,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _install();
    } on UpdateError catch (e) {
      if (!mounted) return;
      setState(() {
        _message = e.message;
        _step = _Step.failed;
      });
    }
  }

  Future<void> _install() async {
    final apk = _apk;
    if (apk == null || !mounted) return;
    if (!await _updater.canInstall()) {
      if (mounted) setState(() => _step = _Step.permission);
      return;
    }
    final opened = await _updater.install(apk);
    if (!mounted) return;
    setState(() {
      if (opened) {
        _step = _Step.installing;
      } else {
        _message = tx('Android could not open the installer. Try again.');
        _step = _Step.failed;
      }
    });
  }

  String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedProvider).value;
    final r = _release;
    final children = <Widget>[
      switch (_step) {
        _Step.checking => _head(tx('Checking for updates'), tx('Asking for the latest Bolt release…')),
        _Step.upToDate => _head(
          tx('You are up to date'),
          tx('{version} is the newest version.', {'version': installed?.label ?? 'Bolt'}),
        ),
        _Step.failed => _head(tx('Update did not work'), _message),
        _Step.found => _head(
          r!.title,
          tx('You have {installed}. Download {size}; your profile, plans and history stay.', {
            'installed': installed?.label ?? tx('an older Bolt'),
            'size': r.apkBytes > 0 ? _mb(r.apkBytes) : tx('the update'),
          }),
          kicker: tx('NEW VERSION'),
        ),
        _Step.downloading => _head(
          tx('Downloading {what}', {'what': r?.title ?? tx('update')}),
          r != null && r.apkBytes > 0
              ? '${_mb((r.apkBytes * _progress).round())} of ${_mb(r.apkBytes)}'
              : '${(_progress * 100).round()} %',
        ),
        _Step.permission => _head(
          tx('Allow Bolt to install updates'),
          tx('Android asks this once. Turn on "Allow from this source", then come back here and the update continues.'),
        ),
        _Step.installing => _head(
          tx('Confirm in the installer'),
          tx('Tap Update on the Android screen. Bolt restarts on the new version with all your data.'),
        ),
      },
    ];
    if (_step == _Step.checking || _step == _Step.downloading) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _step == _Step.checking ? null : _progress,
              minHeight: 8,
              color: BoltColors.neon,
              backgroundColor: BoltColors.lineSoft,
            ),
          ),
        ),
      );
    }
    if (_step == _Step.found && r!.notes.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 14,
            padding: const EdgeInsets.all(12),
            // Long notes scroll inside the box so the button stays in view.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(child: Text(r.notes, style: BoltText.a(13, height: 1.45))),
            ),
          ),
        ),
      );
    }
    final (label, action) = switch (_step) {
      _Step.found => (tx('Download and install'), _download),
      _Step.failed => (tx('Try again'), _release == null ? _check : _download),
      _Step.permission => (tx('Open settings'), () => _updater.openInstallSettings()),
      _Step.installing => (tx('Open installer again'), _install),
      _Step.upToDate => (tx('Done'), () => Navigator.of(context).pop()),
      _ => ('', null),
    };
    if (action != null) {
      children.add(const SizedBox(height: 16));
      children.add(NeonButton(label: label, height: 52, scale: 1, onTap: action));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Widget _head(String title, String sub, {String? kicker}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kicker != null) ...[Kicker(kicker, size: 10, color: BoltColors.neon), const SizedBox(height: 6)],
        Text(title, style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 6),
        Text(sub, style: BoltText.a(13, color: BoltColors.muted, height: 1.45)),
      ],
    );
  }
}
