// App language. Text is written in English in the code and looked up in the
// Serbian (Latin script) table when Serbian is on; anything without a
// translation (names you typed, custom workouts) shows as written.

import 'sr.dart';

enum AppLang {
  en('English', 'EN'),
  sr('Srpski', 'SR');

  const AppLang(this.label, this.short);

  /// Name in its own language, for the picker.
  final String label;
  final String short;

  static AppLang byName(String? n) => AppLang.values.firstWhere((l) => l.name == n, orElse: () => AppLang.en);
}

/// The language on show. Set by the store from the settings.
AppLang appLang = AppLang.en;

bool get isSerbian => appLang != AppLang.en;

/// [en] in the current language. `{name}` placeholders are filled from
/// [args] after translating, so names and numbers are never changed.
String tx(String en, [Map<String, Object?> args = const {}]) {
  var s = isSerbian ? (kSr[en] ?? en) : en;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Serbian noun forms: one (1, 21, 31...), few (2-4, 22-24...) and many.
int _srForm(int n) {
  final a = n.abs();
  if (a % 10 == 1 && a % 100 != 11) return 0;
  if (a % 10 >= 2 && a % 10 <= 4 && (a % 100 < 12 || a % 100 > 14)) return 1;
  return 2;
}

/// "3 sessions" / "3 treninga". Serbian forms come from [kSrNouns]; an
/// unknown word falls back to English.
String plural(int n, String w) {
  if (isSerbian) {
    final forms = kSrNouns[w];
    if (forms != null) return '$n ${forms[_srForm(n)]}';
  }
  return '$n $w${n == 1 ? '' : 's'}';
}
