import 'custom_split.dart';
import 'exercise.dart';
import 'people.dart';
import 'session.dart';
import 'settings.dart';
import 'template.dart';
import 'visit.dart';

/// How the phone's owner trains. Solo and trainee both use the trainee
/// screens; a trainee also follows plans from a coach.
enum Role { solo, trainee, coach }

/// The phone's owner. One person per phone; their data never leaves it except
/// through plans and updates they choose to share.
class Account {
  const Account(this.role, this.id, {this.admin = false});

  /// Id of the owner's own trainee or coach record.
  static const ownerId = 'me';

  final Role role;
  final String id;

  /// Unlocked with the admin key: has both a coach and a trainee record and
  /// can switch between all three roles.
  final bool admin;

  bool get isCoach => role == Role.coach;

  /// Uses the trainee screens (solo or trainee).
  bool get isTrainee => role != Role.coach;
  bool get isSolo => role == Role.solo;

  Map<String, dynamic> toJson() => {'role': role.name, 'id': id, 'admin': admin};

  factory Account.fromJson(Map<String, dynamic> j) =>
      Account(Role.values.byName(j['role'] as String), j['id'] as String, admin: j['admin'] as bool? ?? false);
}

/// The workout in progress: which sets are checked per exercise id.
class ActiveWorkout {
  ActiveWorkout({required this.key, Map<String, List<bool>>? done, Map<String, Map<int, SetLog>>? logs})
    : done = done ?? {},
      logs = logs ?? {};

  final String key;
  final Map<String, List<bool>> done;

  /// Weight and reps per exercise id and set index, for ticked sets.
  final Map<String, Map<int, SetLog>> logs;

  SetLog? log(String exId, int i) => logs[exId]?[i];

  bool isDone(String exId, int i) {
    final a = done[exId];
    return a != null && i < a.length && a[i];
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'done': done,
    'logs': logs.map((id, m) => MapEntry(id, m.map((i, l) => MapEntry('$i', l.toJson())))),
  };

  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
    key: j['key'] as String,
    done: (j['done'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).map((x) => x as bool).toList())),
    logs: (j['logs'] as Map<String, dynamic>? ?? {}).map(
      (id, m) => MapEntry(
        id,
        (m as Map<String, dynamic>).map((i, l) => MapEntry(int.parse(i), SetLog.fromJson(l as Map<String, dynamic>))),
      ),
    ),
  );
}

/// Everything the app knows. Mutable on purpose: the store mutates it in place
/// and notifies, mirroring the prototype's logic one to one.
class BoltData {
  BoltData({
    required this.tpls,
    required this.coaches,
    required this.trainees,
    required this.plans,
    required this.visits,
    required this.gymIn,
    required this.settings,
    this.account,
    this.workout,
    this.nextId = 0,
    this.linkId,
    Map<String, CustomSplit>? splits,
  }) : splits = splits ?? {};

  /// Saved data format. Anything older (the v1.0 demo) is discarded.
  static const version = 2;

  /// Templates by id, in library order.
  final Map<String, WorkoutTemplate> tpls;
  final List<Coach> coaches;
  final List<Trainee> trainees;

  /// Sessions per trainee id, keyed by day key.
  final Map<String, Map<String, Session>> plans;

  /// Closed visits per user id, newest first.
  final Map<String, List<Visit>> visits;

  /// Open visits per user id.
  final Map<String, GymIn> gymIn;
  final AppSettings settings;
  Account? account;
  ActiveWorkout? workout;
  int nextId;

  /// For a trainee: their id on the coach's phone, from the last imported
  /// plan, so updates sent back land on the right person.
  String? linkId;

  /// Weekly splits the owner built, by id.
  final Map<String, CustomSplit> splits;

  String uid() => 'e${++nextId}';

  Map<String, dynamic> toJson() => {
    'version': version,
    'tpls': tpls.values.map((t) => t.toJson()).toList(),
    'coaches': coaches.map((c) => c.toJson()).toList(),
    'trainees': trainees.map((t) => t.toJson()).toList(),
    'plans': plans.map((tid, p) => MapEntry(tid, p.map((k, s) => MapEntry(k, s.toJson())))),
    'visits': visits.map((id, v) => MapEntry(id, v.map((x) => x.toJson()).toList())),
    'gymIn': gymIn.map((id, g) => MapEntry(id, g.toJson())),
    'settings': settings.toJson(),
    'account': account?.toJson(),
    'workout': workout?.toJson(),
    'nextId': nextId,
    'linkId': linkId,
    'splits': splits.values.map((x) => x.toJson()).toList(),
  };

  factory BoltData.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(Object? o) => o as Map<String, dynamic>;
    final tpls = <String, WorkoutTemplate>{};
    for (final t in j['tpls'] as List) {
      final x = WorkoutTemplate.fromJson(m(t));
      tpls[x.id] = x;
    }
    return BoltData(
      tpls: tpls,
      coaches: (j['coaches'] as List).map((c) => Coach.fromJson(m(c))).toList(),
      trainees: (j['trainees'] as List).map((t) => Trainee.fromJson(m(t))).toList(),
      plans: m(j['plans']).map((tid, p) => MapEntry(tid, m(p).map((k, s) => MapEntry(k, Session.fromJson(m(s)))))),
      visits: m(j['visits']).map((id, v) => MapEntry(id, (v as List).map((x) => Visit.fromJson(m(x))).toList())),
      gymIn: m(j['gymIn']).map((id, g) => MapEntry(id, GymIn.fromJson(m(g)))),
      settings: AppSettings.fromJson(m(j['settings'])),
      account: j['account'] == null ? null : Account.fromJson(m(j['account'])),
      workout: j['workout'] == null ? null : ActiveWorkout.fromJson(m(j['workout'])),
      nextId: j['nextId'] as int? ?? 0,
      linkId: j['linkId'] as String?,
      splits: {
        for (final x in j['splits'] as List? ?? const [])
          (x as Map<String, dynamic>)['id'] as String: CustomSplit.fromJson(x),
      },
    );
  }
}
