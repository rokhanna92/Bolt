import 'board.dart';

class AppSettings {
  AppSettings({
    this.remind = true,
    this.brief = true,
    this.checkout = true,
    this.kg = true,
    this.restSecs = 90,
    this.mondayFirst = true,
    this.gymName = '',
    this.recapSeen,
    this.lang = 'en',
    this.restAuto = true,
    this.levelSeen,
    this.haptics = true,
    this.floor = false,
    this.restSound = 'chime',
    this.countdown = true,
    this.volumeLog = true,
    this.rankSeen,
    Board? board,
    List<String>? hintsSeen,
  }) : hintsSeen = hintsSeen ?? [],
       board = board ?? Board();

  /// Session reminders, 2 hours before a planned session.
  bool remind;

  /// Morning brief at 8:00 on training days.
  bool brief;

  /// Check-out reminder after 3 hours.
  bool checkout;

  /// kg (true) or lb (false). Loads are stored in kg and converted on display.
  bool kg;

  /// Fixed rest after a set, used when [restAuto] is off.
  int restSecs;

  /// Rest picked per exercise: long for big lifts, short for isolation.
  bool restAuto;

  /// Suggestions on Today that were closed, by id.
  final List<String> hintsSeen;
  bool mondayFirst;

  /// Home gym, as the user named it.
  String gymName;

  /// Monday key of the week whose recap card was closed.
  String? recapSeen;

  /// App language: `en` or `sr` (Serbian, Latin script).
  String lang;

  /// Highest athlete level already celebrated.
  int? levelSeen;

  /// Haptic feedback on steps, sets and records.
  bool haptics;

  /// Workouts open in gym floor mode: one big set at a time.
  bool floor;

  /// Sound at the end of a rest: `chime`, `beep` or `off`.
  String restSound;

  /// Ticks (and blips, with a sound on) in the last 3 seconds of a rest.
  bool countdown;

  /// Volume down does the big button's job in gym floor mode.
  bool volumeLog;

  /// Highest rank step already celebrated.
  int? rankSeen;

  /// The owner's reminder times and pushes, as last read from notices.json.
  Board board;

  Map<String, dynamic> toJson() => {
    'remind': remind,
    'brief': brief,
    'checkout': checkout,
    'kg': kg,
    'restSecs': restSecs,
    'mondayFirst': mondayFirst,
    'gymName': gymName,
    'recapSeen': recapSeen,
    'lang': lang,
    'restAuto': restAuto,
    'hintsSeen': hintsSeen,
    'levelSeen': levelSeen,
    'haptics': haptics,
    'floor': floor,
    'restSound': restSound,
    'countdown': countdown,
    'volumeLog': volumeLog,
    'rankSeen': rankSeen,
    'board': board.toJson(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    remind: j['remind'] as bool? ?? true,
    brief: j['brief'] as bool? ?? true,
    checkout: j['checkout'] as bool? ?? true,
    kg: j['kg'] as bool? ?? true,
    restSecs: j['restSecs'] as int? ?? 90,
    mondayFirst: j['mondayFirst'] as bool? ?? true,
    gymName: j['gymName'] as String? ?? '',
    recapSeen: j['recapSeen'] as String?,
    lang: j['lang'] as String? ?? 'en',
    restAuto: j['restAuto'] as bool? ?? true,
    hintsSeen: [for (final x in j['hintsSeen'] as List? ?? const []) x as String],
    levelSeen: j['levelSeen'] as int?,
    haptics: j['haptics'] as bool? ?? true,
    floor: j['floor'] as bool? ?? false,
    restSound: j['restSound'] as String? ?? 'chime',
    countdown: j['countdown'] as bool? ?? true,
    volumeLog: j['volumeLog'] as bool? ?? true,
    rankSeen: j['rankSeen'] as int?,
    board: Board.fromJson(j['board']),
  );
}
