// Date and text helpers ported from the prototype's script so every label
// reads exactly the same.

const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const monthsLong = [
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

/// `Wed 14 Oct`
String fmtDay(String k) {
  final d = pk(k);
  return '${weekdays[jsDay(d)]} ${d.day} ${monthsShort[d.month - 1]}';
}

String hm(DateTime d) => '${pad(d.hour)}:${pad(d.minute)}';

/// `1h 07m` or `42m`.
String dur(num m) {
  final x = m < 0 ? 0 : m.round();
  return x >= 60 ? '${x ~/ 60}h ${pad(x % 60)}m' : '${x}m';
}

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

String plural(int n, String w) => '$n $w${n == 1 ? '' : 's'}';

/// Workout title auto-size: <=6 chars base, <=9 74 %, longer 56 %.
double tsz(String? name, double big) {
  final n = (name ?? '').length;
  return (n <= 6
      ? big
      : n <= 9
      ? (big * .74).roundToDouble()
      : (big * .56).roundToDouble());
}
