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
    List<String>? hintsSeen,
  }) : hintsSeen = hintsSeen ?? [];

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
  );
}
