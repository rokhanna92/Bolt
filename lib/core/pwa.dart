import 'package:flutter/foundation.dart';

/// True in the browser build, the iPhone PWA. It decides what is hidden there
/// because it cannot work: reminders, the APK updater, volume-key logging,
/// widgets and shortcuts. Tests set it to check those screens.
bool isPwa = kIsWeb;
