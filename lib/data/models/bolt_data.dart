import 'people.dart';
import 'session.dart';
import 'settings.dart';
import 'template.dart';
import 'visit.dart';

enum Role { trainee, coach }

class Account {
  const Account(this.role, this.id);

  final Role role;
  final String id;

  bool get isTrainee => role == Role.trainee;

  Map<String, dynamic> toJson() => {'role': role.name, 'id': id};

  factory Account.fromJson(Map<String, dynamic> j) =>
      Account(Role.values.byName(j['role'] as String), j['id'] as String);
}

/// The workout in progress: which sets are checked per exercise id.
class ActiveWorkout {
  ActiveWorkout({required this.key, Map<String, List<bool>>? done}) : done = done ?? {};

  final String key;
  final Map<String, List<bool>> done;

  bool isDone(String exId, int i) {
    final a = done[exId];
    return a != null && i < a.length && a[i];
  }

  Map<String, dynamic> toJson() => {'key': key, 'done': done};

  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
        key: j['key'] as String,
        done: (j['done'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as List).map((x) => x as bool).toList())),
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
  });

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

  String uid() => 'e${++nextId}';

  Map<String, dynamic> toJson() => {
        'version': 1,
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
    );
  }
}
