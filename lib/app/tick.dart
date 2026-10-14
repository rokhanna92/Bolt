import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bolt_store.dart';

/// Ticks twice a second for live timers. Only widgets that show a running
/// clock watch it.
final tickProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.read(clockProvider);
  return Stream.periodic(const Duration(milliseconds: 500), (_) => clock());
});

/// Current time for a live widget: rebuilds on every tick.
DateTime watchNow(WidgetRef ref) => ref.watch(tickProvider).value ?? ref.read(clockProvider)();
