/// A closed gym visit.
class Visit {
  Visit({
    required this.date,
    required this.inT,
    required this.outT,
    required this.mins,
    this.auto = false,
  });

  /// Day key of the check-in, so visits across midnight stay on their day.
  final String date;
  final String inT;
  final String outT;
  final int mins;

  /// Closed automatically after 5 hours.
  final bool auto;

  Map<String, dynamic> toJson() => {'date': date, 'inT': inT, 'outT': outT, 'mins': mins, 'auto': auto};

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        date: j['date'] as String,
        inT: j['inT'] as String,
        outT: j['outT'] as String,
        mins: j['mins'] as int,
        auto: j['auto'] as bool? ?? false,
      );
}

/// An open visit.
class GymIn {
  GymIn({required this.at, required this.base, required this.since});

  /// Epoch milliseconds when [base] was measured.
  final int at;

  /// Minutes already elapsed at [at].
  final double base;

  /// Check-in clock time, `HH:MM`.
  final String since;

  double elapsedMinutes(DateTime now) => base + (now.millisecondsSinceEpoch - at) / 60000;

  DateTime checkInTime() =>
      DateTime.fromMillisecondsSinceEpoch(at).subtract(Duration(milliseconds: (base * 60000).round()));

  Map<String, dynamic> toJson() => {'at': at, 'base': base, 'since': since};

  factory GymIn.fromJson(Map<String, dynamic> j) =>
      GymIn(at: j['at'] as int, base: (j['base'] as num).toDouble(), since: j['since'] as String);
}
