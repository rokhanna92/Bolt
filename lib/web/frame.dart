import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../data/bolt_store.dart';
import 'install_guide.dart';

/// Fits Bolt to a browser. Flutter reports no safe areas on the web, so on an
/// iPhone the page would slide under the notch and home bar: they are read
/// from CSS here. On a wide screen Bolt stays phone-sized, so the layout is
/// the one it was made for.
class WebFrame extends StatefulWidget {
  const WebFrame({super.key, required this.child});

  final Widget child;

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  static const _maxWidth = 480.0;

  // padding: env(...) on a hidden element; the browser works out the pixels.
  late final _probe = web.HTMLDivElement()
    ..style.setProperty('position', 'fixed')
    ..style.setProperty('visibility', 'hidden')
    ..style.setProperty('pointer-events', 'none')
    ..style.setProperty(
      'padding',
      'env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)',
    );
  late final _onResize = ((web.Event _) => _read()).toJS;
  EdgeInsets _safe = EdgeInsets.zero;
  bool _skipGuide = false;

  @override
  void initState() {
    super.initState();
    web.document.body!.append(_probe);
    web.window.addEventListener('resize', _onResize);
    web.window.addEventListener('orientationchange', _onResize);
    _read();
  }

  @override
  void dispose() {
    web.window.removeEventListener('resize', _onResize);
    web.window.removeEventListener('orientationchange', _onResize);
    _probe.remove();
    super.dispose();
  }

  void _read() {
    final css = web.window.getComputedStyle(_probe);
    double px(String v) => double.tryParse(v.replaceAll('px', '')) ?? 0;
    final safe = EdgeInsets.fromLTRB(
      px(css.paddingLeft),
      px(css.paddingTop),
      px(css.paddingRight),
      px(css.paddingBottom),
    );
    if (safe != _safe) setState(() => _safe = safe);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final width = math.min(mq.size.width, _maxWidth);
    // The larger of the two, never both: a browser that reports its own insets
    // would otherwise count them twice. Nothing is kept at the bottom, so the
    // nav bar sits right down at the edge, as on Android.
    final padding = EdgeInsets.fromLTRB(
      math.max(mq.padding.left, _safe.left),
      math.max(mq.padding.top, _safe.top),
      math.max(mq.padding.right, _safe.right),
      0,
    );
    return ScrollConfiguration(
      behavior: const _WebScroll(),
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: width,
            child: ClipRect(
              child: MediaQuery(
                data: mq.copyWith(size: Size(width, mq.size.height), padding: padding, viewPadding: padding),
                child: Stack(
                  children: [
                    widget.child,
                    // A new phone in a browser tab gets the steps to install first.
                    if (!_skipGuide && shouldGuideInstall())
                      Consumer(
                        builder: (context, ref, _) => ref.watch(boltProvider.select((d) => d.account == null))
                            ? Positioned.fill(
                                child: BlockSemantics(
                                  child: InstallGuide(onSkip: () => setState(() => _skipGuide = true)),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// No scrollbars, and a mouse can drag like a finger, for testing on a computer.
class _WebScroll extends MaterialScrollBehavior {
  const _WebScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}
