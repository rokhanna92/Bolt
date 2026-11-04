import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'notifications.dart';
import 'rest_timer.dart';

// What main.dart and app.dart need that differs in the browser. In a web build
// web/setup.dart stands in this file's place.

Future<BoltNotifications> openNotifications() => LocalNotifications.init();

RestTimer platformRestTimer(BoltNotifications notifications) =>
    Platform.isAndroid ? AndroidRestTimer() : NotificationRestTimer(notifications);

Widget platformFrame(Widget child) => child;

void startPlatform() {}
