import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/share.dart';
import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../data/rank.dart';
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
                  Text(rankText(r.step), style: BoltText.a(17, weight: 900, color: tierColor(r.tier))),
                  const SizedBox(height: 6),
                  if (r.placed && r.step < kRankSteps - 1)
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
                    Text(tx('Log a main lift to get placed'), style: BoltText.a(11, color: BoltColors.muted)),
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

/// The rank in full: what counts, what the next division takes, the ladder,
/// and a line to share.
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
    final next = nextStep(r, t.body);
    final insets = MediaQuery.paddingOf(context);
    String kg(double v) => fmtWeight(v, metric: metric);

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
          Text(
            rankText(r.step),
            textAlign: TextAlign.center,
            style: BoltText.a(34, weight: 900, width: 112, color: tierColor(r.tier)),
          ),
          const SizedBox(height: 6),
          Text(
            !r.placed
                ? placeHint(t)
                : next == null
                ? tx('The top of the ladder. Few lifters ever get here.')
                : tx('Next: {rank} · +{kg} on {lift}', {
                    'rank': rankText(r.step + 1),
                    'kg': kg(next.$2),
                    'lift': tx(next.$1),
                  }),
            textAlign: TextAlign.center,
            style: BoltText.a(13, weight: 600, color: BoltColors.muted, height: 1.4),
          ),
          if (r.placed && r.step < kRankSteps - 1) ...[
            const SizedBox(height: 14),
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
          else
            NeonButton(label: tx('Set your main lifts'), height: 52, onTap: () => context.push('/progress')),
          if (r.placed) ...[
            const SizedBox(height: 24),
            SectionTitle(tx('What counts')),
            const SizedBox(height: 4),
            Text(
              tx('Your best three main lifts for your bodyweight: a max you set, or your best logged set.'),
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
                      RankEmblem(step: _stepOf(l.pos), size: 34),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tx(l.name), style: BoltText.a(14, weight: 700)),
                            const SizedBox(height: 2),
                            Text(
                              '${kg(l.maxKg)} · ${rankText(_stepOf(l.pos))}',
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
          SectionTitle(tx('The ladder')),
          const SizedBox(height: 4),
          Text(
            tx(
              'Everyone starts at Bodyweight. Plastic to Immortal have three divisions each; Olympia is the top. Levels count what you do, rank counts what you can lift.',
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
                            RankEmblem(
                              step: tier == 0 ? 0 : (tier == kTiers.length - 1 ? kRankSteps - 1 : tier * 3),
                              size: 44,
                            ),
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

/// The step one lift alone would rank at.
int _stepOf(double pos) => pos >= 5 ? kRankSteps - 1 : 1 + (pos / 5 * 27).floor();
