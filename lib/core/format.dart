// Date and text helpers ported from the prototype's script so every label
// reads exactly the same. Day and month names follow the app language.

import '../l10n/l10n.dart';

export '../l10n/l10n.dart' show AppLang, appFemale, appLang, isSerbian, plural, tx, txFor, vocative;

const _weekdaysEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _weekdaysSr = ['Ned', 'Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub'];
const _monthsShortEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsShortSr = ['jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'avg', 'sep', 'okt', 'nov', 'dec'];
const _monthsLongSr = [
  'Januar',
  'Februar',
  'Mart',
  'April',
  'Maj',
  'Jun',
  'Jul',
  'Avgust',
  'Septembar',
  'Oktobar',
  'Novembar',
  'Decembar',
];

List<String> _inLang(List<String> en, List<String> sr) => isSerbian ? sr : en;

/// Short day names, index 0 = Sunday (JS `getDay()`).
List<String> get weekdays => _inLang(_weekdaysEn, _weekdaysSr);
List<String> get monthsShort => _inLang(_monthsShortEn, _monthsShortSr);
List<String> get monthsLong => _inLang(_monthsLongEn, _monthsLongSr);

const _monthsLongEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String pad(int n) => n.toString().padLeft(2, '0');

/// Day key `YYYY-MM-DD`. Keys sort the same way as dates.
String dk(DateTime d) => '${d.year}-${pad(d.month)}-${pad(d.day)}';

DateTime pk(String k) {
  final a = k.split('-').map(int.parse).toList();
  return DateTime(a[0], a[1], a[2]);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// JS `getDay()`: 0 = Sunday.
int jsDay(DateTime d) => d.weekday % 7;

DateTime monday(DateTime d) => addDays(DateTime(d.year, d.month, d.day), -((jsDay(d) + 6) % 7));

DateTime weekStart(DateTime d, {required bool mondayFirst}) =>
    mondayFirst ? monday(d) : addDays(DateTime(d.year, d.month, d.day), -jsDay(d));

/// `14 Oct`, in Serbian `14. okt`.
String dayMonth(DateTime d) => '${d.day}${isSerbian ? '.' : ''} ${monthsShort[d.month - 1]}';

/// `Wed 14 Oct`, in Serbian `Sre 14. okt`.
String fmtDay(String k) {
  final d = pk(k);
  return '${weekdays[jsDay(d)]} ${dayMonth(d)}';
}

String hm(DateTime d) => '${pad(d.hour)}:${pad(d.minute)}';

/// `1h 07m` or `42m`.
String dur(num m) {
  final x = m < 0 ? 0 : m.round();
  return x >= 60 ? '${x ~/ 60}h ${pad(x % 60)}m' : '${x}m';
}

/// `45 min`, `2 h`, `1 h 30 min`.
String spanText(int m) => m < 60
    ? '$m min'
    : m % 60 == 0
    ? '${m ~/ 60} h'
    : '${m ~/ 60} h ${m % 60} min';

int toMin(String s) {
  final a = s.split(':').map(int.parse).toList();
  return a[0] * 60 + a[1];
}

String fromMin(num m) {
  final x = m.round();
  return '${pad((x ~/ 60) % 24)}:${pad(x % 60)}';
}

String firstName(String n) => n.trim().split(' ').first;

String initials(String n) {
  final s = n.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0]).join();
  return (s.length > 2 ? s.substring(0, 2) : s).toUpperCase();
}

/// Workout title auto-size: <=6 chars base, <=9 74 %, longer 56 %.
double tsz(String? name, double big) {
  final n = (name ?? '').length;
  return (n <= 6
      ? big
      : n <= 9
      ? (big * .74).roundToDouble()
      : (big * .56).roundToDouble());
}
