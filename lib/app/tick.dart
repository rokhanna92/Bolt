import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bolt_store.dart';
import '../data/models/visit.dart';

/// Ticks twice a second for live timers. Only widgets that show a running
/// clock watch it.
final tickProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.read(clockProvider);
  return Stream.periodic(const Duration(milliseconds: 500), (_) => clock());
});

/// Current time for a live widget: rebuilds on every tick.
DateTime watchNow(WidgetRef ref) => ref.watch(tickProvider).value ?? ref.read(clockProvider)();

/// Current time for live gym minutes: rebuilds only when one of [live]
/// passes a whole minute, not on every tick.
DateTime watchMinutes(WidgetRef ref, Iterable<GymIn> live) {
  final clock = ref.read(clockProvider);
  ref.watch(tickProvider.select((t) => live.map((g) => g.elapsedMinutes(t.value ?? clock()).floor()).join(',')));
  return clock();
}
