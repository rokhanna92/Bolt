import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/bolt_store.dart';
import 'data/repositories/bolt_repository.dart';
import 'data/seed/demo.dart';
import 'services/notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final repo = await BoltRepository.open();
  final notifications = await LocalNotifications.init();
  var data = repo.load();
  if (data == null) {
    // First launch: seed the demo gym and keep it, so its dates stay put.
    data = buildDemoData(DateTime.now());
    repo.scheduleSave(data);
  }

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
