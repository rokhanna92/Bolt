import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bolt_store.dart' show boltProvider, clockProvider;
import '../../services/rest_timer.dart';

/// The stopwatch as a watch in your pocket: it keeps running when you leave
/// its screen, and its time comes from the clock rather than from counted
/// frames, so it stays right whatever the app was doing in between.
class Watch {
  const Watch({this.since, this.carried = Duration.zero, this.laps = const [], this.peak});

  /// When it was last started, or null while it is stopped.
  final DateTime? since;

  /// Time banked by earlier runs, before [since]. In reverse this is distance
  /// travelled since the turn at [peak], not the time on the display.
  final Duration carried;

  /// Total elapsed at each lap taken, oldest first.
  final List<Duration> laps;

  /// Set in reverse: the spot it turned at, and goes back and forth between
  /// it and zero until stopped.
  final Duration? peak;

  bool get reversing => peak != null;

  bool get running => since != null;

  /// Nothing run and nothing taken: the pusher has nothing to clear.
  bool get idle => !running && carried == Duration.zero && laps.isEmpty && !reversing;

  /// Everything run so far, ignoring direction.
  Duration travel(DateTime now) => running ? carried + now.difference(since!) : carried;

  Duration at(DateTime now) {
    final t = travel(now);
    final p = peak;
    if (p == null) return t;
    final along = Duration(microseconds: t.inMicroseconds % (p.inMicroseconds * 2));
    return along < p ? p - along : along - p;
  }

  /// In reverse: the next sound after [from], in travel. Each stretch counts
  /// its last 5 seconds down in blips, and the turn itself is the end cue.
  ({Duration at, bool end}) nextCue(Duration from) {
    final p = peak!.inMicroseconds;
    final leg = from.inMicroseconds ~/ p;
    final left = p - from.inMicroseconds % p;
    final secs = math.min(5, (left - 1) ~/ Duration.microsecondsPerSecond);
    return (at: Duration(microseconds: (leg + 1) * p - secs * Duration.microsecondsPerSecond), end: secs == 0);
  }

  /// How long the lap in progress has been going.
  Duration lapAt(DateTime now) => reversing ? Duration.zero : at(now) - (laps.isEmpty ? Duration.zero : laps.last);

  /// Each finished lap's own time, oldest first.
  List<Duration> get splits => [for (var i = 0; i < laps.length; i++) i == 0 ? laps[0] : laps[i] - laps[i - 1]];
}

class WatchNotifier extends Notifier<Watch> {
  @override
  Watch build() {
    ref.onDispose(() => _cue?.cancel());
    return const Watch();
  }

  Timer? _cue;

  DateTime get _now => ref.read(clockProvider)();

  /// The crown: runs and stops, holding the time where it is when stopped.
  void startStop() {
    state = state.running
        ? Watch(carried: state.travel(_now), laps: state.laps, peak: state.peak)
        : Watch(since: _now, carried: state.carried, laps: state.laps, peak: state.peak);
    _armCue(state.travel(_now));
  }

  /// Turns here and heads back to zero, then keeps going back and forth
  /// between zero and this spot. Under a second there is nothing to go back
  /// over, so that returns false.
  bool reverse() {
    final spot = state.at(_now);
    if (state.reversing || spot < const Duration(seconds: 1)) return false;
    state = Watch(since: _now, laps: state.laps, peak: spot);
    _armCue(Duration.zero);
    return true;
  }

  /// Times the next sound off the clock. A cue that comes due long after its
  /// moment (the phone slept) is dropped rather than played late.
  void _armCue(Duration from) {
    _cue?.cancel();
    _cue = null;
    if (!state.running || !state.reversing) return;
    final cue = state.nextCue(from);
    _cue = Timer(cue.at - state.travel(_now), () {
      final t = state.travel(_now);
      if (t - cue.at < const Duration(milliseconds: 500)) _play(end: cue.end);
      _armCue(t > cue.at ? t : cue.at);
    });
  }

  void _play({required bool end}) {
    final chosen = ref.read(boltProvider).settings.restSound;
    final sound = chosen == 'off' ? 'beep' : chosen;
    final timer = ref.read(restTimerProvider);
    end ? timer.preview(sound) : timer.blip(sound);
  }

  /// The side pusher: a lap while it runs, back to zero once it is stopped.
  void lapOrReset() {
    if (state.running && state.reversing) return;
    state = state.running
        ? Watch(since: state.since, carried: state.carried, laps: [...state.laps, state.at(_now)])
        : const Watch();
  }
}

final watchProvider = NotifierProvider<WatchNotifier, Watch>(WatchNotifier.new);
