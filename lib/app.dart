import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'data/bolt_store.dart';
import 'theme/bolt_theme.dart';
import 'widgets/toast.dart';

class BoltApp extends ConsumerStatefulWidget {
  const BoltApp({super.key});

  @override
  ConsumerState<BoltApp> createState() => _BoltAppState();
}

class _BoltAppState extends ConsumerState<BoltApp> with WidgetsBindingObserver {
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final store = ref.read(boltProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      store.autoCloseStale();
      store.syncSessionReminders();
    });
    _minute = Timer.periodic(const Duration(minutes: 1), (_) => store.autoCloseStale());
  }

  @override
  void dispose() {
    _minute?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(repositoryProvider).flush();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(boltProvider.notifier).autoCloseStale();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Bolt',
      debugShowCheckedModeBanner: false,
      theme: buildBoltTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => Stack(children: [child!, const ToastLayer()]),
    );
  }
}
