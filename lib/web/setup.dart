import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web/web.dart' as web;

import '../services/notifications.dart';
import '../services/rest_timer.dart';
import 'fonts.dart';
import 'frame.dart';
import 'rest_timer.dart';

// What main.dart and app.dart need that differs in the browser. On a phone
// services/platform_setup.dart stands in this file's place.

/// No reminders in the browser: there is no push server.
Future<BoltNotifications> openNotifications() async => const NoopNotifications();

RestTimer platformRestTimer(BoltNotifications notifications) => WebRestTimer();

Widget platformFrame(Widget child) => WebFrame(child: child);

Future<void> startPlatform() async {
  _coverWholeScreen();
  _keepScreenOn();
  // Ask the browser not to clear Bolt's data when the phone runs short.
  try {
    web.window.navigator.storage.persist();
  } catch (_) {
    // Older iPhones do not have this.
  }
  // The QR reader ships with Bolt instead of coming from a CDN, so scanning
  // works on a gym's bad signal.
  MobileScannerPlatform.instance
    ..setWebBarcodeReader(WebBarcodeReader.zxingJs)
    ..setBarcodeLibraryScriptUrl('vendor/zxing.min.js');
  await ensureFonts();
}

/// Flutter writes its own viewport tag, without the part that lets the page
/// reach under an iPhone's notch and home bar.
void _coverWholeScreen() {
  final tags = web.document.querySelectorAll('meta[name="viewport"]');
  for (var i = 0; i < tags.length; i++) {
    final tag = tags.item(i) as web.HTMLMetaElement;
    if (!tag.content.contains('viewport-fit')) tag.content = '${tag.content}, viewport-fit=cover';
  }
}

/// The screen stays on while Bolt is open, as it does on Android. A browser
/// drops the lock whenever the page hides, so it is asked for again.
void _keepScreenOn() {
  web.WakeLockSentinel? lock;
  var asking = false;
  Future<void> ask() async {
    if (asking || web.document.hidden || (lock != null && !lock!.released)) return;
    asking = true;
    try {
      lock = await web.window.navigator.wakeLock.request('screen').toDart;
    } catch (_) {
      // Unsupported, or the browser wants a touch first.
    }
    asking = false;
  }

  void onEvent(web.Event _) => ask();
  web.document.addEventListener('visibilitychange', onEvent.toJS);
  web.window.addEventListener('pointerup', onEvent.toJS);
  ask();
}
