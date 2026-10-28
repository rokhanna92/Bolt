import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bolt_store.dart' show clockProvider;

/// The stopwatch as a watch in your pocket: it keeps running when you leave
/// its screen, and its time comes from the clock rather than from counted
/// frames, so it stays right whatever the app was doing in between.
class Watch {
  const Watch({this.since, this.carried = Duration.zero, this.laps = const []});

  /// When it was last started, or null while it is stopped.
  final DateTime? since;

  /// Time banked by earlier runs, before [since].
  final Duration carried;

  /// Total elapsed at each lap taken, oldest first.
  final List<Duration> laps;

  bool get running => since != null;

  /// Nothing run and nothing taken: the pusher has nothing to clear.
  bool get idle => !running && carried == Duration.zero && laps.isEmpty;

  Duration at(DateTime now) => running ? carried + now.difference(since!) : carried;

  /// How long the lap in progress has been going.
  Duration lapAt(DateTime now) => at(now) - (laps.isEmpty ? Duration.zero : laps.last);

  /// Each finished lap's own time, oldest first.
  List<Duration> get splits => [for (var i = 0; i < laps.length; i++) i == 0 ? laps[0] : laps[i] - laps[i - 1]];
}

class WatchNotifier extends Notifier<Watch> {
  @override
  Watch build() => const Watch();

  DateTime get _now => ref.read(clockProvider)();

  /// The crown: runs and stops, holding the time where it is when stopped.
  void startStop() {
    state = state.running
        ? Watch(carried: state.at(_now), laps: state.laps)
        : Watch(since: _now, carried: state.carried, laps: state.laps);
  }

  /// The side pusher: a lap while it runs, back to zero once it is stopped.
  void lapOrReset() {
    state = state.running
        ? Watch(since: state.since, carried: state.carried, laps: [...state.laps, state.at(_now)])
        : const Watch();
  }
}

final watchProvider = NotifierProvider<WatchNotifier, Watch>(WatchNotifier.new);
