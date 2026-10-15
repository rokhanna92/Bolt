import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/l10n.dart';

import 'app/actions.dart';
import 'app/router.dart';
import 'data/bolt_store.dart';
import 'services/shortcuts.dart';
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
      store.syncGymTimer();
      AppShortcuts.listen(openShortcut);
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
      title: tx('Bolt'),
      debugShowCheckedModeBanner: false,
      theme: buildBoltTheme(),
      routerConfig: ref.watch(routerProvider),
      // The layout is pixel-tuned to the prototype; allow larger system text
      // but cap it so fixed-size controls keep their shape.
      // A language change rebuilds every screen, constant widgets included.
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(ref.watch(boltProvider.select((d) => d.settings.lang))),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: Stack(children: [child!, const ToastLayer()]),
        ),
      ),
    );
  }
}
