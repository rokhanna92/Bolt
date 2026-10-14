class AppSettings {
  AppSettings({
    this.remind = true,
    this.plans = true,
    this.checkout = true,
    this.kg = true,
    this.restSecs = 90,
    this.mondayFirst = true,
  });

  /// Session reminders, 2 hours before a planned session.
  bool remind;

  /// Plan update notifications.
  bool plans;

  /// Check-out reminder after 3 hours.
  bool checkout;

  /// kg (true) or lb (false). Loads are stored in kg and converted on display.
  bool kg;
  int restSecs;
  bool mondayFirst;

  Map<String, dynamic> toJson() => {
    'remind': remind,
    'plans': plans,
    'checkout': checkout,
    'kg': kg,
    'restSecs': restSecs,
    'mondayFirst': mondayFirst,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    remind: j['remind'] as bool? ?? true,
    plans: j['plans'] as bool? ?? true,
    checkout: j['checkout'] as bool? ?? true,
    kg: j['kg'] as bool? ?? true,
    restSecs: j['restSecs'] as int? ?? 90,
    mondayFirst: j['mondayFirst'] as bool? ?? true,
  );
}
