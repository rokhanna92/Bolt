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
import 'seed/demo.dart';
import 'seed/splits.dart';
import 'seed/templates.dart';

/// Current time. Overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final repositoryProvider = Provider<BoltRepository>((ref) => BoltRepository.memory());

final notificationsProvider = Provider<BoltNotifications>((ref) => const NoopNotifications());

/// Data loaded at startup.
final initialDataProvider = Provider<BoltData>((ref) => buildDemoData(ref.read(clockProvider)()));

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

/// All business rules, ported from the prototype's component methods. State is
/// mutated in place and listeners are notified, then saved in the background.
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

  // Lookups

  Trainee tr(String id) => state.trainees.firstWhere((t) => t.id == id);
  Trainee? trOrNull(String id) {
    for (final t in state.trainees) {
      if (t.id == id) return t;
    }
    return null;
  }

  Coach co(String id) => state.coaches.firstWhere((c) => c.id == id, orElse: () => state.coaches.first);
  Map<String, Session> plan(String tid) => state.plans.putIfAbsent(tid, () => {});
  String unit(String load) => unitLoad(load, kg: state.settings.kg);
  String _dayLabel(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';

  // Account

  void signIn(Role role, String id) {
    state.account = Account(role, id);
    state.workout = null;
    _commit();
    syncSessionReminders();
  }

  void signOut() {
    state.account = null;
    state.workout = null;
    _commit();
    syncSessionReminders();
  }

  void resetDemo() {
    _notify.cancelCheckout();
    _notify.replaceSessionReminders(const []);
    state = buildDemoData(now);
    ref.read(repositoryProvider).scheduleSave(state);
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
    final t = tr(state.account!.id);
    var n = 0;
    for (final p in plan(t.id).values) {
      if (p.status == SessionStatus.pending) {
        p.status = SessionStatus.approved;
        n++;
      }
    }
    _commit();
    _toast('${plural(n, 'session')} confirmed · ${firstName(co(t.coach).name)} notified');
    syncSessionReminders();
  }

  /// Moves a session onto an empty day that is today or later.
  bool move(String from, String to) {
    final t = tr(state.account!.id);
    final p = plan(t.id);
    if (p[to] != null || to.compareTo(today) < 0) return false;
    final o = p.remove(from);
    if (o == null) return false;
    p[to] = o
      ..status = SessionStatus.moved
      ..from = o.from ?? from;
    _commit();
    _toast('Moved to ${fmtDay(to)} · ${firstName(co(t.coach).name)} notified');
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
    final unlocked = _checkPerfectWeek(t);
    _commit();
    _toast('Workout logged · ${p.log}');
    syncSessionReminders();
    return unlocked;
  }

  /// Every planned session this week done: a perfect week, which also
  /// extends the streak.
  List<String> _checkPerfectWeek(Trainee t) {
    final p = plan(t.id);
    final week = [for (var i = 0; i < 7; i++) p[dk(addDays(mon0, i))]]
        .whereType<Session>()
        .where((s) => s.status != SessionStatus.draft)
        .toList();
    final wk = dk(mon0);
    if (week.isEmpty || week.any((s) => s.status != SessionStatus.done) || t.stats.lastPerfectWeek == wk) {
      return const [];
    }
    final before = t.stats.copy();
    final prev = dk(addDays(mon0, -7));
    t.stats
      ..perfect += 1
      ..streak = t.stats.lastPerfectWeek == prev ? t.stats.streak + 1 : 1
      ..lastPerfectWeek = wk;
    return newlyUnlocked(before, t.stats);
  }

  // Coach planning

  /// Coach taps an empty future day: add the next workout in the rotation.
  void addFromRotation(String tid, String k) {
    final t = tr(tid);
    final p = plan(tid);
    if (p[k] != null || k.compareTo(today) < 0) return;
    p[k] = sessionFromTemplate(state, nextInRotation(p, t.split, k), SessionStatus.draft);
    _commit();
  }

  void setTemplate(String tid, String k, String tplId) {
    final p = plan(tid);
    final o = p[k];
    if (o == null || o.status == SessionStatus.done) return;
    p[k] = sessionFromTemplate(state, tplId, SessionStatus.draft)
      ..note = o.note
      ..from = o.from;
    _commit();
  }

  void removeDay(String tid, String k) {
    final was = plan(tid).remove(k)?.status;
    _commit();
    _toast(was == SessionStatus.draft ? 'Draft removed' : 'Removed · ${firstName(tr(tid).name)} will be notified');
  }

  /// Next 3 weeks from this Monday: each split day on its weekday when that
  /// date is today or later and empty.
  void autoFill(String tid) {
    final t = tr(tid);
    final p = plan(tid);
    final split = kSplits[t.split]!;
    var n = 0;
    for (var w = 0; w < 3; w++) {
      for (final d in split.days) {
        final k = dk(addDays(mon0, 7 * w + d.weekday - 1));
        if (k.compareTo(today) >= 0 && p[k] == null) {
          p[k] = sessionFromTemplate(state, d.tpl, SessionStatus.draft);
          n++;
        }
      }
    }
    _commit();
    _toast(n > 0 ? '${plural(n, 'session')} drafted from ${split.name}' : 'The next 3 weeks are already planned');
  }

  void sendDrafts(String tid) {
    final t = tr(tid);
    var n = 0;
    for (final s in plan(tid).values) {
      if (s.status == SessionStatus.draft) {
        s.status = SessionStatus.pending;
        n++;
      }
    }
    _commit();
    _toast('Sent ${plural(n, 'session')} · waiting for ${firstName(t.name)}');
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

  void nudge(String tid) => _toast('Reminder sent to ${firstName(tr(tid).name)}');

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
    final isT = state.account!.isTrainee;
    final by = isT ? 'Reported by ${firstName(t.name)}' : 'Added by ${firstName(co(state.account!.id).name)}';
    t.injuries.add(
      Injury(
        area: area,
        note: note.trim().isEmpty ? '${kAreas[area]} pain reported' : note.trim(),
        by: '$by · ${_dayLabel(now)}',
        fresh: isT,
      ),
    );
    _commit();
    _toast(
      isT
          ? '${firstName(co(t.coach).name)} notified · swaps suggested where needed'
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

  /// Any edit to a planned day that is not done turns it back into a draft
  /// that has to be re-sent.
  void edit(EditTarget target, void Function() fn) {
    fn();
    final o = editObject(target);
    if (o is Session && o.status != SessionStatus.done) o.status = SessionStatus.draft;
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

  void saveEdit(EditTarget target) {
    switch (target) {
      case DayTarget(:final tid, :final key):
        state.plans[tid]?[key]?.status = SessionStatus.pending;
        _commit();
        _toast('Sent to ${firstName(tr(tid).name)} for approval');
      case TemplateTarget():
        _commit();
        _toast('Template saved · used by future auto-fills');
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

  bool addCoach(String name, String role) {
    if (name.trim().isEmpty) return false;
    state.coaches.add(
      Coach(
        id: 'c${state.coaches.length + 1}x${now.millisecondsSinceEpoch % 1000}',
        name: name.trim(),
        role: role.trim().isEmpty ? 'Coach' : role.trim(),
      ),
    );
    _commit();
    _toast('${firstName(name)} added as a coach');
    return true;
  }

  // Settings

  void toggleSetting(String key) {
    final s = state.settings;
    switch (key) {
      case 'remind':
        s.remind = !s.remind;
      case 'plans':
        s.plans = !s.plans;
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
