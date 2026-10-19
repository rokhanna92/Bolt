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
      child: BoltBox(
        color: BoltColors.surface1,
        stroke: const Stroke(BoltColors.lineSoft),
        radius: 14,
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
        color: tier == kTiers.length - 1 ? Colors.white : tierColor(tier),
      ),
    );
    if (tier != kTiers.length - 1) return text;
    return ShaderMask(
      shaderCallback: (b) => const LinearGradient(colors: kAtlasNeon).createShader(b),
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
    final bench = standardsFor('Bench Press', t.body.sex == null ? (Body()..sex = 'm') : t.body)!;
    String x(double v) => '${v == v.roundToDouble() ? v.round() : v}×';

    return BoltPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('RANK')),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: PopIn(
              duration: const Duration(milliseconds: 500),
              child: RankEmblem(step: r.step, size: 170),
            ),
          ),
          const SizedBox(height: 10),
          RankName(step: r.step, size: 34, center: true),
          const SizedBox(height: 6),
          Text(
            !r.placed
                ? placeHint(t)
                : tx('Score {score} of {top}', {'score': r.score.toStringAsFixed(2), 'top': kAtlasScore.round()}),
            textAlign: TextAlign.center,
            style: BoltText.a(13, weight: 600, color: BoltColors.muted, height: 1.4),
          ),
          if (r.placed && r.step < kAtlas) ...[
            const SizedBox(height: 16),
            BoltBox(
              color: BoltColors.surface1,
              stroke: const Stroke(BoltColors.lineSoft),
              radius: 18,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 10),
                  Text(
                    options.isEmpty
                        ? tx('No single lift gets you there now: raise all three together.')
                        : tx('Any one of these gets you there:'),
                    style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
                  ),
                  for (final (lift, add) in options) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: Text(tx(lift), style: BoltText.a(14, weight: 700))),
                        Text(
                          '+${kg(add)} → ${kg(r.lifts.firstWhere((l) => l.name == lift).maxKg + add)}',
                          style: BoltText.m(12, weight: 700, color: BoltColors.neon),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (r.step >= kAtlas) ...[
            const SizedBox(height: 10),
            Text(
              tx('Atlas. Maybe once in a thousand years. There is nothing above this.'),
              textAlign: TextAlign.center,
              style: BoltText.a(14, weight: 800, color: BoltColors.neon, height: 1.4),
            ),
          ],
          const SizedBox(height: 18),
          if (r.placed)
            NeonButton(
              label: tx('Share my rank'),
              height: 52,
              onTap: () async {
                final lifts = r.lifts.map((l) => '${tx(l.name)} ${kg(l.maxKg)}').join(' · ');
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
              tx('Lifts that count: {lifts}.', {'lifts': kStandardLifts.map(tx).join(', ')}),
              textAlign: TextAlign.center,
              style: BoltText.a(12, color: BoltColors.muted3, height: 1.4),
            ),
          ],
          if (r.placed) ...[
            const SizedBox(height: 24),
            SectionTitle(tx('What counts')),
            const SizedBox(height: 4),
            Text(
              tx(
                'Your best three main lifts for your bodyweight: a max you set, or your best set, days logged as done included.',
              ),
              style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
            ),
            const SizedBox(height: 8),
            for (final l in r.lifts)
              Tap(
                onTap: () => context.push('/lift/${Uri.encodeComponent(l.name)}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: BoltColors.divider)),
                  ),
                  child: Row(
                    children: [
                      RankEmblem(step: stepOf(l.pos), size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx(l.name), style: BoltText.a(14, weight: 700)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                kg(l.maxKg),
                                tx('{x} bodyweight', {'x': '${(l.maxKg / t.body.weightKg!).toStringAsFixed(2)}×'}),
                                tx(kStrengthLevels[l.pos.floor().clamp(0, 4)]),
                                rankText(stepOf(l.pos)),
                              ].join(' · '),
                              style: BoltText.a(11, color: BoltColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const Chevron(size: 16),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          SectionTitle(tx('How rank works')),
          const SizedBox(height: 8),
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
                'Each lift scores 0 to 6: 1 is Novice, 2 Intermediate, 3 Advanced, 4 Elite, and two more bands past Elite.',
              ),
            ),
            (4, tx('Your best three lifts are averaged into your score.')),
            (
              5,
              tx(
                'Scores 0 to 5 climb Plastic I to Immortal III in 27 steps. 5 is Olympia, the greatest lifters there have been. 6 is Atlas: world-record strength on all three at once.',
              ),
            ),
          ]) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text('$n', style: BoltText.m(13, weight: 700, color: BoltColors.neon)),
                ),
                Expanded(child: Text(line, style: BoltText.a(13, height: 1.45))),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          SectionTitle(tx('The ladder')),
          const SizedBox(height: 4),
          Text(
            tx(
              'Everyone starts at Bodyweight. Plastic to Immortal have three divisions each. Olympia is for the greatest lifters there have been; Atlas is for a titan, maybe once in a thousand years. Levels count what you do, rank counts what you can lift.',
            ),
            style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
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
                        opacity: tier <= r.tier ? 1 : .45,
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
                                  color: tier == r.tier ? tierColor(tier) : BoltColors.textSoft,
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
        ],
      ),
    );
  }
}

/// The step shown for [tier] on the ladder: its top division.
int _ladderStep(int tier) => tier == 0
    ? 0
    : tier == kTiers.length - 1
    ? kAtlas
    : tier == kTiers.length - 2
    ? kOlympia
    : tier * 3;
