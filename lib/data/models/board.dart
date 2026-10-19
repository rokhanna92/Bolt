// What the app's owner pushes to every phone: the times of the built-in
// reminders and their own notifications. Lives in notices.json in Bolt's
// repo; each phone keeps the last copy it read.

/// One notification from the owner.
class Push {
  Push({
    required this.id,
    required this.title,
    required this.body,
    this.titleSr = '',
    this.bodySr = '',
    this.at = 18 * 60,
    this.date,
    List<int>? days,
    this.to = 'all',
  }) : days = days ?? [];

  final String id;
  String title;
  String body;

  /// Serbian text; the English shows when it is empty.
  String titleSr;
  String bodySr;

  /// Minutes after midnight.
  int at;

  /// Day key when it goes out once; null repeats.
  String? date;

  /// Weekdays it repeats on, 1 (Monday) to 7; empty with no [date] is every
  /// day.
  final List<int> days;

  /// `all`, `solo`, `clients` (people with a coach) or `coaches`.
  String to;

  Push copy() => Push(
    id: id,
    title: title,
    body: body,
    titleSr: titleSr,
    bodySr: bodySr,
    at: at,
    date: date,
    days: [...days],
    to: to,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    if (titleSr.isNotEmpty) 'titleSr': titleSr,
    if (bodySr.isNotEmpty) 'bodySr': bodySr,
    'at': at,
    if (date != null) 'date': date,
    if (days.isNotEmpty) 'days': days,
    'to': to,
  };

  /// Null when it is not a usable push.
  static Push? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['title'] is! String) return null;
    final at = j['at'];
    return Push(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] is String ? j['body'] as String : '',
      titleSr: j['titleSr'] is String ? j['titleSr'] as String : '',
      bodySr: j['bodySr'] is String ? j['bodySr'] as String : '',
      at: at is int && at >= 0 && at < 24 * 60 ? at : 18 * 60,
      date: j['date'] is String ? j['date'] as String : null,
      days: [
        for (final d in j['days'] is List ? j['days'] as List : const [])
          if (d is int && d >= 1 && d <= 7) d,
      ],
      to: const {'all', 'solo', 'clients', 'coaches'}.contains(j['to']) ? j['to'] as String : 'all',
    );
  }
}

/// When the built-in reminders go out, in minutes.
class PushTimes {
  PushTimes({this.brief = 8 * 60, this.nudge = 9 * 60, this.before = 120, this.checkout = 180});

  /// Morning brief on training days, after midnight.
  int brief;

  /// Days-off nudge, after midnight.
  int nudge;

  /// Session reminder, before the usual check-in.
  int before;

  /// Check-out reminder, after checking in.
  int checkout;

  PushTimes copy() => PushTimes(brief: brief, nudge: nudge, before: before, checkout: checkout);

  Map<String, dynamic> toJson() => {'brief': brief, 'nudge': nudge, 'before': before, 'checkout': checkout};

  factory PushTimes.fromJson(Object? j) {
    int pick(String k, int fallback, int max) {
      final v = j is Map ? j[k] : null;
      return v is int && v > 0 && v < max ? v : fallback;
    }

    return PushTimes(
      brief: pick('brief', 8 * 60, 24 * 60),
      nudge: pick('nudge', 9 * 60, 24 * 60),
      before: pick('before', 120, 12 * 60),
      checkout: pick('checkout', 180, 12 * 60),
    );
  }
}

class Board {
  Board({PushTimes? times, List<Push>? pushes}) : times = times ?? PushTimes(), pushes = pushes ?? [];

  final PushTimes times;
  final List<Push> pushes;

  Board copy() => Board(times: times.copy(), pushes: [for (final p in pushes) p.copy()]);

  Map<String, dynamic> toJson() => {'times': times.toJson(), 'pushes': pushes.map((p) => p.toJson()).toList()};

  /// Anything unreadable is left out rather than failing the whole board.
  factory Board.fromJson(Object? j) => Board(
    times: PushTimes.fromJson(j is Map ? j['times'] : null),
    pushes: [for (final p in j is Map && j['pushes'] is List ? j['pushes'] as List : const []) ?Push.fromJson(p)],
  );
}
