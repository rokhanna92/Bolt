// Menstrual cycle tracking: where someone is in their cycle and what that
// usually means for training. Logged starts stay on the phone.

import '../core/format.dart';

class CycleInfo {
  const CycleInfo({required this.day, required this.length, required this.phase, required this.dueIn});

  /// Day of the cycle, the start being day 1.
  final int day;

  /// Average length from the logged starts, 28 until there are two.
  final int length;

  /// `period`, `follicular`, `ovulation`, `luteal` or `pre`.
  final String phase;

  /// Days until the next period is expected; 0 or less when it is due.
  final int dueIn;
}

/// Phase names by key.
const kCyclePhases = {
  'period': 'Period',
  'follicular': 'Follicular phase',
  'ovulation': 'Around ovulation',
  'luteal': 'Luteal phase',
  'pre': 'Before your period',
};

/// What each phase usually means for training.
const kCycleTips = {
  'period': 'Energy can be low the first days. Train by feel; going lighter is fine.',
  'follicular': 'Energy and strength usually climb. A good stretch to push for PRs.',
  'ovulation': 'Strength often peaks around now. Warm up well, joints can feel a bit looser.',
  'luteal': 'Recovery can feel slower and heat harder. Keep the plan, adjust loads by feel.',
  'pre': 'Strength can dip in the days before a period. Going lighter is fine.',
};

/// The cycle on [now] from logged [starts] (day keys, any order). Null with
/// nothing logged, or when the last start is over 60 days back.
CycleInfo? cycleInfo(List<String> starts, DateTime now) {
  if (starts.isEmpty) return null;
  final days = [for (final s in starts) pk(s)]..sort();
  final gaps = [
    for (var i = days.length - 1; i > 0 && i >= days.length - 4; i--) days[i].difference(days[i - 1]).inDays,
  ].where((g) => g >= 20 && g <= 45).toList();
  final length = gaps.isEmpty ? 28 : (gaps.reduce((a, b) => a + b) / gaps.length).round();
  final today = DateTime(now.year, now.month, now.day);
  final day = today.difference(days.last).inDays + 1;
  if (day < 1 || day > 60) return null;
  final dueIn = length - day + 1;
  final phase = day <= 5
      ? 'period'
      : dueIn <= 5
      ? 'pre'
      : day <= length - 15
      ? 'follicular'
      : day <= length - 12
      ? 'ovulation'
      : 'luteal';
  return CycleInfo(day: day, length: length, phase: phase, dueIn: dueIn);
}
