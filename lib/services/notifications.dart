import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';

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

  /// A live gym timer in the notification shade, counting up from [since].
  Future<void> showInGym(DateTime since, String sinceText);
  Future<void> clearInGym();

  /// A rest countdown to [end] that shows on the lock screen.
  Future<void> showRest(DateTime end, String next);
  Future<void> clearRest();
}

class NoopNotifications implements BoltNotifications {
  const NoopNotifications();

  @override
  Future<void> scheduleCheckout(Reminder r) async {}

  @override
  Future<void> cancelCheckout() async {}

  @override
  Future<void> replaceSessionReminders(List<Reminder> list) async {}

  @override
  Future<void> showInGym(DateTime since, String sinceText) async {}

  @override
  Future<void> clearInGym() async {}

  @override
  Future<void> showRest(DateTime end, String next) async {}

  @override
  Future<void> clearRest() async {}
}

class LocalNotifications implements BoltNotifications {
  LocalNotifications._(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _checkoutId = 1;
  static const _inGymId = 2;
  static const _restId = 3;
  static const _sessionBase = 100;
  static const _sessionSlots = 24;

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
  Future<void> showInGym(DateTime since, String sinceText) async {
    try {
      await _ensurePermission();
      await _plugin.show(
        id: _inGymId,
        title: tx('In the gym'),
        body: tx('Since {time} · scan the plaque on your way out', {'time': sinceText}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'bolt_gym_timer',
            tx('Gym timer'),
            channelDescription: tx('Live time while you are checked in'),
            importance: Importance.low,
            priority: Priority.low,
            icon: 'ic_stat_bolt',
            color: _neon,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            showWhen: true,
            when: since.millisecondsSinceEpoch,
            usesChronometer: true,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Future<void> clearInGym() async {
    try {
      await _plugin.cancel(id: _inGymId);
    } catch (_) {}
  }

  @override
  Future<void> showRest(DateTime end, String next) async {
    try {
      final ms = end.difference(DateTime.now()).inMilliseconds;
      if (ms <= 0) return;
      await _plugin.show(
        id: _restId,
        title: tx('Rest'),
        body: next,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'bolt_rest_timer',
            tx('Rest timer'),
            channelDescription: tx('Countdown between sets'),
            importance: Importance.low,
            priority: Priority.low,
            icon: 'ic_stat_bolt',
            color: _neon,
            onlyAlertOnce: true,
            silent: true,
            showWhen: true,
            when: end.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: ms,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Future<void> clearRest() async {
    try {
      await _plugin.cancel(id: _restId);
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
