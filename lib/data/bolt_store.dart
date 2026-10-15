import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../services/notifications.dart';
import 'models/bolt_data.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'models/template.dart';
import 'models/visit.dart';
import 'repositories/bolt_repository.dart';
import 'rules.dart';
import 'seed/content.dart';
import 'seed/splits.dart';
import 'seed/templates.dart';
import 'share_codes.dart';

/// Current time. Overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final repositoryProvider = Provider<BoltRepository>((ref) => BoltRepository.memory());

final notificationsProvider = Provider<BoltNotifications>((ref) => const NoopNotifications());

/// Data loaded at startup: what is saved on the phone, or a fresh start.
final initialDataProvider = Provider<BoltData>((ref) => freshData());

final boltProvider = NotifierProvider<BoltStore, BoltData>(BoltStore.new);

class ToastMessage {
  ToastMessage(this.text) : id = _next++;

  static int _next = 0;
  final String text;

  /// Distinct per toast so the same text twice still animates.
  final int id;
}

final toastProvider = NotifierProvider<ToastController, ToastMessage?>(ToastController.new);

class ToastController extends Notifier<ToastMessage?> {
  @override
  ToastMessage? build() => null;

  void show(String text) => state = ToastMessage(text);

  void clear(int id) {
    if (state?.id == id) state = null;
  }
}

/// Result of scanning the plaque.
class ScanOutcome {
  const ScanOutcome({required this.head, required this.sub, this.unlocked = const []});

  final String head;
  final String sub;

  /// Badges unlocked by this check-out.
  final List<String> unlocked;
}

/// What the editor is editing: a template, or one trainee's day.
sealed class EditTarget {
  const EditTarget();
}

class TemplateTarget extends EditTarget {
  const TemplateTarget(this.id);

  final String id;
}

class DayTarget extends EditTarget {
  const DayTarget(this.tid, this.key);

  final String tid;
  final String key;
}

/// Profile fields from onboarding or "Edit profile". Null means unchanged.
class ProfileInput {
  const ProfileInput({required this.name, this.goal, this.split, this.coachName, this.specialty, this.gym, this.body});

  final String name;
  final String? goal;
  final String? split;
  final String? coachName;
  final String? specialty;
  final String? gym;
  final Body? body;
}

/// All business rules. State is mutated in place and listeners are notified,
/// then saved to the phone in the background.
class BoltStore extends Notifier<BoltData> {
  @override
  BoltData build() => ref.read(initialDataProvider);

  DateTime get now => ref.read(clockProvider)();
  String get today => dk(now);
  DateTime get mon0 => monday(now);

  BoltNotifications get _notify => ref.read(notificationsProvider);

  void _commit() {
    ref.notifyListeners();
    ref.read(repositoryProvider).scheduleSave(state);
  }

  void _toast(String t) => ref.read(toastProvider.notifier).show(t);

  bool get _isCoach => state.account?.isCoach ?? false;

  // Lookups

  Trainee tr(String id) => state.trainees.firstWhere((t) => t.id == id);
  Trainee? trOrNull(String id) {
    for (final t in state.trainees) {
      if (t.id == id) return t;
    }
    return null;
  }

  Coach co(String id) => state.coaches.firstWhere((c) => c.id == id, orElse: () => state.coaches.first);
  Coach? coOrNull(String id) {
    for (final c in state.coaches) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The trainee's coach by name: on this phone, or named in their profile.
  String? coachNameOf(Trainee t) {
    final n = t.coachName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return coOrNull(t.coach)?.name;
  }

  Map<String, Session> plan(String tid) => state.plans.putIfAbsent(tid, () => {});
  String unit(String load) => unitLoad(load, kg: state.settings.kg);
  String _dayLabel(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';
  String get _sinceLabel => '${monthsShort[now.month - 1]} ${now.year}';

  // Profile

  /// Onboarding: creates the phone owner's profile. Solo users can have their
  /// first three weeks planned from their split right away. An admin gets
  /// both a coach and a trainee record so every role works.
  void createProfile(Role role, ProfileInput p, {bool autoPlan = false, bool admin = false}) {
    final body = (p.body ?? Body())..updated = (p.body?.isEmpty ?? true) ? null : today;
    if (role == Role.coach || admin) {
      state.coaches
        ..clear()
        ..add(Coach(id: Account.ownerId, name: p.name.trim(), role: _or(p.specialty, 'Coach'), body: body));
    }
    if (role != Role.coach || admin) {
      state.trainees.removeWhere((t) => t.id == Account.ownerId);
      state.trainees.add(
        Trainee(
          id: Account.ownerId,
          name: p.name.trim(),
          coach: '',
          coachName: role == Role.trainee ? _orNull(p.coachName) : null,
          goal: p.goal ?? 'General fitness',
          split: p.split ?? 'ppl',
          since: _sinceLabel,
          injuries: [],
          stats: TraineeStats(),
          body: body,
        ),
      );
    }
    state.settings.gymName = p.gym?.trim() ?? '';
    state.account = Account(role, Account.ownerId, admin: admin);
    if (autoPlan && role != Role.coach) _fill(Account.ownerId, SessionStatus.approved);
    _commit();
    syncSessionReminders();
  }

  /// Admin only: shows the app as a coach, trainee or solo user.
  void switchRole(Role role) {
    final a = state.account;
    if (a == null || !a.admin || a.role == role) return;
    state.account = Account(role, a.id, admin: true);
    _commit();
    syncSessionReminders();
  }

  /// Saves "Edit profile" for the owner or, for a coach, one of their trainees.
  void saveProfile(String id, ProfileInput p) {
    final t = trOrNull(id);
    if (t != null) {
      t.name = p.name.trim().isEmpty ? t.name : p.name.trim();
      if (p.goal != null) t.goal = p.goal!;
      if (p.split != null) t.split = p.split!;
      if (p.coachName != null) t.coachName = _orNull(p.coachName);
      if (p.body != null) t.body = p.body!..updated = today;
    }
    final c = coOrNull(id);
    if (c != null) {
      c.name = p.name.trim().isEmpty ? c.name : p.name.trim();
      if (p.specialty != null) c.role = _or(p.specialty, 'Coach');
      if (p.body != null) c.body = p.body!..updated = today;
    }
    if (p.gym != null && id == Account.ownerId) state.settings.gymName = p.gym!.trim();
    _commit();
    _toast('Profile saved');
  }

  /// Erases everything on this phone and returns to onboarding.
  void resetAll() {
    _notify.cancelCheckout();
    _notify.replaceSessionReminders(const []);
    state = freshData();
    ref.read(repositoryProvider).scheduleSave(state);
  }

  String _or(String? v, String fallback) => (v == null || v.trim().isEmpty) ? fallback : v.trim();
  String? _orNull(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  // Coach: trainees

  /// A coach adds someone they coach. Returns the new trainee's id.
  String addTrainee(ProfileInput p) {
    final id = 't${state.uid().substring(1)}';
    state.trainees.add(
      Trainee(
        id: id,
        name: p.name.trim(),
        coach: Account.ownerId,
        goal: p.goal ?? 'General fitness',
        split: p.split ?? 'ppl',
        since: _sinceLabel,
        injuries: [],
        stats: TraineeStats(),
        body: (p.body ?? Body())..updated = (p.body?.isEmpty ?? true) ? null : today,
      ),
    );
    state.plans[id] = {};
    _commit();
    _toast('${firstName(p.name)} added');
    return id;
  }

  void removeTrainee(String tid) {
    final name = trOrNull(tid)?.name ?? '';
    state.trainees.removeWhere((t) => t.id == tid);
    state.plans.remove(tid);
    state.visits.remove(tid);
    state.gymIn.remove(tid);
    _commit();
    _toast('${firstName(name)} removed');
  }

  // Gym

  /// Scanning the plaque toggles: check in if out, otherwise check out.
  ScanOutcome scan() {
    final id = state.account!.id;
    final g = state.gymIn[id];
    final n = now;
    if (g == null) {
      final since = hm(n);
      state.gymIn[id] = GymIn(at: n.millisecondsSinceEpoch, base: 0, since: since);
      if (state.settings.checkout) {
        _notify.scheduleCheckout(
          Reminder(
            at: n.add(const Duration(hours: 3)),
            title: 'Still at the gym?',
            body: 'Checked in at $since. Scan the plaque on your way out.',
          ),
        );
      }
      _commit();
      return ScanOutcome(head: 'Checked in', sub: '$since · have a good session');
    }
    final mins = math.max(1, g.elapsedMinutes(n).round());
    final res = _closeVisit(id, g, mins, auto: false);
    _commit();
    return ScanOutcome(
      head: 'Checked out',
      sub: '${dur(mins)} in the gym · ${g.since} → ${res.$1.outT}',
      unlocked: res.$2,
    );
  }

  (Visit, List<String>) _closeVisit(String id, GymIn g, int mins, {required bool auto}) {
    state.gymIn.remove(id);
    _notify.cancelCheckout();
    final v = Visit(
      date: dk(g.checkInTime()),
      inT: g.since,
      outT: fromMin(toMin(g.since) + mins),
      mins: mins,
      auto: auto,
    );
    state.visits.putIfAbsent(id, () => []).insert(0, v);
    final t = trOrNull(id);
    if (t == null) return (v, const []);
    final before = t.stats.copy();
    t.stats.sessions++;
    t.stats.mins += mins;
    if (toMin(g.since) < 420) t.stats.early++;
    if (toMin(g.since) >= 1260) t.stats.late++;
    return (v, newlyUnlocked(before, t.stats));
  }

  /// Visits still open after 5 hours are closed at 5 hours and flagged auto.
  void autoCloseStale() {
    final n = now;
    final stale = state.gymIn.entries.where((e) => e.value.elapsedMinutes(n) >= 300).toList();
    if (stale.isEmpty) return;
    for (final e in stale) {
      _closeVisit(e.key, e.value, 300, auto: true);
    }
    _commit();
  }

  // Trainee plan

  void accept(String k) {
    final p = plan(state.account!.id)[k];
    if (p != null) p.status = SessionStatus.approved;
    _commit();
    _toast('${fmtDay(k)} confirmed');
    syncSessionReminders();
  }

  void acceptAll() {
    var n = 0;
    for (final p in plan(state.account!.id).values) {
      if (p.status == SessionStatus.pending) {
        p.status = SessionStatus.approved;
        n++;
      }
    }
    _commit();
    _toast('${plural(n, 'session')} confirmed');
    syncSessionReminders();
  }

  /// Moves a session onto an empty day that is today or later.
  bool move(String from, String to) {
    final p = plan(state.account!.id);
    if (p[to] != null || to.compareTo(today) < 0) return false;
    final o = p.remove(from);
    if (o == null) return false;
    // A coach's session is marked moved so the coach sees it in the next
    // update; the trainee's own sessions just move.
    p[to] = o
      ..status = o.byCoach ? SessionStatus.moved : o.status
      ..from = o.byCoach ? (o.from ?? from) : null;
    _commit();
    _toast('Moved to ${fmtDay(to)}');
    syncSessionReminders();
    return true;
  }

  // Workout

  void startWorkout(String k) {
    if (state.workout?.key != k) state.workout = ActiveWorkout(key: k);
    _commit();
  }

  /// Returns true when the set became done (the rest timer starts).
  bool toggleSet(String exId, int i) {
    final w = state.workout;
    if (w == null) return false;
    final a = w.done.putIfAbsent(exId, () => []);
    while (a.length <= i) {
      a.add(false);
    }
    a[i] = !a[i];
    _commit();
    return a[i];
  }

  void swap(Exercise e) {
    swapExercise(e);
    _commit();
    _toast('Swapped to ${e.name}');
  }

  /// Logs the workout and returns badges it unlocked.
  List<String> finish() {
    final w = state.workout;
    if (w == null) return const [];
    final t = tr(state.account!.id);
    final p = plan(t.id)[w.key];
    state.workout = null;
    if (p == null) {
      _commit();
      return const [];
    }
    var dn = 0;
    for (final e in p.ex) {
      for (var i = 0; i < e.sets; i++) {
        if (w.isDone(e.id, i)) dn++;
      }
    }
    p.status = SessionStatus.done;
    p.log = '$dn/${p.totalSets} sets';
    final before = t.stats.copy();
    t.stats
      ..workouts += 1
      ..sets += dn;
    _checkPerfectWeek(t);
    final unlocked = newlyUnlocked(before, t.stats);
    _commit();
    _toast('Workout logged · ${p.log}');
    syncSessionReminders();
    return unlocked;
  }

  /// Every planned session this week done: a perfect week, which also
  /// extends the streak.
  void _checkPerfectWeek(Trainee t) {
    final p = plan(t.id);
    final week = [for (var i = 0; i < 7; i++) p[dk(addDays(mon0, i))]]
        .whereType<Session>()
        .where((s) => s.status != SessionStatus.draft)
        .toList();
    final wk = dk(mon0);
    if (week.isEmpty || week.any((s) => s.status != SessionStatus.done) || t.stats.lastPerfectWeek == wk) {
      return;
    }
    final prev = dk(addDays(mon0, -7));
    t.stats
      ..perfect += 1
      ..streak = t.stats.lastPerfectWeek == prev ? t.stats.streak + 1 : 1
      ..lastPerfectWeek = wk;
  }

  // Planning, for a coach's trainees and for the owner's own plan. A coach
  // plans drafts that are sent for approval; people planning for themselves
  // get confirmed sessions straight away.

  SessionStatus get _newStatus => _isCoach ? SessionStatus.draft : SessionStatus.approved;

  /// Tapping an empty future day adds the next workout in the rotation.
  bool addFromRotation(String tid, String k) {
    final t = tr(tid);
    final p = plan(tid);
    if (p[k] != null || k.compareTo(today) < 0) return false;
    p[k] = sessionFromTemplate(state, nextInRotation(p, t.split, k), _newStatus);
    _commit();
    if (!_isCoach) syncSessionReminders();
    return true;
  }

  void setTemplate(String tid, String k, String tplId) {
    final p = plan(tid);
    final o = p[k];
    if (o == null || o.status == SessionStatus.done) return;
    p[k] = sessionFromTemplate(state, tplId, _isCoach ? SessionStatus.draft : o.status)
      ..note = o.note
      ..from = o.from
      ..byCoach = o.byCoach;
    _commit();
  }

  void removeDay(String tid, String k) {
    final was = plan(tid).remove(k)?.status;
    _commit();
    _toast(was == SessionStatus.draft ? 'Draft removed' : 'Removed');
    if (!_isCoach) syncSessionReminders();
  }

  /// Next 3 weeks from this Monday: each split day on its weekday when that
  /// date is today or later and empty.
  void autoFill(String tid) {
    final split = kSplits[tr(tid).split]!;
    final n = _fill(tid, _newStatus);
    _commit();
    _toast(
      n == 0
          ? 'The next 3 weeks are already planned'
          : '${plural(n, 'session')} ${_isCoach ? 'drafted' : 'planned'} from ${split.name}',
    );
    if (!_isCoach) syncSessionReminders();
  }

  int _fill(String tid, SessionStatus status) {
    final p = plan(tid);
    var n = 0;
    for (var w = 0; w < 3; w++) {
      for (final d in kSplits[tr(tid).split]!.days) {
        final k = dk(addDays(mon0, 7 * w + d.weekday - 1));
        if (k.compareTo(today) >= 0 && p[k] == null) {
          p[k] = sessionFromTemplate(state, d.tpl, status);
          n++;
        }
      }
    }
    return n;
  }

  void cycleSplit(String tid) {
    final t = tr(tid);
    t.split = kSplitOrder[(kSplitOrder.indexOf(t.split) + 1) % kSplitOrder.length];
    _commit();
  }

  /// Coach OKs a moved session.
  void ack(String tid, String k) {
    final p = plan(tid)[k];
    if (p == null) return;
    p
      ..status = SessionStatus.approved
      ..from = null;
    _commit();
    _toast('Change accepted');
  }

  void markInjuriesSeen(String tid) {
    for (final i in tr(tid).injuries) {
      i.fresh = false;
    }
    _commit();
  }

  void resolveInjury(String tid, int index) {
    tr(tid).injuries.removeAt(index);
    _commit();
    _toast('Flag resolved');
  }

  void reportInjury(String tid, String area, String note) {
    final t = tr(tid);
    final role = state.account!.role;
    final by = role == Role.coach
        ? 'Added by ${firstName(co(state.account!.id).name)}'
        : 'Reported by ${firstName(t.name)}';
    t.injuries.add(
      Injury(
        area: area,
        note: note.trim().isEmpty ? '${kAreas[area]} pain reported' : note.trim(),
        by: '$by · ${_dayLabel(now)}',
        fresh: role == Role.trainee,
      ),
    );
    _commit();
    final coach = coachNameOf(t);
    _toast(
      role == Role.trainee && coach != null
          ? 'Saved · send ${firstName(coach)} an update so they see it'
          : 'Flag added · matching exercises show swaps',
    );
  }

  // Editor

  /// The template or session being edited.
  Object? editObject(EditTarget target) => switch (target) {
    TemplateTarget(:final id) => state.tpls[id],
    DayTarget(:final tid, :final key) => state.plans[tid]?[key],
  };

  List<Exercise> editExercises(EditTarget target) => switch (editObject(target)) {
    WorkoutTemplate t => t.ex,
    Session s => s.ex,
    _ => const [],
  };

  /// A coach's edit to a planned day that is not done turns it back into a
  /// draft that has to be re-sent. People editing their own plan just save.
  void edit(EditTarget target, void Function() fn) {
    fn();
    final o = editObject(target);
    if (_isCoach && o is Session && o.status != SessionStatus.done) o.status = SessionStatus.draft;
    _commit();
  }

  void renameTemplate(String id, String name) {
    final t = state.tpls[id];
    if (t == null) return;
    t.name = name;
    if (t.custom) {
      final letters = name.replaceAll(RegExp('[^A-Za-z]'), '');
      t.code = (letters.isEmpty ? 'CUST' : letters.substring(0, math.min(4, letters.length))).toUpperCase();
    }
    _commit();
  }

  void addExercise(EditTarget target, ExSeed a) {
    edit(target, () => editExercises(target).add(exerciseFromSeed(a, state.uid())));
    _toast('${a.name} added');
  }

  /// Saves the editor. For a coach editing a trainee's day this also sends it:
  /// the returned message is shared with the trainee.
  String? saveEdit(EditTarget target) {
    switch (target) {
      case DayTarget(:final tid, :final key):
        if (_isCoach) {
          state.plans[tid]?[key]?.status = SessionStatus.pending;
          _commit();
          return planMessage(tid);
        }
        _commit();
        _toast('Session saved');
        return null;
      case TemplateTarget():
        _commit();
        _toast('Template saved · used by future auto-fills');
        return null;
    }
  }

  String newTemplate() {
    final n = state.tpls.keys.where((k) => k.startsWith('cu')).length + 1;
    final id = 'cu$n';
    state.tpls[id] = WorkoutTemplate(
      id: id,
      name: 'Custom $n',
      code: 'CUST',
      focus: 'Custom session',
      mins: 45,
      ex: [],
      custom: true,
    );
    _commit();
    return id;
  }

  // Sharing between phones

  /// Coach sends drafts: they become "waiting" and the returned message (with
  /// the whole upcoming plan) goes to the trainee.
  String? sendDrafts(String tid) {
    var n = 0;
    for (final s in plan(tid).values) {
      if (s.status == SessionStatus.draft) {
        s.status = SessionStatus.pending;
        n++;
      }
    }
    _commit();
    return n == 0 ? null : planMessage(tid);
  }

  /// The coach's upcoming plan for [tid] as a message to share.
  String planMessage(String tid) {
    final t = tr(tid);
    final coach = co(state.account!.id);
    final keys = plan(
      tid,
    ).keys.where((k) => k.compareTo(today) >= 0 && plan(tid)[k]!.status != SessionStatus.draft).toList()..sort();
    final code = ShareCode.encode({
      'type': 'plan',
      'tid': tid,
      'name': t.name,
      'coach': coach.name,
      'injuries': t.injuries.map((i) => i.toJson()).toList(),
      'sessions': {for (final k in keys) k: plan(tid)[k]!.toJson()},
    });
    final range = keys.isEmpty ? '' : ', ${fmtDay(keys.first)} to ${fmtDay(keys.last)}';
    return '${firstName(t.name)}, here is your Bolt plan from ${firstName(coach.name)}: '
        '${plural(keys.length, 'session')}$range.\n'
        'In Bolt open Me, then Import plan. It reads this message from your clipboard.\n\n$code';
  }

  /// The trainee's progress as a message for their coach.
  String updateMessage() {
    final t = tr(Account.ownerId);
    final p = plan(t.id);
    final from = dk(addDays(now, -28));
    final keys = p.keys
        .where(
          (k) =>
              k.compareTo(from) >= 0 &&
              p[k]!.byCoach &&
              {SessionStatus.approved, SessionStatus.moved, SessionStatus.done}.contains(p[k]!.status),
        )
        .toList();
    final cutoff = dk(addDays(now, -42));
    final code = ShareCode.encode({
      'type': 'update',
      'tid': state.linkId,
      'name': t.name,
      'sessions': {
        for (final k in keys) k: {'status': p[k]!.status.name, 'from': p[k]!.from, 'log': p[k]!.log},
      },
      'visits': [
        for (final v in state.visits[t.id] ?? const <Visit>[])
          if (v.date.compareTo(cutoff) >= 0) v.toJson(),
      ],
      'injuries': t.injuries.map((i) => i.toJson()).toList(),
      'stats': t.stats.toJson(),
      'body': t.body.toJson(),
    });
    final done = keys.where((k) => p[k]!.status == SessionStatus.done).length;
    final coach = coachNameOf(t);
    return 'Bolt update from ${firstName(t.name)}${coach == null ? '' : ' for ${firstName(coach)}'}: '
        '${plural(done, 'workout')} done, ${plural(keys.length - done, 'session')} confirmed or moved.\n'
        'In Bolt open Trainees, then Import update. It reads this message from your clipboard.\n\n$code';
  }

  /// Imports a plan (trainee) or an update (coach) from pasted text. Returns
  /// an error to show, or null when it worked.
  String? importText(String text) {
    final packet = ShareCode.decode(text);
    if (packet == null) {
      return ShareCode.contains(text)
          ? 'That code looks damaged. Copy the whole message again.'
          : 'No Bolt code found in the copied text.';
    }
    final type = packet['type'];
    if (type == 'plan') {
      if (_isCoach) return 'This is a plan for a trainee. Open it on their phone.';
      _importPlan(packet);
      return null;
    }
    if (type == 'update') {
      if (!_isCoach) return 'This is an update for a coach. Open it on their phone.';
      return _importUpdate(packet);
    }
    return 'This code is from a newer Bolt. Update the app and try again.';
  }

  void _importPlan(Map<String, dynamic> packet) {
    final me = tr(Account.ownerId);
    final p = plan(me.id);
    final sessions = (packet['sessions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Session.fromJson(v as Map<String, dynamic>)),
    );
    // Days this trainee moved stay where they put them while the coach's plan
    // still lists the original day.
    final movedFrom = {
      for (final s in p.values)
        if (s.from != null && sessions.containsKey(s.from)) s.from!,
    };
    // Other coach sessions missing from the plan were removed by the coach.
    p.removeWhere(
      (k, s) =>
          s.byCoach &&
          k.compareTo(today) >= 0 &&
          s.status != SessionStatus.done &&
          !sessions.containsKey(k) &&
          !movedFrom.contains(s.from),
    );
    var n = 0;
    sessions.forEach((k, s) {
      final existing = p[k];
      if (existing?.status == SessionStatus.done || movedFrom.contains(k)) return;
      p[k] = Session(
        tpl: s.tpl,
        title: s.title,
        focus: s.focus,
        mins: s.mins,
        ex: [for (final e in s.ex) e.copyWith(id: state.uid())],
        status: s.status == SessionStatus.draft ? SessionStatus.pending : s.status,
        note: s.note,
        from: s.from,
        byCoach: true,
      );
      n++;
    });
    final coachName = packet['coach'] as String?;
    if (coachName != null && coachName.trim().isNotEmpty) me.coachName = coachName.trim();
    state.linkId = packet['tid'] as String?;
    // Coach flags replace earlier coach flags; the trainee's own reports stay.
    final coachFlags = [
      for (final j in packet['injuries'] as List? ?? const []) Injury.fromJson(j as Map<String, dynamic>),
    ];
    me.injuries = [
      ...coachFlags,
      for (final i in me.injuries)
        if (i.by.startsWith('Reported') && !coachFlags.any((c) => c.area == i.area && c.note == i.note)) i,
    ];
    _commit();
    syncSessionReminders();
    final pending = sessions.values.where((s) => s.status == SessionStatus.pending).length;
    _toast(
      '${plural(n, 'session')} from ${firstName(coachName ?? 'your coach')}'
      '${pending > 0 ? ' · $pending waiting for your OK' : ''}',
    );
  }

  String? _importUpdate(Map<String, dynamic> packet) {
    final tid = packet['tid'] as String?;
    final t = tid == null ? null : trOrNull(tid);
    if (t == null) {
      return 'This update is from someone who is not in your trainees. Send them a plan first.';
    }
    final p = plan(t.id);
    var moved = 0, done = 0, ok = 0;
    (packet['sessions'] as Map<String, dynamic>).forEach((k, v) {
      final j = v as Map<String, dynamic>;
      final status = SessionStatus.values.byName(j['status'] as String);
      final from = j['from'] as String?;
      var s = p[k];
      if (s == null && from != null && p[from] != null) {
        s = p.remove(from)!;
        p[k] = s;
      }
      if (s == null) return;
      switch (status) {
        case SessionStatus.done:
          if (s.status != SessionStatus.done) done++;
          s
            ..status = SessionStatus.done
            ..log = j['log'] as String?;
        case SessionStatus.moved:
          // Already OK'd by the coach: keep it confirmed.
          if (s.status == SessionStatus.approved && s.from == null) return;
          if (s.status != SessionStatus.moved) moved++;
          s
            ..status = SessionStatus.moved
            ..from = from;
        case SessionStatus.approved:
          if (s.status == SessionStatus.pending) {
            s.status = SessionStatus.approved;
            ok++;
          }
        default:
          break;
      }
    });
    state.visits[t.id] = [
      for (final v in packet['visits'] as List? ?? const []) Visit.fromJson(v as Map<String, dynamic>),
    ]..sort((a, b) => b.date.compareTo(a.date));
    for (final j in packet['injuries'] as List? ?? const []) {
      final i = Injury.fromJson(j as Map<String, dynamic>);
      if (!t.injuries.any((x) => x.area == i.area && x.note == i.note)) {
        t.injuries.add(i..fresh = i.by.startsWith('Reported'));
      }
    }
    if (packet['stats'] case final Map<String, dynamic> stats) t.stats = TraineeStats.fromJson(stats);
    final body = Body.fromJson(packet['body'] as Map<String, dynamic>?);
    if (!body.isEmpty) t.body = body;
    _commit();
    _toast('Update from ${firstName(t.name)} · $ok confirmed, $moved moved, $done done');
    return null;
  }

  // Settings

  void toggleSetting(String key) {
    final s = state.settings;
    switch (key) {
      case 'remind':
        s.remind = !s.remind;
      case 'checkout':
        s.checkout = !s.checkout;
        if (!s.checkout) _notify.cancelCheckout();
    }
    _commit();
    if (key == 'remind') syncSessionReminders();
  }

  void toggleUnits() {
    state.settings.kg = !state.settings.kg;
    _commit();
  }

  void toggleWeekStart() {
    state.settings.mondayFirst = !state.settings.mondayFirst;
    _commit();
  }

  void cycleRest() {
    const steps = [60, 90, 120, 150, 180];
    final i = steps.indexOf(state.settings.restSecs);
    state.settings.restSecs = steps[(i + 1) % steps.length];
    _commit();
  }

  void toast(String text) => _toast(text);

  /// Reminders 2 hours before each confirmed session in the coming week, at
  /// the trainee's usual check-in time.
  void syncSessionReminders() {
    final a = state.account;
    if (a == null || !a.isTrainee || !state.settings.remind) {
      _notify.replaceSessionReminders(const []);
      return;
    }
    final usual = _usualCheckIn(a.id);
    final p = plan(a.id);
    final list = <Reminder>[];
    for (var i = 0; i < 8; i++) {
      final d = addDays(now, i);
      final s = p[dk(d)];
      if (s == null || (s.status != SessionStatus.approved && s.status != SessionStatus.moved)) continue;
      final at = DateTime(d.year, d.month, d.day).add(Duration(minutes: usual - 120));
      list.add(
        Reminder(
          at: at,
          title: '${s.title} today',
          body: '${s.focus} · ~${s.mins} min. Scan the plaque when you arrive.',
        ),
      );
    }
    _notify.replaceSessionReminders(list);
  }

  /// Median check-in time of recent visits, in minutes after midnight.
  int _usualCheckIn(String id) {
    final v = (state.visits[id] ?? const <Visit>[]).take(10).map((x) => toMin(x.inT)).toList()..sort();
    return v.isEmpty ? 18 * 60 : v[v.length ~/ 2];
  }
}
