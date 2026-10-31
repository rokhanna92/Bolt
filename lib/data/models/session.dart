import 'exercise.dart';

/// draft --send--> pending --accept--> approved --finish--> done
/// pending/approved --trainee moves--> moved --coach OK--> approved
enum SessionStatus { draft, pending, approved, moved, done }

/// High fives a coach can give a done workout.
const kCheers = ['🔥', '💪', '👏', '⚡'];

/// A planned day for one trainee. Exercises are copied from the template when
/// the session is created, so later template edits never change planned days.
class Session {
  Session({
    required this.tpl,
    required this.title,
    required this.focus,
    required this.mins,
    required this.ex,
    required this.status,
    this.note = '',
    this.from,
    this.log,
    this.byCoach = false,
    this.code,
    this.deload = false,
    this.took,
    this.cheer,
    List<String>? prs,
  }) : prs = prs ?? [];

  String tpl;
  String title;
  String focus;
  int mins;
  List<Exercise> ex;
  SessionStatus status;
  String note;

  /// Original day key when the trainee moved it.
  String? from;

  /// `x/y sets` once done.
  String? log;

  /// Came in a plan from the coach (as opposed to planned by the trainee).
  bool byCoach;

  /// Calendar code for a day built from muscles, which has no template.
  String? code;

  /// Part of a deload week: sets halved.
  bool deload;

  /// Minutes from starting the workout in Bolt to finishing it.
  int? took;

  /// Lifts with a personal record in this workout.
  final List<String> prs;

  /// The coach's high five on a done workout, an emoji.
  String? cheer;

  int get totalSets => ex.fold(0, (a, e) => a + e.sets);

  /// Logged with every planned set, from the log's "done/total sets" start.
  bool get whole {
    final m = RegExp(r'^(\d+)/(\d+) sets').firstMatch(log ?? '');
    return m != null && m[1] == m[2];
  }

  Map<String, dynamic> toJson() => {
    'tpl': tpl,
    'title': title,
    'focus': focus,
    'mins': mins,
    'ex': ex.map((e) => e.toJson()).toList(),
    'status': status.name,
    'note': note,
    'from': from,
    'log': log,
    'byCoach': byCoach,
    'code': code,
    'deload': deload,
    'took': took,
    if (prs.isNotEmpty) 'prs': prs,
    if (cheer != null) 'cheer': cheer,
  };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
    tpl: j['tpl'] as String,
    title: j['title'] as String,
    focus: j['focus'] as String,
    mins: j['mins'] as int,
    ex: (j['ex'] as List).map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList(),
    status: SessionStatus.values.byName(j['status'] as String),
    note: j['note'] as String? ?? '',
    from: j['from'] as String?,
    log: j['log'] as String?,
    byCoach: j['byCoach'] as bool? ?? false,
    code: j['code'] as String?,
    deload: j['deload'] as bool? ?? false,
    took: j['took'] as int?,
    cheer: j['cheer'] as String?,
    prs: [for (final x in j['prs'] as List? ?? const []) x as String],
  );
}
