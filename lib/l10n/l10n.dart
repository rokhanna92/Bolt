// App language. Text is written in English in the code and looked up in the
// Serbian (Latin script) table when Serbian is on; anything without a
// translation (names you typed, custom workouts) shows as written.

import 'sr.dart';
import 'sr_female.dart';

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

/// The phone owner set Female: Serbian uses female word forms when talking
/// to them. Set by the store.
bool appFemale = false;

/// [en] in the current language. `{name}` placeholders are filled from
/// [args] after translating, so names and numbers are never changed.
String tx(String en, [Map<String, Object?> args = const {}]) {
  var s = isSerbian ? ((appFemale ? kSrFemale[en] : null) ?? kSr[en] ?? en) : en;
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

/// A first name for addressing someone, in Serbian the vocative: Danijel →
/// Danijele, Miloš → Milošu, Petar → Petre, Vuk → Vuče, Milica → Milice.
/// Names ending in another vowel (Marko, Ana, Luka) stay as they are, and
/// English leaves every name alone.
String vocative(String name) {
  if (!isSerbian || name.length < 2) return name;
  final low = name.toLowerCase();
  final up = name == name.toUpperCase();
  String end(int cut, String add) => name.substring(0, name.length - cut) + (up ? add.toUpperCase() : add);
  if (low.endsWith('ica')) return end(1, 'e');
  if (RegExp(r'[aeiou]$').hasMatch(low)) return name;
  if (RegExp(r'(j|č|ć|đ|š|ž)$').hasMatch(low)) return end(0, 'u');
  if (RegExp(r'[^aeiou]ar$').hasMatch(low)) return end(2, 're');
  if (low.endsWith('k') || low.endsWith('c')) return end(1, 'če');
  if (low.endsWith('g')) return end(1, 'že');
  if (low.endsWith('h')) return end(1, 'še');
  return end(0, 'e');
}
