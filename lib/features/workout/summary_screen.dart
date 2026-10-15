import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/models/session.dart';
import '../../data/rules.dart';
import '../../data/seed/exercises.dart';
import '../../data/seed/muscles.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';

/// A finished workout as a card: time, sets, volume, PRs and muscles. Shown
/// after Finish and from a done day; can be shared as an image.
class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.dayKey});

  final String dayKey;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  final _card = GlobalKey();

  Future<void> _share(String title) async {
    final store = ref.read(boltProvider.notifier);
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bolt-workout-${widget.dayKey}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: title,
        ),
      );
    } catch (_) {
      store.toast(tx('Could not create the image'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final store = ref.read(boltProvider.notifier);
    final t = store.trOrNull(d.account?.id ?? '');
    final s = t == null ? null : store.plan(t.id)[widget.dayKey];
    if (t == null || s == null || s.status != SessionStatus.done) return const BoltPage(child: SizedBox.expand());
    final insets = MediaQuery.paddingOf(context);
    final metric = d.settings.kg;
    final sets = s.ex.fold(0, (a, e) => a + (e.logged.isNotEmpty ? e.logged.length : 0));
    final volume = s.ex.fold(0.0, (a, e) => a + e.logged.fold(0.0, (b, l) => b + (l.kg ?? 0) * (l.reps ?? 0)));
    final muscles = {
      for (final e in s.ex)
        if (kExerciseByName[e.name]?.muscle case final String m when kMuscles.containsKey(m)) m,
    };
    final title = tx(s.title);
    Widget stat(String v, String l) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: BoltText.a(24, weight: 900, color: BoltColors.ink)),
          Text(l, style: BoltText.m(9, weight: 700, spacing: .1, color: BoltColors.ink.withValues(alpha: .7))),
        ],
      ),
    );

    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 40 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Kicker(tx('WORKOUT DONE')),
              ],
            ),
            const SizedBox(height: 18),
            RepaintBoundary(
              key: _card,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: BoltColors.neon, borderRadius: BorderRadius.circular(26)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('BOLT', style: BoltText.a(18, weight: 900, width: 125, color: BoltColors.ink)),
                        const Spacer(),
                        Text(
                          fmtDay(widget.dayKey).toUpperCase(),
                          style: BoltText.m(11, weight: 700, color: BoltColors.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title.toUpperCase(),
                      style: BoltText.a(tsz(title, 44), weight: 900, width: 115, height: .95, color: BoltColors.ink),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        stat(s.took == null ? '-' : dur(s.took!), tx('TIME')),
                        stat('$sets', tx('SETS')),
                        stat(
                          volume == 0
                              ? '-'
                              : metric
                              ? '${(volume / 1000).toStringAsFixed(1)} t'
                              : '${(volume * 2.20462).round()} lb',
                          tx('LIFTED'),
                        ),
                      ],
                    ),
                    if (s.prs.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        tx('NEW PERSONAL RECORDS'),
                        style: BoltText.m(10, weight: 700, spacing: .1, color: BoltColors.ink),
                      ),
                      const SizedBox(height: 6),
                      for (final p in s.prs)
                        Text('★ ${tx(p)}', style: BoltText.a(16, weight: 800, color: BoltColors.ink)),
                    ],
                    if (muscles.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in muscles)
                            BoltBox(
                              radius: 99,
                              stroke: const Stroke(Color(0x800A0B09)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: Text(
                                tx(kMuscles[m]!.name).toUpperCase(),
                                style: BoltText.m(10, weight: 700, color: BoltColors.ink),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      logText(s.log),
                      style: BoltText.a(13, weight: 700, color: BoltColors.ink.withValues(alpha: .8)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            NeonButton(label: tx('Share'), height: 52, scale: 1, onTap: () => _share(title)),
            const SizedBox(height: 8),
            OutlineButton(
              label: tx('Done'),
              color: BoltColors.text,
              borderColor: BoltColors.line,
              weight: 700,
              onTap: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
