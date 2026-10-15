import '../seed/splits.dart';

/// A weekly split the user built: a workout template per weekday.
class CustomSplit {
  CustomSplit({required this.id, required this.name, Map<int, String>? days}) : days = days ?? {};

  final String id;
  String name;

  /// Template id per weekday, 1 = Monday ... 7 = Sunday. Missing days rest.
  final Map<int, String> days;

  Split toSplit() => Split(
    name: name,
    short: name,
    custom: true,
    days: [
      for (final wd in kWeekOrder)
        if (days[wd] != null) SplitDay(wd, days[wd]!),
    ],
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'days': days.map((k, v) => MapEntry('$k', v))};

  factory CustomSplit.fromJson(Map<String, dynamic> j) => CustomSplit(
    id: j['id'] as String,
    name: j['name'] as String,
    days: (j['days'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as String)),
  );
}
