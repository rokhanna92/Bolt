import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/models/people.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// "Body" section: weight, height and measurements with Progress and Edit
/// links.
class BodyCard extends ConsumerWidget {
  const BodyCard({
    super.key,
    required this.body,
    required this.onEdit,
    required this.onProgress,
    this.empty,
    this.titleSize = 17,
  });

  final Body body;
  final VoidCallback onEdit;

  /// Opens the measurements page with the history and trends.
  final VoidCallback onProgress;

  /// Shown when nothing is recorded yet.
  final String? empty;
  final double titleSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metric = ref.watch(boltProvider.select((d) => d.settings.kg));
    final items = <(String, String)>[
      if (body.sex != null) (tx('SEX'), tx(body.sex == 'f' ? 'Female' : 'Male')),
      if (body.weightKg != null) (tx('WEIGHT'), fmtWeight(body.weightKg!, metric: metric)),
      if (body.heightCm != null) (tx('HEIGHT'), fmtLength(body.heightCm!, metric: metric)),
      for (final e in Body.parts.entries)
        if (body.cm[e.key] != null) (tx(e.value).toUpperCase(), fmtLength(body.cm[e.key]!, metric: metric)),
    ];
    final updated = body.updated;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle(tx('Body'), size: titleSize)),
            if (body.history.isNotEmpty) ...[
              Tap(
                onTap: onProgress,
                child: Text(tx('Progress'), style: BoltText.a(13, weight: 700, color: BoltColors.neon)),
              ),
              const SizedBox(width: 16),
            ],
            Tap(
              onTap: onEdit,
              child: Text(
                items.isEmpty ? tx('+ Add') : tx('Edit'),
                style: BoltText.a(13, weight: 700, color: BoltColors.neon),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Tap(
            onTap: onEdit,
            child: BoltBox(
              radius: 14,
              stroke: const Stroke.dashed(BoltColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                empty ?? tx('Add your weight and measurements to track progress.'),
                style: BoltText.a(13, color: BoltColors.muted),
              ),
            ),
          )
        else
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var r = 0; r < items.length; r += 3) ...[
                  if (r > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = r; i < r + 3; i++)
                        Expanded(
                          child: i < items.length
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Kicker(items[i].$1, size: 9, spacing: .1),
                                    const SizedBox(height: 3),
                                    Text(items[i].$2, style: BoltText.a(16, weight: 800)),
                                  ],
                                )
                              : const SizedBox(),
                        ),
                    ],
                  ),
                ],
                if (updated != null) ...[
                  const SizedBox(height: 12),
                  Tap(
                    onTap: onProgress,
                    child: Row(
                      children: [
                        Expanded(
                          child: Kicker(
                            tx('UPDATED {day}', {'day': fmtDay(updated).toUpperCase()}),
                            size: 9,
                            color: BoltColors.muted3,
                          ),
                        ),
                        Text(tx('+ Log · history ›'), style: BoltText.a(12, weight: 700, color: BoltColors.neon)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
