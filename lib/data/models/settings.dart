class AppSettings {
  AppSettings({
    this.remind = true,
    this.checkout = true,
    this.kg = true,
    this.restSecs = 90,
    this.mondayFirst = true,
    this.gymName = '',
    this.recapSeen,
    this.lang = 'en',
  });

  /// Session reminders, 2 hours before a planned session.
  bool remind;

  /// Check-out reminder after 3 hours.
  bool checkout;

  /// kg (true) or lb (false). Loads are stored in kg and converted on display.
  bool kg;
  int restSecs;
  bool mondayFirst;

  /// Home gym, as the user named it.
  String gymName;

  /// Monday key of the week whose recap card was closed.
  String? recapSeen;

  /// App language: `en` or `sr` (Serbian, Latin script).
  String lang;

  Map<String, dynamic> toJson() => {
    'remind': remind,
    'checkout': checkout,
    'kg': kg,
    'restSecs': restSecs,
    'mondayFirst': mondayFirst,
    'gymName': gymName,
    'recapSeen': recapSeen,
    'lang': lang,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    remind: j['remind'] as bool? ?? true,
    checkout: j['checkout'] as bool? ?? true,
    kg: j['kg'] as bool? ?? true,
    restSecs: j['restSecs'] as int? ?? 90,
    mondayFirst: j['mondayFirst'] as bool? ?? true,
    gymName: j['gymName'] as String? ?? '',
    recapSeen: j['recapSeen'] as String?,
    lang: j['lang'] as String? ?? 'en',
  );
}
