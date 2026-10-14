import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/bolt_store.dart';
import 'data/repositories/bolt_repository.dart';
import 'data/seed/content.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final repo = await BoltRepository.open();
  final notifications = await LocalNotifications.init();
  // Everything lives on this phone. First launch (or an old demo install)
  // starts empty and goes through onboarding.
  final data = repo.load() ?? freshData();

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        notificationsProvider.overrideWithValue(notifications),
        initialDataProvider.overrideWithValue(data),
      ],
      child: const BoltApp(),
    ),
  );
}
