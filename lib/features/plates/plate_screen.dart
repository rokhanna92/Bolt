import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/bolt_store.dart';
import '../../data/plates.dart';
import '../../services/haptics.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
import '../../widgets/plate_bar.dart';
import '../workout/floor_view.dart' show FloorStepper;

/// Type a weight, pick the bar, see the plates for each side. Opens on
/// [kg] when a workout sends it.
class PlateScreen extends ConsumerStatefulWidget {
  const PlateScreen({super.key, this.kg});

  final double? kg;

  @override
  ConsumerState<PlateScreen> createState() => _PlateScreenState();
}

class _PlateScreenState extends ConsumerState<PlateScreen> {
  late final bool _metric = ref.read(boltProvider).settings.kg;

  /// Target in the chosen unit, kg or lb.
  late double _total = widget.kg == null ? (_metric ? 60 : 135) : (_metric ? widget.kg! : widget.kg! * 2.20462);
  late double _bar = _metric ? kBarsKg.first : kBarsLb.first;

  List<double> get _plates => _metric ? kPlatesKg : kPlatesLb;

  String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed((v * 2) % 1 == 0 ? 1 : 2);

  void _step(int dir) {
    final step = _metric ? 2.5 : 5.0;
    final q = _total / step;
    final n = (q - q.round()).abs() < 1e-6 ? q.round() + dir : (dir > 0 ? q.ceil() : q.floor());
    final next = n * step;
    if (next < _bar) return Haptics.play(Feel.error);
    final before = platesFor(_total, _bar, _plates).side.length;
    setState(() => _total = next);
    // A plate going on or coming off lands firmer than a plain step.
    Haptics.play(platesFor(next, _bar, _plates).side.length != before ? Feel.detent : Feel.tick);
  }

  Future<void> _type() async {
    final c = TextEditingController(text: _n(_total));
    await showBoltSheet<void>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(tx('WEIGHT'), size: 10),
          const SizedBox(height: 10),
          BoltField(controller: c, hint: tx('WEIGHT'), number: true, suffix: weightUnit(_metric), autofocus: true),
          const SizedBox(height: 14),
          NeonButton(
            label: tx('Save'),
            height: 52,
            scale: 1,
            onTap: () {
              final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
              if (v != null && v > 0) setState(() => _total = v);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unit = weightUnit(_metric);
    final insets = MediaQuery.paddingOf(context);
    final r = platesFor(_total, _bar, _plates);
    final loaded = _total - r.left;
    final bars = _metric ? kBarsKg : kBarsLb;
    return BoltPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('PLATES')),
            ],
          ),
          const SizedBox(height: 14),
          Text(tx('Plate calculator'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
          const SizedBox(height: 4),
          Text(
            tx('The weight on the bar, and the plates for each side.'),
            style: BoltText.a(13, color: BoltColors.muted),
          ),
          const SizedBox(height: 20),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FloorStepper(label: tx('ON THE BAR'), value: _n(_total), unit: unit, onStep: _step, onTapValue: _type),
                const SizedBox(height: 18),
                PlateBar(side: r.side, plates: _plates, height: 130),
                const SizedBox(height: 14),
                Kicker(tx('EACH SIDE'), size: 10),
                const SizedBox(height: 4),
                Text(
                  r.left < 0
                      ? tx('Lighter than the empty bar.')
                      : r.side.isEmpty
                      ? tx('Just the bar.')
                      : '${sideText(r.side)} $unit',
                  style: BoltText.a(22, weight: 900, color: BoltColors.neon),
                ),
                if (r.left > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    tx('These plates make {kg}, {left} short.', {
                      'kg': '${_n(loaded)} $unit',
                      'left': '${_n(r.left)} $unit',
                    }),
                    style: BoltText.a(12, color: BoltColors.warn),
                  ),
                ],
              ],
            ),
          ),
          FieldLabel(tx('BAR')),
          ChoiceChips(
            options: [for (final b in bars) _n(b)],
            labels: {for (final b in bars) _n(b): '${_n(b)} $unit'},
            selected: _n(_bar),
            onSelect: (v) => setState(() => _bar = double.parse(v)),
          ),
          const SizedBox(height: 8),
          Text(
            _metric
                ? tx('20 kg is the standard Olympic bar, 15 kg the women\'s bar, 10 kg a technique bar.')
                : tx('45 lb is the standard Olympic bar, 35 lb the women\'s bar, 15 lb a technique bar.'),
            style: BoltText.a(12, color: BoltColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
