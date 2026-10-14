import 'exercise.dart';

/// draft --send--> pending --accept--> approved --finish--> done
/// pending/approved --trainee moves--> moved --coach OK--> approved
enum SessionStatus { draft, pending, approved, moved, done }

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
  });

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

  int get totalSets => ex.fold(0, (a, e) => a + e.sets);

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
      );
}
