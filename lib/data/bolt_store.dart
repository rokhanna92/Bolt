import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/units.dart';
import '../services/notifications.dart';
import 'models/bolt_data.dart';
import 'models/custom_split.dart';
import 'models/exercise.dart';
import 'models/people.dart';
import 'models/session.dart';
import 'models/template.dart';
import 'models/visit.dart';
import 'level.dart';
import 'lifts.dart';
import 'programs.dart';
import 'repositories/bolt_repository.dart';
import 'rules.dart';
import 'seed/content.dart';
import 'seed/exercises.dart';
import 'seed/muscles.dart';
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
  const ScanOutcome({
    required this.head,
    required this.sub,
    this.checkIn = false,
    this.hype,
    this.detail,
    this.unlocked = const [],
  });

  /// The scan checked in (rather than out).
  final bool checkIn;

  final String head;
  final String sub;

  /// A line to fire you up or celebrate.
  final String? hype;

  /// What happened to today's workout.
  final String? detail;

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

/// Whether the phone owner set Female, for Serbian female word forms.
bool _ownerFemale(BoltData d) {
  final me = Account.ownerId;
  final body = (d.account?.isCoach ?? false)
      ? d.coaches.where((c) => c.id == me).firstOrNull?.body
      : d.trainees.where((t) => t.id == me).firstOrNull?.body;
  return body?.sex == 'f';
}

/// All business rules. State is mutated in place and listeners are notified,
/// then saved to the phone in the background.
class BoltStore extends Notifier<BoltData> {
  @override
  BoltData build() {
    final d = ref.read(initialDataProvider);
    appLang = AppLang.byName(d.settings.lang);
    appFemale = _ownerFemale(d);
    return d;
  }

  /// Switches the app language; every screen is rebuilt in it.
  void setLanguage(AppLang l) {
    state.settings.lang = l.name;
    appLang = l;
    _commit();
  }

  DateTime get now => ref.read(clockProvider)();
  String get today => dk(now);
  DateTime get mon0 => monday(now);

  BoltNotifications get _notify => ref.read(notificationsProvider);

  void _commit() {
    appFemale = _ownerFemale(state);
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

  /// Loads and body shown in kg and cm (else lb and in).
  bool get metric => state.settings.kg;

  /// Stored in English (injury flags), translated where shown.
  String _dayLabel(DateTime d) =>
      '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
  String get _sinceLabel => '${monthsShort[now.month - 1]} ${now.year}';

  // Profile

  /// Onboarding: creates the phone owner's profile. Solo users can have their
  /// first three weeks planned from their split right away. An admin gets
  /// both a coach and a trainee record so every role works.
  void createProfile(Role role, ProfileInput p, {bool autoPlan = false, bool admin = false}) {
    final body = (p.body ?? Body())..updated = (p.body?.isEmpty ?? true) ? null : today;
    if (!body.isEmpty) body.logCurrent(today);
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
          // An admin's coach record has the same values in its own object.
          body: admin ? (body.clone()..logCurrent(today)) : body,
        ),
      );
    }
    state.settings.gymName = p.gym?.trim() ?? '';
    state.account = Account(role, Account.ownerId, admin: admin);
    state.settings.levelSeen = 1;
    if (autoPlan && role != Role.coach) _fill(Account.ownerId, SessionStatus.approved);
    _commit();
    syncSessionReminders();
  }

  /// Roles the owner can switch between: an admin all three, a coach between
  /// coaching and training solo. Empty for everyone else.
  List<Role> get switchRoles {
    final a = state.account;
    if (a == null) return const [];
    if (a.admin) return const [Role.coach, Role.trainee, Role.solo];
    return coOrNull(Account.ownerId) != null ? const [Role.coach, Role.solo] : const [];
  }

  /// Changes which screens the owner sees. A coach training solo for the
  /// first time gets their own trainee record, named after their profile.
  void switchRole(Role role) {
    final a = state.account;
    if (a == null || a.role == role || !switchRoles.contains(role)) return;
    final c = coOrNull(Account.ownerId);
    if (role != Role.coach && c != null && trOrNull(Account.ownerId) == null) {
      state.trainees.add(
        Trainee(
          id: Account.ownerId,
          name: c.name,
          coach: '',
          goal: 'General fitness',
          split: 'ppl',
          since: _sinceLabel,
          injuries: [],
          stats: TraineeStats(),
          body: c.body,
        ),
      );
    }
    state.account = Account(role, a.id, admin: a.admin);
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
      if (p.body != null) t.body = _nextBody(t.body, p.body!.clone());
    }
    final c = coOrNull(id);
    if (c != null) {
      c.name = p.name.trim().isEmpty ? c.name : p.name.trim();
      if (p.specialty != null) c.role = _or(p.specialty, 'Coach');
      if (p.body != null) c.body = _nextBody(c.body, p.body!.clone());
    }
    if (p.gym != null && id == Account.ownerId) state.settings.gymName = p.gym!.trim();
    _commit();
    _toast(tx('Profile saved'));
  }

  /// [fresh] values from a form, keeping [old]'s history and logging today.
  Body _nextBody(Body old, Body fresh) {
    fresh.history.addAll(old.history);
    fresh.goals.addAll(old.goals);
    return fresh
      ..updated = today
      ..logCurrent(today);
  }

  /// The body on show: a trainee's when [tid] is given, otherwise the
  /// owner's, the coach record on coach screens.
  Body? bodyFor(String? tid) {
    if (tid != null) return trOrNull(tid)?.body;
    final me = Account.ownerId;
    return (state.account?.isCoach ?? false) ? coOrNull(me)?.body : trOrNull(me)?.body;
  }

  /// Today's weigh-in or measurements: only the values given change.
  void logBody(String? tid, double? weightKg, Map<String, double> cm) {
    final b = bodyFor(tid);
    if (b == null || (weightKg == null && cm.isEmpty)) return;
    var e = b.history.where((x) => x.date == today).firstOrNull;
    if (e == null) {
      e = BodyEntry(date: today);
      b.history
        ..add(e)
        ..sort((a, c) => a.date.compareTo(c.date));
    }
    if (weightKg != null) b.weightKg = e.weightKg = weightKg;
    cm.forEach((k, v) => b.cm[k] = e!.cm[k] = v);
    b.updated = today;
    _commit();
    _toast(tx('Logged for today'));
  }

  void deleteBodyEntry(String? tid, String date) {
    final b = bodyFor(tid);
    if (b == null) return;
    b.history.removeWhere((e) => e.date == date);
    b.recomputeLatest();
    _commit();
    _toast(tx('{day} removed', {'day': fmtDay(date)}));
  }

  /// Erases everything on this phone and returns to onboarding.
  void resetAll() {
    _notify.cancelCheckout();
    _notify.clearInGym();
    _notify.replaceSessionReminders(const []);
    final lang = state.settings.lang;
    state = freshData()..settings.lang = lang;
    appFemale = false;
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
        body: (p.body ?? Body())
          ..updated = (p.body?.isEmpty ?? true) ? null : today
          ..logCurrent(today),
      ),
    );
    state.plans[id] = {};
    _commit();
    _toast(tx('{name} added', {'name': firstName(p.name)}));
    return id;
  }

  void removeTrainee(String tid) {
    final name = trOrNull(tid)?.name ?? '';
    final female = trOrNull(tid)?.body.sex == 'f';
    state.trainees.removeWhere((t) => t.id == tid);
    state.plans.remove(tid);
    state.visits.remove(tid);
    state.gymIn.remove(tid);
    _commit();
    _toast(txFor(female, '{name} removed', {'name': firstName(name)}));
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
      _notify.showInGym(n, since);
      if (state.settings.checkout) {
        _notify.scheduleCheckout(
          Reminder(
            at: n.add(const Duration(hours: 3)),
            title: tx('Still at the gym?'),
            body: tx('Checked in at {time}. Scan the plaque on your way out.', {'time': since}),
          ),
        );
      }
      _commit();
      syncSessionReminders();
      final s = plan(id)[dk(n)];
      final planned = s != null && s.status != SessionStatus.draft && s.status != SessionStatus.done;
      return ScanOutcome(
        head: tx('Checked in'),
        checkIn: true,
        sub: planned
            ? tx('{time} · today: {workout}', {'time': since, 'workout': tx(s.title)})
            : tx('{time} · have a good session', {'time': since}),
        hype: _pick(_inHype),
      );
    }
    final mins = math.max(1, g.elapsedMinutes(n).round());
    final t = trOrNull(id);
    final before = t?.stats.copy();
    final res = _closeVisit(id, g, mins, auto: false);
    final day = t == null ? null : _finishDay(t, res.$1.date, mins);
    _commit();
    syncSessionReminders();
    return ScanOutcome(
      head: day == null ? tx('Checked out') : tx('Day done'),
      sub: tx('{time} in the gym · {from} → {to}', {'time': dur(mins), 'from': g.since, 'to': res.$1.outT}),
      hype: day == null ? null : _pick(_outHype),
      detail:
          day ??
          (mins < minGymMins ? tx('Under {n} minutes, so it only counts as gym time.', {'n': minGymMins}) : null),
      unlocked: before == null ? res.$2 : newlyUnlocked(before, t!.stats),
    );
  }

  /// Visits shorter than this count as gym time but do not finish the day,
  /// so a mistaken scan never logs a workout.
  static const minGymMins = 10;

  static const _inHype = ['Let\'s get it.', 'Make it count.', 'Yeah buddy!', 'Time to work.', 'Iron is waiting.'];

  static const _outHype = [
    'Beast mode: complete.',
    'The iron never lies.',
    'Light weight, baby!',
    'Stronger than yesterday.',
    'That is how legends are built.',
    'Arnold would be proud.',
    'Pump secured. Now go eat.',
    'You showed up. That is the whole secret.',
    'Done. Now grow.',
    'Another day in the bank.',
    'Sweat today, statue tomorrow.',
    'Discipline beats motivation. You proved it.',
    'Nobody remembers easy days. Today counts.',
    'Iron sharpened.',
  ];

  String _pick(List<String> lines) => tx(lines[math.Random().nextInt(lines.length)]);

  /// Scanning out finishes day [k]: a workout in progress is finished with
  /// the sets checked, a planned one counts as done with every set, and a
  /// day with nothing planned becomes a gym session to fill in later. The
  /// gym time goes into the log. Returns what happened, or null when the
  /// day is left as it was.
  String? _finishDay(Trainee t, String k, int mins) {
    if (mins < minGymMins) return null;
    final p = plan(t.id);
    final s = p[k];
    final w = state.workout;
    if (s == null) {
      final g = Session(
        tpl: mixTpl,
        title: gymSessionTitle,
        focus: tx('Add what you trained'),
        mins: mins,
        ex: [],
        status: SessionStatus.done,
        log: '${dur(mins)} in the gym',
        code: 'GYM',
      );
      p[k] = g;
      t.stats.workouts += 1;
      _countWorkout(t, k, g);
      _checkPerfectWeek(t);
      return tx('Saved as a gym session. Add what you trained from Plan.');
    }
    if (w != null && w.key == k && s.status != SessionStatus.done) {
      state.workout = null;
      _saveLogs(t, k, w, s);
      _complete(t, k, s, _checkedSets(w, s));
      _timeIt(w, s);
    } else if ({SessionStatus.approved, SessionStatus.moved, SessionStatus.pending}.contains(s.status)) {
      _complete(t, k, s, s.totalSets, checked: false);
    }
    if (s.status != SessionStatus.done) return null;
    if (!(s.log ?? '').contains('in the gym')) s.log = '${s.log} · ${dur(mins)} in the gym';
    final coach = s.byCoach ? coachNameOf(t) : null;
    return coach == null
        ? tx('{workout} done.', {'workout': tx(s.title)})
        : tx('{workout} done. Send {name} an update from Me.', {'workout': tx(s.title), 'name': firstName(coach)});
  }

  (Visit, List<String>) _closeVisit(String id, GymIn g, int mins, {required bool auto}) {
    state.gymIn.remove(id);
    _notify.cancelCheckout();
    _notify.clearInGym();
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
    if (!auto && mins >= 90) t.stats.long++;
    return (v, newlyUnlocked(before, t.stats));
  }

  /// Shows the live gym timer when the owner is checked in, e.g. after a
  /// restart cleared the notification.
  void syncGymTimer() {
    final g = state.gymIn[state.account?.id];
    if (g == null) {
      _notify.clearInGym();
    } else {
      _notify.showInGym(g.checkInTime(), g.since);
    }
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
    _toast(tx('{day} confirmed', {'day': fmtDay(k)}));
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
    _toast(tx('{n} confirmed', {'n': plural(n, 'session')}));
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
    _toast(tx('Moved to {day}', {'day': fmtDay(to)}));
    syncSessionReminders();
    return true;
  }

  // Workout

  /// Starts day [k]'s workout. A fresh start swaps exercises that load a
  /// flagged injury to their safer alternative.
  void startWorkout(String k) {
    if (state.workout?.key != k) {
      state.workout = ActiveWorkout(key: k, started: now.millisecondsSinceEpoch);
      final t = trOrNull(state.account!.id);
      final flagged = [
        for (final e in plan(t?.id ?? '')[k]?.ex ?? const <Exercise>[])
          if (isFlagged(t, e) && e.alt != null) e,
      ];
      for (final e in flagged) {
        swapExercise(e);
      }
      if (flagged.isNotEmpty) {
        _toast(tx('{n} swapped for your injury flags', {'n': plural(flagged.length, 'exercise')}));
      }
    }
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
    if (!a[i]) w.logs[exId]?.remove(i);
    _commit();
    return a[i];
  }

  /// Ticks set [i] with the weight and reps done, or updates a ticked one.
  void logSet(String exId, int i, SetLog log) {
    final w = state.workout;
    if (w == null) return;
    final a = w.done.putIfAbsent(exId, () => []);
    while (a.length <= i) {
      a.add(false);
    }
    a[i] = true;
    w.logs.putIfAbsent(exId, () => {})[i] = log;
    _commit();
  }

  void swap(Exercise e) {
    swapExercise(e);
    _commit();
    _toast(tx('Swapped to {name}', {'name': tx(e.name)}));
  }

  /// Swaps [e] for [name], another exercise for the same muscle, with that
  /// exercise's reps and load. Picking the original again undoes the swap.
  /// A coach's change turns the day back into a draft.
  void swapTo(Exercise e, String name) {
    final x = kExerciseByName[name];
    if (x == null) return;
    final first = e.swapped ? e.orig : e.name;
    e
      ..name = name
      ..reps = x.reps
      ..load = x.load
      ..area = x.area
      ..alt = x.alt
      ..swapped = name != first
      ..orig = name != first ? first : '';
    if (_isCoach) {
      for (final s in state.plans.values.expand((p) => p.values)) {
        if (s.ex.contains(e) && s.status != SessionStatus.done) s.status = SessionStatus.draft;
      }
    }
    _commit();
    _toast(tx('Swapped to {name}', {'name': tx(name)}));
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
    final before = t.stats.copy();
    final prs = _saveLogs(t, w.key, w, p);
    _complete(t, w.key, p, _checkedSets(w, p));
    _timeIt(w, p);
    final unlocked = newlyUnlocked(before, t.stats);
    _commit();
    _toast(
      tx('Workout logged · {log}', {'log': logText(p.log)}) +
          (prs.isEmpty
              ? ''
              : ' · ${prs.length == 1 ? tx('PR on {name}', {'name': tx(prs.first)}) : tx('{n} PRs', {'n': prs.length})}'),
    );
    syncSessionReminders();
    return unlocked;
  }

  /// Copies the ticked sets' weight and reps onto the session's exercises
  /// and counts personal records: a better estimated 1RM or a heavier top
  /// set than any earlier workout. Returns the lifts with a record.
  List<String> _saveLogs(Trainee t, String k, ActiveWorkout w, Session p) {
    final prs = <String>[];
    for (final e in p.ex) {
      e.logged
        ..clear()
        ..addAll([
          for (var i = 0; i < e.sets; i++)
            if (w.isDone(e.id, i)) w.log(e.id, i) ?? SetLog(),
        ]);
      if (e.logged.isEmpty || prs.contains(e.name)) continue;
      final prev = liftHistory(plan(t.id), e.name, before: k);
      if (prev.isEmpty) continue;
      final now = LiftDay(k, e.logged);
      double? most(double? Function(LiftDay) f) =>
          prev.map(f).whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a);
      final best = most((d) => d.best), top = most((d) => d.topKg);
      if ((now.best != null && best != null && now.best! > best + .01) ||
          (now.topKg != null && top != null && now.topKg! > top)) {
        prs.add(e.name);
      }
    }
    t.stats.prs += prs.length;
    p.prs
      ..clear()
      ..addAll(prs);
    return prs;
  }

  /// Minutes from starting the workout in Bolt to now.
  void _timeIt(ActiveWorkout w, Session p) {
    final started = w.started;
    if (started != null) p.took = math.max(1, ((now.millisecondsSinceEpoch - started) / 60000).round());
  }

  /// Sets or clears a hand-entered one-rep max for [name].
  void setMax(String tid, String name, double? kg) {
    final t = tr(tid);
    if (kg == null) {
      t.maxes.remove(name);
    } else {
      t.maxes[name] = kg;
    }
    _commit();
    _toast(kg == null ? tx('Max cleared') : tx('Max saved'));
  }

  /// Sets or clears a target max for [name], to reach by day [by].
  void setLiftGoal(String tid, String name, double? kg, String by) {
    final t = tr(tid);
    if (kg == null) {
      t.liftGoals.remove(name);
    } else {
      t.liftGoals[name] = (kg, by);
    }
    _commit();
    _toast(kg == null ? tx('Goal removed') : tx('Goal saved'));
  }

  /// Adds [a] to day [k]'s workout, from a suggestion on Today.
  void addToDay(String tid, String k, ExSeed a) {
    final s = plan(tid)[k];
    if (s == null || s.status == SessionStatus.done) return;
    s.ex.add(exerciseFromSeed(a, state.uid()));
    if (_isCoach && s.status != SessionStatus.draft) s.status = SessionStatus.draft;
    _commit();
    _toast(tx('{name} added to {day}', {'name': tx(a.name), 'day': fmtDay(k)}));
  }

  /// Closes a suggestion on Today for good.
  void dismissHint(String id) {
    state.settings.hintsSeen.add(id);
    _commit();
  }

  int _checkedSets(ActiveWorkout w, Session p) {
    var dn = 0;
    for (final e in p.ex) {
      for (var i = 0; i < e.sets; i++) {
        if (w.isDone(e.id, i)) dn++;
      }
    }
    return dn;
  }

  /// Marks day [k] done with [dn] sets and counts it toward badges. Sets that
  /// were not [checked] off one by one never count as a full workout.
  void _complete(Trainee t, String k, Session p, int dn, {bool checked = true}) {
    p.status = SessionStatus.done;
    p.log = '$dn/${p.totalSets} sets';
    t.stats
      ..workouts += 1
      ..sets += dn;
    if (checked && dn > 0 && dn == p.totalSets) t.stats.full++;
    _countWorkout(t, k, p);
    _checkPerfectWeek(t);
  }

  /// Logs a past day from a solo user's diary: done with every set, counted
  /// toward badges like a finished workout. Returns badges it unlocked.
  List<String> logPast(String k) {
    final t = tr(state.account!.id);
    final p = plan(t.id)[k];
    if (p == null || !canLogPast(t.id, k)) return const [];
    if (p.status != SessionStatus.approved && p.status != SessionStatus.moved) return const [];
    p.status = SessionStatus.done;
    p.log = '${p.totalSets}/${p.totalSets} sets';
    final before = t.stats.copy();
    t.stats
      ..workouts += 1
      ..sets += p.totalSets
      ..diary += 1;
    _countWorkout(t, k, p);
    _checkPerfectWeek(t);
    final unlocked = newlyUnlocked(before, t.stats);
    _commit();
    syncSessionReminders();
    _toast(tx('{day} logged · {log}', {'day': fmtDay(k), 'log': logText(p.log)}));
    return unlocked;
  }

  /// Counters for the kind of workout logged on day [k]: weekend, variety,
  /// custom-built and the muscle groups it trained.
  void _countWorkout(Trainee t, String k, Session p) {
    if (pk(k).weekday >= DateTime.saturday) t.stats.weekend++;
    _countDetails(t, p);
  }

  /// Variety, custom-built and muscle counters. A gym session without
  /// exercises counts once its details are filled in.
  void _countDetails(Trainee t, Session p) {
    if (p.ex.isEmpty) return;
    final s = t.stats;
    s.kinds.add(p.title.trim().toLowerCase());
    if (p.tpl == mixTpl || (state.tpls[p.tpl]?.custom ?? false)) s.built++;
    for (final g in sessionGroups(p)) {
      s.muscles[g] = (s.muscles[g] ?? 0) + 1;
    }
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
    final last = t.stats.lastPerfectWeek;
    t.stats
      ..perfect += 1
      ..streak = last != null && awayBridge(t.stats, last, wk) ? t.stats.streak + 1 : 1
      ..lastPerfectWeek = wk;
    t.stats.bestStreak = math.max(t.stats.bestStreak, t.stats.streak);
  }

  // Deload, challenges, goals

  /// Halves the sets of every session not done yet in the week starting
  /// [mon], or undoes it when that week is already a deload week.
  void toggleDeload(String tid, DateTime mon) {
    final p = plan(tid);
    final week = [
      for (var i = 0; i < 7; i++)
        if (p[dk(addDays(mon, i))] case final Session s when s.status != SessionStatus.done) s,
    ];
    if (week.isEmpty) {
      _toast(tx('Nothing planned that week'));
      return;
    }
    final undo = week.any((s) => s.deload);
    for (final s in week) {
      if (undo == !s.deload) continue;
      for (final e in s.ex) {
        if (undo) {
          e.sets = e.fullSets ?? e.sets;
          e.fullSets = null;
        } else {
          e.fullSets = e.sets;
          e.sets = math.max(1, (e.sets / 2).ceil());
        }
      }
      s.deload = !undo;
      if (undo && s.note == deloadNote) s.note = '';
      if (!undo && s.note.isEmpty) s.note = deloadNote;
      if (_isCoach && s.status != SessionStatus.draft) s.status = SessionStatus.draft;
    }
    _commit();
    _toast(
      undo
          ? tx('Deload undone · full sets back')
          : tx('Deload week · {n} halved', {'n': plural(week.length, 'session')}),
    );
    if (!_isCoach) syncSessionReminders();
  }

  /// Starts [id] this week: empty days of its weeks are filled from the
  /// split, then the main lifts of every session not done get the week's
  /// sets, reps and % load. A coach's changed days become drafts.
  void startProgram(String tid, String id) {
    final prog = programById(id);
    if (prog == null) return;
    final t = tr(tid);
    final p = plan(tid);
    final split = splitOf(state, t.split);
    var lifts = 0;
    for (var w = 0; w < prog.weeks.length; w++) {
      final (sets, reps, pct) = prog.weeks[w];
      for (final d in split.days) {
        final k = dk(addDays(mon0, 7 * w + d.weekday - 1));
        if (k.compareTo(today) >= 0 && p[k] == null) p[k] = sessionFromTemplate(state, d.tpl, _newStatus);
      }
      for (var i = 0; i < 7; i++) {
        final s = p[dk(addDays(mon0, 7 * w + i))];
        if (s == null || s.status == SessionStatus.done) continue;
        for (final e in s.ex.where((e) => kMainLifts.contains(e.name))) {
          e
            ..sets = sets
            ..reps = reps
            ..load = pctText(pct);
          lifts++;
          if (_isCoach) s.status = SessionStatus.draft;
        }
      }
    }
    t
      ..program = id
      ..programStart = dk(mon0);
    _commit();
    _toast(
      lifts == 0
          ? tx('No main barbell lifts in this split, so loads stay as they are')
          : tx('{name} planned for {n}', {'name': tx(prog.name), 'n': plural(prog.weeks.length, 'week')}),
    );
    if (!_isCoach) syncSessionReminders();
  }

  /// Ends the program; planned days keep their loads.
  void stopProgram(String tid) {
    tr(tid)
      ..program = null
      ..programStart = null;
    _commit();
    _toast(tx('Program stopped'));
  }

  /// The owner's level when it is higher than the last one celebrated, once.
  /// A save from before levels only remembers where it stands.
  int? levelUp() {
    final t = trOrNull(state.account?.id ?? '');
    if (t == null) return null;
    final l = levelOf(xpOf(t.stats)).level;
    final seen = state.settings.levelSeen;
    if (seen != null && l <= seen) return null;
    state.settings.levelSeen = l;
    _commit();
    return seen == null ? null : l;
  }

  /// Marks day [k] as a rest day, or clears the mark. A session planned
  /// there that is not done yet makes way for the rest.
  void toggleRest(String k) {
    final id = state.account!.id;
    final rest = tr(id).stats.rest;
    final s = plan(id)[k];
    if (rest.remove(k)) {
      _toast(tx('Rest day cleared'));
    } else {
      if (s?.status == SessionStatus.done) return;
      plan(id).remove(k);
      rest.add(k);
      _toast(tx('Rest day · recover well'));
    }
    _commit();
    syncSessionReminders();
  }

  /// Marks [weeks] weeks from Monday [from] as away, or clears them when the
  /// first is already away. Away weeks keep the streak and skip reminders.
  void toggleAway(DateTime from, int weeks) {
    final s = tr(state.account!.id).stats;
    final keys = [for (var i = 0; i < weeks; i++) dk(addDays(from, 7 * i))];
    final clear = s.away.contains(keys.first);
    clear ? s.away.removeAll(keys) : s.away.addAll(keys);
    _commit();
    _toast(
      clear
          ? tx('Back on · away weeks cleared')
          : tx('Away {from} to {to} · your streak is safe', {
              'from': fmtDay(keys.first),
              'to': fmtDay(dk(addDays(pk(keys.last), 6))),
            }),
    );
    syncSessionReminders();
  }

  /// Sets or clears a challenge. For a coach the returned plan message
  /// carries it to the trainee.
  String? setChallenge(String tid, Challenge? c) {
    tr(tid).challenge = c;
    _commit();
    _toast(c == null ? tx('Challenge removed') : tx('Challenge set · {title}', {'title': c.title}));
    return _isCoach ? planMessage(tid) : null;
  }

  /// Today's readiness check-in: sleep, energy and soreness, 1 to 3 each.
  /// Only the last 60 days are kept.
  void setReadiness(List<int> r) {
    final t = tr(state.account!.id);
    t.readiness[today] = r;
    final cut = dk(addDays(now, -60));
    t.readiness.removeWhere((k, _) => k.compareTo(cut) < 0);
    _commit();
  }

  /// Takes a set off every exercise on day [k] for a low-readiness day.
  void lightenDay(String tid, String k) {
    final s = plan(tid)[k];
    if (s == null || s.status == SessionStatus.done || s.note == lighterNote) return;
    for (final e in s.ex) {
      e.sets = math.max(1, e.sets - 1);
    }
    if (s.note.isEmpty) s.note = lighterNote;
    _commit();
    _toast(tx('Lighter today · one set less per exercise'));
  }

  /// Logs a period that started on day [k], for cycle tracking.
  void logPeriod(String k) {
    final t = tr(state.account!.id);
    if (!t.periods.contains(k)) t.periods.add(k);
    t.periods.sort();
    _commit();
    _toast(tx('Period start saved · {day}', {'day': fmtDay(k)}));
  }

  void removePeriod(String k) {
    tr(state.account!.id).periods.remove(k);
    _commit();
  }

  void setBodyGoal(String? tid, String key, double? value) {
    final b = bodyFor(tid);
    if (b == null) return;
    if (value == null) {
      b.goals.remove(key);
    } else {
      b.goals[key] = value;
    }
    _commit();
  }

  /// Monday recap card closed for the week starting [weekKey].
  void dismissRecap(String weekKey) {
    state.settings.recapSeen = weekKey;
    _commit();
  }

  // Backup

  /// Everything on this phone as one file's text.
  String backupText() => const JsonEncoder.withIndent(' ').convert({'bolt': 'backup', ...state.toJson()});

  /// Replaces everything on this phone with a backup. Returns an error to
  /// show, or null when it worked.
  String? restore(String text) {
    Map<String, dynamic> j;
    try {
      j = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return tx('That file is not a Bolt backup.');
    }
    if (j['bolt'] != 'backup') return tx('That file is not a Bolt backup.');
    if (j['version'] != BoltData.version) return tx('This backup is from a different Bolt version.');
    try {
      final d = BoltData.fromJson(j);
      addMissingTemplates(d);
      _notify.cancelCheckout();
      state = d;
      appLang = AppLang.byName(d.settings.lang);
      appFemale = _ownerFemale(d);
      ref.read(repositoryProvider).scheduleSave(state);
      syncSessionReminders();
      syncGymTimer();
      _toast(tx('Backup restored'));
      return null;
    } catch (_) {
      return tx('That backup could not be read.');
    }
  }

  // Planning, for a coach's trainees and for the owner's own plan. A coach
  // plans drafts that are sent for approval; people planning for themselves
  // get confirmed sessions straight away.

  SessionStatus get _newStatus => _isCoach ? SessionStatus.draft : SessionStatus.approved;

  /// Solo users can fill in days already behind them from their own diary.
  /// Trainees and coaches plan from today on.
  bool canLogPast(String tid, String k) =>
      state.account?.role == Role.solo && tid == state.account!.id && k.compareTo(today) < 0;

  /// Tapping an empty day adds the next workout in the rotation: from today
  /// on, or on a past day for a solo user's diary.
  bool addFromRotation(String tid, String k) {
    final t = tr(tid);
    final p = plan(tid);
    if (p[k] != null || (k.compareTo(today) < 0 && !canLogPast(tid, k))) return false;
    p[k] = sessionFromTemplate(state, nextInRotation(p, splitOf(state, t.split), k), _newStatus);
    t.stats.rest.remove(k);
    _commit();
    if (!_isCoach) syncSessionReminders();
    return true;
  }

  /// Returns badges unlocked by filling in a logged gym session.
  List<String> setTemplate(String tid, String k, String tplId) {
    final p = plan(tid);
    final o = p[k];
    if (o == null || (o.status == SessionStatus.done && !canFillIn(o))) return const [];
    final n = p[k] = sessionFromTemplate(state, tplId, _isCoach ? SessionStatus.draft : o.status)
      ..note = o.note
      ..from = o.from
      ..byCoach = o.byCoach;
    final unlocked = o.status == SessionStatus.done ? _filledIn(tid, o, n) : const <String>[];
    _commit();
    return unlocked;
  }

  /// A logged day the owner planned themselves can still get its details,
  /// e.g. a gym session saved by scanning out.
  bool canFillIn(Session s) => s.status == SessionStatus.done && !_isCoach && !s.byCoach;

  /// Keeps a filled-in day logged and counts what it trained, the first time
  /// it gets exercises.
  List<String> _filledIn(String tid, Session old, Session s) {
    s
      ..status = SessionStatus.done
      ..log = old.log;
    if (old.ex.isNotEmpty) return const [];
    final t = tr(tid);
    final before = t.stats.copy();
    t.stats.sets += s.totalSets;
    _countDetails(t, s);
    return newlyUnlocked(before, t.stats);
  }

  /// Replaces day [k] with a workout built from [muscles]: [ex] as picked in
  /// the muscle builder. Kept as a one-off day, or saved to the Library as a
  /// template when [save] is set.
  List<String> useMuscles(String tid, String k, List<String> muscles, List<ExSeed> ex, {bool save = false}) {
    if (save) {
      _toast(tx('{name} saved to your Library', {'name': musclesTitle(muscles)}));
      return setTemplate(tid, k, templateFromMuscles(muscles, ex));
    }
    final p = plan(tid);
    final o = p[k];
    if (o != null && o.status == SessionStatus.done && !canFillIn(o)) return const [];
    final n = p[k] = Session(
      tpl: mixTpl,
      title: musclesTitle(muscles),
      focus: [for (final m in muscles) tx(kMuscles[m]?.name ?? m)].join(' · '),
      mins: _minsFor(ex),
      ex: [for (final e in ex) exerciseFromSeed(e, state.uid())],
      status: _isCoach ? SessionStatus.draft : (o?.status ?? SessionStatus.approved),
      note: o?.note ?? '',
      from: o?.from,
      byCoach: o?.byCoach ?? false,
      code: musclesCode(muscles),
    );
    final unlocked = o != null && o.status == SessionStatus.done ? _filledIn(tid, o, n) : const <String>[];
    _commit();
    if (!_isCoach) syncSessionReminders();
    return unlocked;
  }

  /// Saves a muscle-builder workout as a custom template. Returns its id.
  String templateFromMuscles(List<String> muscles, List<ExSeed> ex) {
    final id = _newTemplateId();
    state.tpls[id] = WorkoutTemplate(
      id: id,
      name: musclesTitle(muscles),
      code: musclesCode(muscles),
      focus: [for (final m in muscles) tx(kMuscles[m]?.name ?? m)].join(' · '),
      mins: _minsFor(ex),
      ex: [for (final e in ex) exerciseFromSeed(e, state.uid())],
      custom: true,
    );
    _commit();
    return id;
  }

  /// About three minutes a set, warm-up included.
  int _minsFor(List<ExSeed> ex) => (ex.fold(0, (a, e) => a + e.sets) * 3).clamp(20, 120);

  void removeDay(String tid, String k) {
    final was = plan(tid).remove(k)?.status;
    _commit();
    _toast(was == SessionStatus.draft ? tx('Draft removed') : tx('Removed'));
    if (!_isCoach) syncSessionReminders();
  }

  /// Next 3 weeks from this Monday: each split day on its weekday when that
  /// date is today or later and empty.
  void autoFill(String tid) {
    final split = splitOf(state, tr(tid).split);
    final n = _fill(tid, _newStatus);
    _commit();
    _toast(
      n == 0
          ? tx('The next 3 weeks are already planned')
          : tx(_isCoach ? '{n} drafted from {split}' : '{n} planned from {split}', {
              'n': plural(n, 'session'),
              'split': tx(split.name),
            }),
    );
    if (!_isCoach) syncSessionReminders();
  }

  int _fill(String tid, SessionStatus status) {
    final p = plan(tid);
    var n = 0;
    for (var w = 0; w < 3; w++) {
      for (final d in splitOf(state, tr(tid).split).days) {
        final k = dk(addDays(mon0, 7 * w + d.weekday - 1));
        if (k.compareTo(today) >= 0 && p[k] == null) {
          p[k] = sessionFromTemplate(state, d.tpl, status);
          n++;
        }
      }
    }
    return n;
  }

  void setSplit(String tid, String id) {
    tr(tid).split = id;
    _commit();
    _toast(tx('Split set to {name}', {'name': tx(splitOf(state, id).name)}));
  }

  // Custom splits

  /// A new empty split. Returns its id.
  String newSplit() {
    var n = state.splits.length + 1;
    while (state.splits.containsKey('sp$n')) {
      n++;
    }
    final id = 'sp$n';
    state.splits[id] = CustomSplit(id: id, name: tx('My split {n}', {'n': n}));
    _commit();
    return id;
  }

  void renameSplit(String id, String name) {
    final x = state.splits[id];
    if (x == null) return;
    x.name = name.trim().isEmpty ? x.name : name.trim();
    _commit();
  }

  /// Sets the workout on weekday [wd] (1 = Monday), or a rest day when null.
  void setSplitDay(String id, int wd, String? tpl) {
    final x = state.splits[id];
    if (x == null) return;
    if (tpl == null) {
      x.days.remove(wd);
    } else {
      x.days[wd] = tpl;
    }
    _commit();
  }

  /// Deletes a custom split; anyone on it goes back to Push / Pull / Legs.
  void deleteSplit(String id) {
    final name = state.splits.remove(id)?.name;
    for (final t in state.trainees) {
      if (t.split == id) t.split = 'ppl';
    }
    _commit();
    if (name != null) _toast(tx('{name} deleted', {'name': name}));
  }

  /// Coach OKs a moved session.
  void ack(String tid, String k) {
    final p = plan(tid)[k];
    if (p == null) return;
    p
      ..status = SessionStatus.approved
      ..from = null;
    _commit();
    _toast(tx('Change accepted'));
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
    _toast(tx('Flag resolved'));
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
        note: note.trim().isEmpty ? tx('{area} pain reported', {'area': tx(kAreas[area]!)}) : note.trim(),
        by: '$by · ${_dayLabel(now)}',
        fresh: role == Role.trainee,
      ),
    );
    _commit();
    final coach = coachNameOf(t);
    _toast(
      role == Role.trainee && coach != null
          ? tx('Saved · send {name} an update so they see it', {'name': firstName(coach)})
          : tx('Flag added · matching exercises show swaps'),
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
    _toast(tx('{name} added', {'name': tx(a.name)}));
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
        _toast(tx('Session saved'));
        return null;
      case TemplateTarget():
        _commit();
        _toast(tx('Template saved · used by future auto-fills'));
        return null;
    }
  }

  String _newTemplateId() {
    var n = state.tpls.keys.where((k) => k.startsWith('cu')).length + 1;
    while (state.tpls.containsKey('cu$n')) {
      n++;
    }
    return 'cu$n';
  }

  String newTemplate() {
    final id = _newTemplateId();
    final n = id.substring(2);
    state.tpls[id] = WorkoutTemplate(
      id: id,
      name: tx('Custom {n}', {'n': n}),
      code: 'CUST',
      focus: tx('Custom session'),
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
      'challenge': t.challenge?.toJson(),
      'program': t.program,
      'programStart': t.programStart,
      // Template ids differ between phones, so each day carries its own code.
      'sessions': {
        for (final k in keys)
          k: plan(tid)[k]!.toJson()..['code'] = plan(tid)[k]!.code ?? state.tpls[plan(tid)[k]!.tpl]?.code,
      },
    });
    final range = keys.isEmpty ? '' : tx(', {from} to {to}', {'from': fmtDay(keys.first), 'to': fmtDay(keys.last)});
    return '${tx('{name}, here is your Bolt plan from {coach}:', {'name': vocative(firstName(t.name)), 'coach': firstName(coach.name)})} '
        '${plural(keys.length, 'session')}$range.\n'
        '${tx('In Bolt open Me, then Import plan. It reads this message from your clipboard.')}\n\n$code';
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
        for (final k in keys)
          k: {
            'status': p[k]!.status.name,
            'from': p[k]!.from,
            'log': p[k]!.log,
            // Logged weights and reps, so the coach sees lifts and PRs.
            if (p[k]!.status == SessionStatus.done) ...{
              'took': p[k]!.took,
              'prs': p[k]!.prs,
              'ex': [
                for (final e in p[k]!.ex)
                  if (e.logged.isNotEmpty) {'name': e.name, 'logged': e.logged.map((l) => l.toJson()).toList()},
              ],
            },
          },
      },
      'visits': [
        for (final v in state.visits[t.id] ?? const <Visit>[])
          if (v.date.compareTo(cutoff) >= 0) v.toJson(),
      ],
      'injuries': t.injuries.map((i) => i.toJson()).toList(),
      'stats': t.stats.toJson(),
      'maxes': t.maxes,
      'liftGoals': liftGoalsToJson(t.liftGoals),
      'readiness': {
        for (final e in t.readiness.entries)
          if (e.key.compareTo(dk(addDays(now, -14))) >= 0) e.key: e.value,
      },
      if (t.challenge case final Challenge c)
        'challenge': {'progress': challengeProgress(c, p, state.visits[t.id] ?? const [])},
      'body': t.body.toJson(last: 90),
    });
    final done = keys.where((k) => p[k]!.status == SessionStatus.done).length;
    final coach = coachNameOf(t);
    final head = coach == null
        ? tx('Bolt update from {name}:', {'name': firstName(t.name)})
        : tx('Bolt update from {name} for {coach}:', {'name': firstName(t.name), 'coach': firstName(coach)});
    return '$head ${tx('{done} done, {open} confirmed or moved.', {'done': plural(done, 'workout'), 'open': plural(keys.length - done, 'session')})}\n'
        '${tx('In Bolt open Trainees, then Import update. It reads this message from your clipboard.')}\n\n$code';
  }

  /// Imports a plan (trainee) or an update (coach) from pasted text. Returns
  /// an error to show, or null when it worked.
  String? importText(String text) {
    final packet = ShareCode.decode(text);
    if (packet == null) {
      return ShareCode.contains(text)
          ? tx('That code looks damaged. Copy the whole message again.')
          : tx('No Bolt code found in the copied text.');
    }
    final type = packet['type'];
    if (type == 'plan') {
      if (_isCoach) return tx('This is a plan for a trainee. Open it on their phone.');
      _importPlan(packet);
      return null;
    }
    if (type == 'update') {
      if (!_isCoach) return tx('This is an update for a coach. Open it on their phone.');
      return _importUpdate(packet);
    }
    return tx('This code is from a newer Bolt. Update the app and try again.');
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
        code: s.code,
      );
      n++;
    });
    final coachName = packet['coach'] as String?;
    if (coachName != null && coachName.trim().isNotEmpty) me.coachName = coachName.trim();
    state.linkId = packet['tid'] as String?;
    me
      ..program = packet['program'] as String?
      ..programStart = packet['programStart'] as String?;
    me.challenge = packet['challenge'] == null ? null : Challenge.fromJson(packet['challenge'] as Map<String, dynamic>);
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
      tx('{n} from {coach}', {
            'n': plural(n, 'session'),
            'coach': coachName == null ? tx('your coach') : firstName(coachName),
          }) +
          (pending > 0 ? tx(' · {n} waiting for your OK', {'n': pending}) : ''),
    );
  }

  String? _importUpdate(Map<String, dynamic> packet) {
    final tid = packet['tid'] as String?;
    final t = tid == null ? null : trOrNull(tid);
    if (t == null) {
      return tx('This update is from someone who is not in your trainees. Send them a plan first.');
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
            ..log = j['log'] as String?
            ..took = j['took'] as int?;
          s.prs
            ..clear()
            ..addAll([for (final x in j['prs'] as List? ?? const []) x as String]);
          final used = <Exercise>{};
          for (final x in j['ex'] as List? ?? const []) {
            final m = x as Map<String, dynamic>;
            final e = s.ex.where((e) => e.name == m['name'] && !used.contains(e)).firstOrNull;
            if (e == null) continue;
            used.add(e);
            e.logged
              ..clear()
              ..addAll([for (final l in m['logged'] as List) SetLog.fromJson(l as Map<String, dynamic>)]);
          }
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
    if (packet['challenge'] case {'progress': final int n}) t.challenge?.progress = n;
    if (packet['maxes'] case final Map<String, dynamic> m) {
      t.maxes
        ..clear()
        ..addAll(m.map((k, v) => MapEntry(k, (v as num).toDouble())));
    }
    if (packet['liftGoals'] != null) {
      t.liftGoals
        ..clear()
        ..addAll(liftGoalsFromJson(packet['liftGoals']));
    }
    if (packet['readiness'] != null) {
      t.readiness
        ..clear()
        ..addAll(readinessFromJson(packet['readiness']));
    }
    final body = Body.fromJson(packet['body'] as Map<String, dynamic>?);
    // The trainee's history wins; days only the coach logged are kept.
    if (!body.isEmpty) t.body = body..mergeHistory(t.body.history);
    _commit();
    _toast(
      tx('Update from {name} · {ok} confirmed, {moved} moved, {done} done', {
        'name': firstName(t.name),
        'ok': ok,
        'moved': moved,
        'done': done,
      }),
    );
    return null;
  }

  // Settings

  void toggleSetting(String key) {
    final s = state.settings;
    switch (key) {
      case 'remind':
        s.remind = !s.remind;
      case 'brief':
        s.brief = !s.brief;
      case 'checkout':
        s.checkout = !s.checkout;
        if (!s.checkout) _notify.cancelCheckout();
    }
    _commit();
    if (key == 'remind' || key == 'brief') syncSessionReminders();
  }

  void toggleUnits() {
    state.settings.kg = !state.settings.kg;
    _commit();
  }

  void toggleWeekStart() {
    state.settings.mondayFirst = !state.settings.mondayFirst;
    _commit();
  }

  /// Auto, then 60 to 180 seconds, then back to Auto.
  void cycleRest() {
    const steps = [60, 90, 120, 150, 180];
    final st = state.settings;
    if (st.restAuto) {
      st
        ..restAuto = false
        ..restSecs = steps.first;
    } else {
      final i = steps.indexOf(st.restSecs);
      if (i < 0 || i == steps.length - 1) {
        st.restAuto = true;
      } else {
        st.restSecs = steps[i + 1];
      }
    }
    _commit();
  }

  void toast(String text) => _toast(text);

  /// Reminders 2 hours before each confirmed session in the coming week, at
  /// the trainee's usual check-in time, and a morning brief at 8:00 when
  /// that is later. Days with nothing planned and 3 or more days off get a
  /// nudge at 9:00 instead, and from 5 days off another one 2 hours before
  /// the usual check-in.
  void syncSessionReminders() {
    final a = state.account;
    final st = state.settings;
    if (a == null || !a.isTrainee || (!st.remind && !st.brief)) {
      _notify.replaceSessionReminders(const []);
      return;
    }
    final usual = _usualCheckIn(a.id);
    final p = plan(a.id);
    final list = <Reminder>[];
    final stats = trOrNull(a.id)?.stats;
    for (var i = 0; i < 8; i++) {
      final d = addDays(now, i);
      final day = DateTime(d.year, d.month, d.day);
      final s = p[dk(d)];
      if (stats?.away.contains(dk(monday(d))) ?? false) continue;
      final at = day.add(Duration(minutes: usual - 120));
      if (s == null || (s.status != SessionStatus.approved && s.status != SessionStatus.moved)) {
        if (!st.remind) continue;
        // Not while checked in: that visit counts once it closes.
        if (i == 0 && state.gymIn[a.id] != null) continue;
        final off = daysOff(p, state.visits[a.id] ?? const [], stats?.rest ?? const {}, d);
        if (off < 3) continue;
        final title = tx('{days} off', {'days': plural(off, 'day')});
        list.add(Reminder(at: day.add(const Duration(hours: 9)), title: title, body: _offBody(off)));
        if (off >= 5 && at.hour > 9) {
          list.add(Reminder(at: at, title: tx('Still time to train today'), body: _offBody(off)));
        }
        continue;
      }
      final morning = day.add(const Duration(hours: 8));
      if (st.brief && at.difference(morning).inMinutes >= 60) {
        list.add(
          Reminder(at: morning, title: tx('Today: {workout}', {'workout': tx(s.title)}), body: brief(a.id, dk(d))),
        );
      }
      if (!st.remind) continue;
      list.add(
        Reminder(
          at: at,
          title: tx('{workout} today', {'workout': tx(s.title)}),
          body: tx('{focus} · ~{mins} min. Scan the plaque when you arrive.', {'focus': tx(s.focus), 'mins': s.mins}),
        ),
      );
    }
    _notify.replaceSessionReminders(list);
  }

  /// The morning brief for day [k]: the size of the workout and what to
  /// beat, a weight to go for or the last time's log.
  String brief(String tid, String k) {
    final p = plan(tid);
    final s = p[k]!;
    final size = '${plural(s.ex.length, 'exercise')} · ~${s.mins} min';
    final metric = state.settings.kg;
    for (final e in s.ex) {
      final h = hintFor(p, e, k);
      if (h != null && h.up && h.nextKg != null) {
        return tx('{size}. Go for {kg} on {name}.', {
          'size': size,
          'kg': '${weightValue(h.nextKg, metric: metric)} ${weightUnit(metric)}',
          'name': tx(e.name),
        });
      }
    }
    if (lastSame(p, s, k) case final last?) {
      return tx('{size}. Last time {log}. Beat it.', {'size': size, 'log': logText(p[last]!.log)});
    }
    return '$size · ${tx(s.focus)}';
  }

  String _offBody(int off) => off >= 5
      ? tx('Your body has recovered and the habit is slipping. Get to the gym today, even 20 minutes counts.')
      : off == 4
      ? tx('Recovery is done. Time to move before the habit slips.')
      : tx('Rested enough? A short session today keeps the habit going.');

  /// Median check-in time of recent visits, in minutes after midnight.
  int _usualCheckIn(String id) {
    final v = (state.visits[id] ?? const <Visit>[]).take(10).map((x) => toMin(x.inT)).toList()..sort();
    return v.isEmpty ? 18 * 60 : v[v.length ~/ 2];
  }
}
