import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/bolt_store.dart';
import 'data/repositories/bolt_repository.dart';
import 'data/seed/content.dart';
import 'services/notifications.dart';
import 'services/rest_timer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Independent setup, so it runs side by side before the first frame.
  final (repo, notifications) = await (BoltRepository.open(), LocalNotifications.init()).wait;
  // Everything lives on this phone. First launch (or an old demo install)
  // starts empty and goes through onboarding.
  final data = repo.load() ?? freshData();
  addMissingTemplates(data);

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        notificationsProvider.overrideWithValue(notifications),
        restTimerProvider.overrideWithValue(
          Platform.isAndroid ? AndroidRestTimer() : NotificationRestTimer(notifications),
        ),
        initialDataProvider.overrideWithValue(data),
      ],
      child: const BoltApp(),
    ),
  );
}
