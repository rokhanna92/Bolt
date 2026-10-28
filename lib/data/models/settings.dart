import 'board.dart';

/// One go at the key screen: which key, when, and how it went (`in`,
/// `pending` for a coach key the owner has not switched on, or `bad`).
class KeyEntry {
  KeyEntry({required this.name, required this.at, required this.how});

  final String name;
  final DateTime at;
  final String how;

  Map<String, dynamic> toJson() => {'name': name, 'at': at.toIso8601String(), 'how': how};

  factory KeyEntry.fromJson(Map<String, dynamic> j) =>
      KeyEntry(name: j['name'] as String? ?? '', at: DateTime.parse(j['at'] as String), how: j['how'] as String? ?? '');
}

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
    this.keyGen = 0,
    this.watchFace = 'dial',
    Board? board,
    List<String>? hintsSeen,
    List<int>? coachKeysOn,
    List<KeyEntry>? keyLog,
  }) : hintsSeen = hintsSeen ?? [],
       coachKeysOn = coachKeysOn ?? [],
       keyLog = keyLog ?? [],
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

  /// Which stopwatch face is on: `dial` (the chronograph) or `digital`
  /// (big counter inside a sweeping ring).
  String watchFace;

  /// The key generation this phone last got through. Below `kKeyGen` the app
  /// asks for a key again before it opens.
  int keyGen;

  /// Coach keys the owner has switched on, numbered as in `licenses.dart`. A
  /// coach key that is not in here is recognised but waits for activation.
  final List<int> coachKeysOn;

  /// Every go at the key screen, oldest first, trimmed to the last 60.
  final List<KeyEntry> keyLog;

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
    'keyGen': keyGen,
    'watchFace': watchFace,
    'coachKeysOn': coachKeysOn,
    'keyLog': [for (final e in keyLog) e.toJson()],
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
    keyGen: j['keyGen'] as int? ?? 0,
    watchFace: j['watchFace'] as String? ?? 'dial',
    coachKeysOn: [for (final x in j['coachKeysOn'] as List? ?? const []) x as int],
    keyLog: [for (final x in j['keyLog'] as List? ?? const []) KeyEntry.fromJson(x as Map<String, dynamic>)],
    board: Board.fromJson(j['board']),
  );
}
