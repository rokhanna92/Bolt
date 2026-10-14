import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bolt_store.dart';

/// Simple mutable UI value.
class Value<T> extends Notifier<T> {
  Value(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T v) => state = v;
}

/// First day of the month shown on the trainee's Plan calendar.
final planMonthProvider = NotifierProvider<MonthValue, DateTime>(MonthValue.new);

class MonthValue extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = ref.read(clockProvider)();
    return DateTime(n.year, n.month);
  }

  void set(DateTime d) => state = DateTime(d.year, d.month);

  void shift(int by) => state = DateTime(state.year, state.month + by);
}

/// Day key of the session being moved on the Plan tab.
final moveFromProvider = NotifierProvider<Value<String?>, String?>(() => Value(null));

/// Week offset on the coach Schedule tab.
final scheduleWeekProvider = NotifierProvider<Value<int>, int>(() => Value(0));

/// Learn tab: w (workouts), e (exercises), s (supplements).
final learnTabProvider = NotifierProvider<Value<String>, String>(() => Value('w'));
