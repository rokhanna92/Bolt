import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/bolt_store.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import 'plaque_qr.dart';

/// The printable entrance plaque.
class PlaqueScreen extends ConsumerStatefulWidget {
  const PlaqueScreen({super.key});

  @override
  ConsumerState<PlaqueScreen> createState() => _PlaqueScreenState();
}

class _PlaqueScreenState extends ConsumerState<PlaqueScreen> {
  final _plaque = GlobalKey();

  /// Renders the plaque to a high-resolution PNG and opens the share sheet,
  /// from where it can be printed or saved.
  Future<void> _export() async {
    final store = ref.read(boltProvider.notifier);
    try {
      final boundary = _plaque.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 6);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bolt-plaque.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      store.toast('Plaque file ready');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'Bolt entrance plaque',
        ),
      );
    } catch (_) {
      store.toast('Could not create the print file');
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                const Kicker('ENTRANCE PLAQUE'),
              ],
            ),
            const SizedBox(height: 22),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: RepaintBoundary(
                  key: _plaque,
                  child: BoltBox(
                    color: BoltColors.ink,
                    radius: 24,
                    stroke: const Stroke(BoltColors.neon, 2),
                    shadows: const [BoxShadow(color: Color(0x2EC6FF1A), blurRadius: 40)],
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'BOLT',
                          style: BoltText.a(30, weight: 900, width: 125, spacing: .04, color: BoltColors.neon),
                        ),
                        const SizedBox(height: 16),
                        const AspectRatio(
                          aspectRatio: 1,
                          child: BoltBox(
                            color: BoltColors.text,
                            radius: 14,
                            padding: EdgeInsets.all(14),
                            child: PlaqueQr(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SCAN IN · SCAN OUT',
                          textAlign: TextAlign.center,
                          style: BoltText.m(11, spacing: .14, color: BoltColors.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This code never changes. The app decides check-in or check-out based on whether the member is already in.',
              textAlign: TextAlign.center,
              style: BoltText.a(13, color: BoltColors.muted, height: 1.5),
            ),
            const SizedBox(height: 18),
            OutlineButton(label: 'Download print file', onTap: _export),
          ],
        ),
      ),
    );
  }
}
