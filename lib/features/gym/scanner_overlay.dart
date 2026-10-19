import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';

import '../../app/actions.dart';
import '../../data/bolt_store.dart';
import '../../data/seed/content.dart';
import '../../services/haptics.dart';
import '../../services/shortcuts.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';
import '../plaque/plaque_qr.dart';

/// Full-screen scanner. The plaque QR toggles check-in / check-out; the
/// button below (or tapping the frame) does the same without a scan.
class ScannerRoute extends PageRouteBuilder<void> {
  ScannerRoute({bool fromShortcut = false, bool manual = false})
    : super(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, a, s) => ScannerOverlay(fromShortcut: fromShortcut, manual: manual),
        transitionsBuilder: (context, a, s, child) => FadeTransition(opacity: a, child: child),
      );
}

class ScannerOverlay extends ConsumerStatefulWidget {
  const ScannerOverlay({super.key, this.fromShortcut = false, this.manual = false});

  /// Opened from the app icon's shortcut: after checking in, Bolt steps out
  /// of the way and the timer keeps running in the notification.
  final bool fromShortcut;

  /// Checks in or out at once without the camera; only the result shows.
  final bool manual;

  @override
  ConsumerState<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends ConsumerState<ScannerOverlay> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  ScanOutcome? _done;
  bool _cameraFailed = false;
  DateTime _lastReject = DateTime(0);
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    if (widget.manual) WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _camera.dispose();
    super.dispose();
  }

  void _scan() {
    if (_done != null) return;
    Haptics.play(Feel.success);
    final res = ref.read(boltProvider.notifier).scan();
    setState(() => _done = res);
    if (!widget.manual) _camera.stop();
    // Up long enough to read it, or to undo a mistake; a tap closes it
    // sooner.
    _closeTimer = Timer(Duration(milliseconds: res.detail == null ? 4000 : 6000), _close);
  }

  /// A scan by mistake: everything goes back to how it was before it.
  void _undo() {
    _closeTimer?.cancel();
    if (!mounted) return;
    Haptics.play(Feel.off);
    ref.read(boltProvider.notifier).undoScan();
    Navigator.of(context).pop();
  }

  void _close() {
    _closeTimer?.cancel();
    final res = _done;
    if (!mounted || res == null) return;
    Navigator.of(context).pop();
    showUnlocks(res.unlocked);
    if (widget.fromShortcut && res.checkIn) AppShortcuts.toBackground();
  }

  void _onDetect(BarcodeCapture c) {
    if (_done != null) return;
    for (final b in c.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      if (Gym.isPlaque(raw)) {
        _scan();
        return;
      }
      final now = DateTime.now();
      if (now.difference(_lastReject).inSeconds >= 3) {
        _lastReject = now;
        ref.read(boltProvider.notifier).toast(tx('Not the Bolt plaque · try the code by the entrance'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final inGym = d.gymIn[d.account?.id] != null;
    final pad = MediaQuery.paddingOf(context);
    return BoltPage(
      color: BoltColors.scannerBg,
      child: Padding(
        padding: EdgeInsets.only(top: pad.top, bottom: pad.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      inGym ? tx('Scan to check out') : tx('Scan to check in'),
                      style: BoltText.a(18, weight: 800),
                    ),
                  ),
                  SquareButton(onTap: () => Navigator.of(context).pop(), label: '✕', fontSize: 16),
                ],
              ),
            ),
            Expanded(
              child: _done != null
                  ? _success(_done!)
                  : widget.manual
                  ? const SizedBox.shrink()
                  : _aim(inGym),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aim(bool inGym) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Tap(
            key: const Key('scan-frame'),
            onTap: _scan,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const RadialGradient(colors: [BoltColors.scannerWell, BoltColors.ink]),
              ),
              child: Stack(
                children: [
                  // The faded plaque from the prototype shows until the camera
                  // feed covers it, and stays if there is no camera.
                  const Positioned.fill(
                    left: 50,
                    top: 50,
                    right: 50,
                    bottom: 50,
                    child: Opacity(
                      opacity: .25,
                      child: BoltBox(color: BoltColors.text, radius: 8, padding: EdgeInsets.all(10), child: PlaqueQr()),
                    ),
                  ),
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _cameraFailed
                          ? const SizedBox.shrink()
                          : MobileScanner(
                              controller: _camera,
                              onDetect: _onDetect,
                              placeholderBuilder: (context) => const SizedBox.shrink(),
                              errorBuilder: (context, error) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && !_cameraFailed) setState(() => _cameraFailed = true);
                                });
                                return const SizedBox.shrink();
                              },
                            ),
                    ),
                  ),
                  const Positioned(left: 0, top: 0, child: _Corner(top: true, left: true)),
                  const Positioned(right: 0, top: 0, child: _Corner(top: true, left: false)),
                  const Positioned(left: 0, bottom: 0, child: _Corner(top: false, left: true)),
                  const Positioned(right: 0, bottom: 0, child: _Corner(top: false, left: false)),
                  const Positioned.fill(child: _Laser()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 260,
            child: Text(
              tx('Point at the plaque by the entrance.'),
              textAlign: TextAlign.center,
              style: BoltText.a(14, color: BoltColors.muted),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 260,
            child: OutlineButton(
              label: inGym ? tx('Check out without scanning') : tx('Check in without scanning'),
              onTap: _scan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _success(ScanOutcome r) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PopIn(
              duration: const Duration(milliseconds: 500),
              curve: const Cubic(.2, .8, .2, 1),
              child: Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: BoltColors.neon,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x73C6FF1A), blurRadius: 60)],
                ),
                child: const BoltIcon('check', size: 56, color: BoltColors.ink),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 400),
              child: Text(r.head.toUpperCase(), style: BoltText.a(34, weight: 900, width: 115)),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              duration: const Duration(milliseconds: 400),
              child: Text(
                r.sub,
                textAlign: TextAlign.center,
                style: BoltText.m(13, color: BoltColors.muted),
              ),
            ),
            if (r.hype != null) ...[
              const SizedBox(height: 18),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 450),
                child: Text(
                  r.hype!,
                  textAlign: TextAlign.center,
                  style: BoltText.a(22, weight: 900, color: BoltColors.neon, height: 1.15),
                ),
              ),
            ],
            if (r.detail != null) ...[
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 550),
                duration: const Duration(milliseconds: 400),
                child: Text(r.detail!, textAlign: TextAlign.center, style: BoltText.a(14, weight: 600, height: 1.45)),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: 220,
              child: OutlineButton(
                label: r.checkIn ? tx('Undo check-in') : tx('Undo check-out'),
                height: 46,
                color: BoltColors.text,
                borderColor: BoltColors.line,
                weight: 700,
                onTap: _undo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neon corner bracket: 44 px plus its 4 px border, 22 px outer radius.
class _Corner extends StatelessWidget {
  const _Corner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) => Transform.flip(
    flipX: !left,
    flipY: !top,
    child: const CustomPaint(size: Size(48, 48), painter: _CornerPainter()),
  );
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(2, size.height)
      ..lineTo(2, 22)
      ..arcToPoint(const Offset(22, 2), radius: const Radius.circular(20))
      ..lineTo(size.width, 2);
    canvas.drawPath(
      path,
      Paint()
        ..color = BoltColors.neon
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

/// Neon line sweeping 12 % -> 86 % -> 12 % every 2.2 s.
class _Laser extends StatefulWidget {
  const _Laser();

  @override
  State<_Laser> createState() => _LaserState();
}

class _LaserState extends State<_Laser> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(
            children: [
              Positioned(
                left: 18,
                right: 18,
                top: box.maxHeight * (.12 + .74 * t),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: BoltColors.neon,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [BoxShadow(color: Color(0x99C6FF1A), blurRadius: 18, spreadRadius: 4)],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
