import '../../core/format.dart';
import '../models/bolt_data.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../models/settings.dart';
import '../models/template.dart';
import 'splits.dart';
import 'templates.dart';

/// The check-in plaque. One permanent code: scanning it toggles check-in and
/// check-out. Every Bolt plaque carries the same token, so a printed plaque
/// works for anyone at that gym.
abstract final class Gym {
  static const plaqueToken = 'bolt-downtown-7f3k9q';
  static const plaqueUri = 'bolt://checkin?gym=$plaqueToken';

  /// True when [raw] is this gym's plaque.
  static bool isPlaque(String raw) {
    final u = Uri.tryParse(raw.trim());
    return u != null && u.scheme == 'bolt' && u.host == 'checkin' && u.queryParameters['gym'] == plaqueToken;
  }
}

Exercise exerciseFromSeed(ExSeed a, String id) =>
    Exercise(id: id, name: a.name, sets: a.sets, reps: a.reps, load: a.load, area: a.area, alt: a.alt);

/// Copies a template into a new session. Exercises are copied, never shared.
Session sessionFromTemplate(BoltData d, String tplId, SessionStatus status) {
  final x = d.tpls[tplId]!;
  return Session(
    tpl: tplId,
    title: x.name,
    focus: x.focus,
    mins: x.mins,
    ex: [for (final e in x.ex) e.copyWith(id: d.uid())],
    status: status,
  );
}

/// Puts each split day of the week starting at [mon] into [plan] where empty.
void fillWeek(BoltData d, Map<String, Session> plan, String split, DateTime mon, SessionStatus status) {
  for (final day in kSplits[split]!.days) {
    final k = dk(addDays(mon, day.weekday - 1));
    plan.putIfAbsent(k, () => sessionFromTemplate(d, day.tpl, status));
  }
}

/// A brand-new phone: the built-in templates and nothing else. The owner's
/// profile is created during onboarding.
BoltData freshData() {
  final d = BoltData(tpls: {}, coaches: [], trainees: [], plans: {}, visits: {}, gymIn: {}, settings: AppSettings());
  kTemplates.forEach((k, t) {
    d.tpls[k] = WorkoutTemplate(
      id: k,
      name: t.name,
      code: t.code,
      focus: t.focus,
      mins: t.mins,
      ex: [for (final e in t.ex) exerciseFromSeed(e, d.uid())],
    );
  });
  return d;
}
