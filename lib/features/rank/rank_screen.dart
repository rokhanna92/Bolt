import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/rank.dart';
import '../../data/strength.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../../widgets/rank_emblem.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/tap.dart';

/// "GOLD II", in the app language.
String rankText(int step) {
  final d = divisionOf(step);
  final tier = tx(kTiers[tierOf(step)]).toUpperCase();
  return d == 0 ? tier : '$tier ${const ['I', 'II', 'III'][d - 1]}';
}

/// What still stands between [t] and a rank: a bodyweight, a sex, a lift.
String placeHint(Trainee t) {
  if (t.body.weightKg == null || t.body.sex == null) {
    return tx('Add your bodyweight and sex to your profile, then log a main lift.');
  }
  return tx('Log a bench, squat, deadlift or another main lift with its weight and reps to get placed.');
}

/// Your rank on Today: emblem, name and the bar to the next division.
class RankCard extends StatelessWidget {
  const RankCard({super.key, required this.rank, required this.t});

  final Rank rank;
  final Trainee t;

  @override
  Widget build(BuildContext context) {
    final r = rank;
    return Tap(
      onTap: () => context.push('/rank'),
      child: Stage(
        color: _stageColor(r.tier),
        blend: BoltColors.rank,
        radius: 18,
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          children: [
            RankEmblem(step: r.step, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker(tx('RANK'), size: 9, spacing: .14),
                  const SizedBox(height: 2),
                  RankName(step: r.step, size: 17),
                  const SizedBox(height: 6),
                  if (r.placed && r.step < kAtlas)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: SizedBox(
                        height: 5,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: BoltColors.lineSoft),
                            GrowTo(
                              value: r.into,
                              builder: (context, v) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: v.clamp(0.0, 1.0),
                                child: ColoredBox(color: tierColor(r.tier)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!r.placed)
                    Text(
                      t.body.weightKg == null || t.body.sex == null
                          ? tx('Add your bodyweight and sex to get placed')
                          : tx('Log a main lift to get placed'),
                      style: BoltText.a(11, color: BoltColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Chevron(size: 16),
          ],
        ),
      ),
    );
  }
}

/// A rank's name in its colour; Atlas shimmers through its neon.
class RankName extends StatelessWidget {
  const RankName({super.key, required this.step, required this.size, this.center = false});

  final int step;
  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final tier = tierOf(step);
    final text = Text(
      rankText(step),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: BoltText.a(
        size,
        weight: 900,
        width: 112,
        // Bodyweight's grey reads as switched off, so its name is white.
        color: tier == kTiers.length - 1 || tier == 0 ? Colors.white : tierColor(tier),
      ),
    );
    if (tier != kTiers.length - 1) return text;
    return ShaderMask(
      shaderCallback: (b) => LinearGradient(colors: kAtlasNeon).createShader(b),
      child: text,
    );
  }
}

/// The rank in full: how far to the next one and what gets you there, what
/// counts, how it is worked out, the ladder, and a line to share.
class RankScreen extends ConsumerWidget {
  const RankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    if (t == null) return const BoltPage(child: SizedBox.expand());
    final r = rankOf(t, store.plan(t.id));
    final metric = d.settings.kg;
    final options = nextOptions(r, t.body);
    final insets = MediaQuery.paddingOf(context);
    String kg(double v) => fmtWeight(v, metric: metric);
    String reps(int n) => tx('{n} reps', {'n': '$n'});
    final bench = standardsFor('Bench Press', t.body.sex == null ? (Body()..sex = 'm') : t.body)!;
    String x(double v) => '${v == v.roundToDouble() ? v.round() : v}×';

    return BoltPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        children: [
          PageHead(onBack: () => context.pop(), kicker: tx('RANK'), title: tx('Your rank')),
          const SizedBox(height: 18),
          Stage(
            color: _stageColor(r.tier),
            blend: BoltColors.rank,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: PopIn(
                    duration: const Duration(milliseconds: 500),
                    child: RankEmblem(step: r.step, size: 170),
                  ),
                ),
                const SizedBox(height: 12),
                RankName(step: r.step, size: 38, center: true),
                const SizedBox(height: 6),
                Text(
                  !r.placed
                      ? placeHint(t)
                      : tx('Score {score} of {top}', {'score': r.score.toStringAsFixed(2), 'top': kAtlasScore.round()}),
                  textAlign: TextAlign.center,
                  style: BoltText.a(13, weight: 600, color: BoltColors.muted, height: 1.4),
                ),
                if (r.placed && r.step < kAtlas) ...[
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Kicker(tx('NEXT: {rank}', {'rank': rankText(r.step + 1)}), size: 10, weight: 700),
                      ),
                      Text('${(r.into * 100).floor()}%', style: BoltText.m(11, weight: 700, color: tierColor(r.tier))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: BoltColors.lineSoft),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: r.into.clamp(0.0, 1.0),
                            child: ColoredBox(color: tierColor(r.tier)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (r.step >= kAtlas) ...[
                  const SizedBox(height: 12),
                  Text(
                    tx('Atlas. Maybe once in a thousand years. There is nothing above this.'),
                    textAlign: TextAlign.center,
                    style: BoltText.a(14, weight: 800, color: BoltColors.neon, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          // What moves you up: one lift is enough.
          if (r.placed && r.step < kAtlas) ...[
            Section(
              tx('To {rank}', {'rank': rankText(r.step + 1)}),
              sub: options.isEmpty
                  ? tx('No single lift gets you there now: raise all three together.')
                  : tx('Any one of these gets you there:'),
            ),
            if (options.isNotEmpty)
              RowGroup(
                children: [
                  for (final (lift, add) in options)
                    LinkRow(
                      title: tx(lift),
                      trailing: Text(
                        _gain(r.lifts.firstWhere((l) => l.name == lift), add, kg, reps),
                        style: BoltText.m(12, weight: 700, color: BoltColors.rank),
                      ),
                    ),
                ],
              ),
          ],
          const SizedBox(height: 18),
          if (r.placed)
            NeonButton(
              label: tx('Share my rank'),
              height: 52,
              onTap: () async {
                final lifts = r.lifts
                    .map((l) => '${tx(l.name)} ${l.reps != null ? reps(l.reps!) : kg(l.maxKg)}')
                    .join(' · ');
                final hint = await shareMessage(
                  tx('I am {rank} in Bolt. {lifts}', {'rank': rankText(r.step), 'lifts': lifts}),
                  subject: tx('My Bolt rank'),
                );
                if (hint != null) store.toast(hint);
              },
            )
          else if (t.body.weightKg == null || t.body.sex == null)
            NeonButton(label: tx('Edit profile'), height: 52, onTap: () => context.push('/edit-profile'))
          else
            NeonButton(label: tx('Set your main lifts'), height: 52, onTap: () => context.push('/progress')),
          if (!r.placed) ...[
            const SizedBox(height: 12),
            Text(
              tx('Lifts that count: {lifts}.', {
                'lifts': [...kStandardLifts, ...kRepLifts].map(tx).join(', '),
              }),
              textAlign: TextAlign.center,
              style: BoltText.a(12, color: BoltColors.muted3, height: 1.4),
            ),
          ],
          if (r.placed) ...[
            Section(
              tx('What counts'),
              sub: tx(
                'Your best three main lifts for your bodyweight: a max you set, or your best set, days logged as done included.',
              ),
            ),
            RowGroup(
              children: [
                for (final l in r.lifts)
                  LinkRow(
                    onTap: () => context.push('/lift/${Uri.encodeComponent(l.name)}'),
                    lead: RankEmblem(step: stepOf(l.pos), size: 34),
                    title: tx(l.name),
                    sub: [
                      if (l.reps != null)
                        reps(l.reps!)
                      else ...[
                        kg(l.maxKg),
                        tx('{x} bodyweight', {'x': '${(l.maxKg / t.body.weightKg!).toStringAsFixed(2)}×'}),
                      ],
                      tx(kStrengthLevels[l.pos.floor().clamp(0, 4)]),
                      rankText(stepOf(l.pos)),
                    ].join(' · '),
                  ),
              ],
            ),
          ],
          Section(tx('How rank works')),
          Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (n, line) in [
                  (
                    1,
                    tx(
                      'Each main lift\'s best: a max you set, or your best set as a one-rep max, weight × (1 + reps ÷ 30). 100 kg for 5 is about 117 kg.',
                    ),
                  ),
                  (
                    2,
                    tx(
                      'That max divided by your bodyweight is placed on strength standards for your sex: Beginner, Novice, Intermediate, Advanced, Elite. On the bench that is {n}, {i}, {a} and {e} bodyweight for each step up.',
                      {'n': x(bench[0]), 'i': x(bench[1]), 'a': x(bench[2]), 'e': x(bench[3])},
                    ),
                  ),
                  (
                    3,
                    tx(
                      'Muscle-ups, pull-ups, chin-ups and dips count by your best set of reps instead, on the same scale.',
                    ),
                  ),
                  (
                    4,
                    tx(
                      'Each lift scores 0 to 6: 1 is Novice, 2 Intermediate, 3 Advanced, 4 Elite, and two more bands past Elite.',
                    ),
                  ),
                  (5, tx('Your best three lifts are averaged into your score.')),
                  (
                    6,
                    tx(
                      'Scores 0 to 5 climb Plastic I to Immortal III in 27 steps. 5 is Olympia, the greatest lifters there have been. 6 is Atlas: world-record strength on all three at once.',
                    ),
                  ),
                ]) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text('$n', style: BoltText.display(20, color: Tone.paper().accent)),
                      ),
                      Expanded(
                        child: Text(line, style: BoltText.a(13, color: BoltColors.paperSoft, height: 1.45)),
                      ),
                    ],
                  ),
                  if (n < 6) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Section(
            tx('The ladder'),
            sub: tx(
              'Everyone starts at Bodyweight. Plastic to Immortal have three divisions each. Olympia is for the greatest lifters there have been; Atlas is for a titan, maybe once in a thousand years. Levels count what you do, rank counts what you can lift.',
            ),
          ),
          BoltBox(
            color: BoltColors.surface1,
            radius: 20,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: LayoutBuilder(
              builder: (context, box) {
                // Four to a row, filling the width.
                final w = (box.maxWidth - 3 * 8) / 4;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    for (var tier = 0; tier < kTiers.length; tier++)
                      SizedBox(
                        width: w,
                        child: Opacity(
                          // Ranks still ahead stay faint, so none looks earned.
                          opacity: tier <= r.tier ? 1 : .3,
                          child: Column(
                            children: [
                              RankEmblem(step: _ladderStep(tier), size: 44),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  tx(kTiers[tier]),
                                  maxLines: 1,
                                  style: BoltText.a(
                                    11,
                                    weight: tier == r.tier ? 900 : 600,
                                    color: tier == r.tier && tier > 0 ? tierColor(tier) : BoltColors.textSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The color a rank's stage glows with: its tier, or the rank color for
/// Bodyweight, whose grey would read as switched off.
Color _stageColor(int tier) => tier == 0 ? BoltColors.rank : tierColor(tier);

/// What one option in the next-rank box adds: "+2.5 kg → 102.5 kg", or
/// "+2 → 10 reps" on a bodyweight lift.
String _gain(RankedLift l, double add, String Function(double) kg, String Function(int) reps) =>
    l.reps != null ? '+${add.round()} → ${reps(l.reps! + add.round())}' : '+${kg(add)} → ${kg(l.maxKg + add)}';

/// The step shown for [tier] on the ladder: its top division.
int _ladderStep(int tier) => tier == 0
    ? 0
    : tier == kTiers.length - 1
    ? kAtlas
    : tier == kTiers.length - 2
    ? kOlympia
    : tier * 3;
