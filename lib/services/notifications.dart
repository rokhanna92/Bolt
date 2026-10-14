import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// A reminder the app wants on the device.
class Reminder {
  const Reminder({required this.at, required this.title, required this.body});

  final DateTime at;
  final String title;
  final String body;
}

/// Local reminders: the check-out nudge and session reminders.
abstract class BoltNotifications {
  Future<void> scheduleCheckout(Reminder r);
  Future<void> cancelCheckout();

  /// Replaces every scheduled session reminder with [list].
  Future<void> replaceSessionReminders(List<Reminder> list);
}

class NoopNotifications implements BoltNotifications {
  const NoopNotifications();

  @override
  Future<void> scheduleCheckout(Reminder r) async {}

  @override
  Future<void> cancelCheckout() async {}

  @override
  Future<void> replaceSessionReminders(List<Reminder> list) async {}
}

class LocalNotifications implements BoltNotifications {
  LocalNotifications._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _checkoutId = 1;
  static const _sessionBase = 100;
  static const _sessionSlots = 14;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'bolt_reminders',
      'Reminders',
      channelDescription: 'Session and check-out reminders',
      importance: Importance.high,
      priority: Priority.high,
      color: _neon,
    ),
    iOS: DarwinNotificationDetails(),
  );
  static const _neon = Color(0xFFC6FF1A);

  static Future<BoltNotifications> init() async {
    try {
      tzdata.initializeTimeZones();
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      return LocalNotifications._(plugin);
    } catch (_) {
      // Reminders are a convenience; the app works without them.
      return const NoopNotifications();
    }
  }

  Future<void> _ensurePermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _schedule(int id, Reminder r) async {
    if (!r.at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: id,
      title: r.title,
      body: r.body,
      scheduledDate: tz.TZDateTime.from(r.at, tz.local),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> scheduleCheckout(Reminder r) async {
    try {
      await _ensurePermission();
      await _schedule(_checkoutId, r);
    } catch (_) {}
  }

  @override
  Future<void> cancelCheckout() async {
    try {
      await _plugin.cancel(id: _checkoutId);
    } catch (_) {}
  }

  @override
  Future<void> replaceSessionReminders(List<Reminder> list) async {
    try {
      for (var i = 0; i < _sessionSlots; i++) {
        await _plugin.cancel(id: _sessionBase + i);
      }
      if (list.isEmpty) return;
      await _ensurePermission();
      for (var i = 0; i < list.length && i < _sessionSlots; i++) {
        await _schedule(_sessionBase + i, list[i]);
      }
    } catch (_) {}
  }
}
