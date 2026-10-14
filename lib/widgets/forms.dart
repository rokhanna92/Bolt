import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/units.dart';
import '../data/models/people.dart';
import '../data/models/template.dart';
import '../data/seed/splits.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'box.dart';
import 'common.dart';
import 'fields.dart';
import 'tap.dart';

const kGoals = ['Strength', 'Hypertrophy', 'Fat loss', 'Conditioning', 'General fitness', 'Return to sport'];

/// Small mono label above a form field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.top = 18});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8),
    child: Kicker(text, size: 10),
  );
}

/// Single-choice pill chips (neon when picked).
class ChoiceChips extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.selected, required this.onSelect, this.labels});

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  /// Display text per option; defaults to the option itself.
  final Map<String, String>? labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in options)
          Tap(
            onTap: () => onSelect(o),
            child: BoltBox(
              radius: 99,
              color: o == selected ? BoltColors.neon : BoltColors.surface2,
              stroke: Stroke(o == selected ? BoltColors.neon : BoltColors.line),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                labels?[o] ?? o,
                style: BoltText.a(13, weight: 700, color: o == selected ? BoltColors.ink : BoltColors.text),
              ),
            ),
          ),
      ],
    );
  }
}

/// Weekly split cards with a 7-day preview, like the Library.
class SplitPicker extends StatelessWidget {
  const SplitPicker({super.key, required this.selected, required this.onSelect, required this.tpls});

  final String selected;
  final ValueChanged<String> onSelect;
  final Map<String, WorkoutTemplate> tpls;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final k in kSplitOrder) ...[
          Tap(
            onTap: () => onSelect(k),
            child: BoltBox(
              color: BoltColors.surface1,
              stroke: Stroke(k == selected ? BoltColors.neon : BoltColors.lineSoft, k == selected ? 1.5 : 1),
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(kSplits[k]!.name, style: BoltText.a(14, weight: 800))),
                      if (k == selected) Text('✓', style: BoltText.a(14, weight: 800, color: BoltColors.neon)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _week(k),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _week(String k) {
    final byDay = {for (final d in kSplits[k]!.days) d.weekday: d.tpl};
    return Row(
      children: [
        for (final (i, wd) in const [1, 2, 3, 4, 5, 6, 0].indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: BoltBox(
              height: 40,
              borderBox: true,
              radius: 9,
              color: byDay[wd] != null ? BoltColors.surface2 : Colors.transparent,
              stroke: byDay[wd] != null ? const Stroke(BoltColors.line) : const Stroke.dashed(BoltColors.lineFaint),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(weekdays[wd][0], style: BoltText.m(8, color: BoltColors.muted3)),
                  const SizedBox(height: 1),
                  Text(
                    byDay[wd] == null ? '' : tpls[byDay[wd]]?.code ?? '',
                    style: BoltText.m(8, weight: 700, color: BoltColors.neon),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Inputs for weight, height and tape measurements in the current unit.
class BodyForm {
  BodyForm(Body body, {required this.metric})
    : weight = TextEditingController(text: weightValue(body.weightKg, metric: metric)),
      height = TextEditingController(text: lengthValue(body.heightCm, metric: metric)),
      parts = {
        for (final p in Body.parts.keys) p: TextEditingController(text: lengthValue(body.cm[p], metric: metric)),
      };

  final bool metric;
  final TextEditingController weight;
  final TextEditingController height;
  final Map<String, TextEditingController> parts;

  Body read() {
    final cm = <String, double>{};
    parts.forEach((k, c) {
      final v = parseLength(c.text, metric: metric);
      if (v != null) cm[k] = v;
    });
    return Body(
      weightKg: parseWeight(weight.text, metric: metric),
      heightCm: parseLength(height.text, metric: metric),
      cm: cm,
    );
  }

  void dispose() {
    for (final c in [weight, height, ...parts.values]) {
      c.dispose();
    }
  }
}

/// The fields for a [BodyForm]: weight and height, then measurements in two
/// columns.
class BodyFields extends StatelessWidget {
  const BodyFields({super.key, required this.form});

  final BodyForm form;

  @override
  Widget build(BuildContext context) {
    final m = form.metric;
    Widget field(TextEditingController c, String hint, String unit) =>
        BoltField(controller: c, hint: '$hint ($unit)', number: true, suffix: unit);
    final keys = Body.parts.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: field(form.weight, 'Weight', weightUnit(m))),
            const SizedBox(width: 8),
            Expanded(child: field(form.height, 'Height', lengthUnit(m))),
          ],
        ),
        const FieldLabel('MEASUREMENTS'),
        for (var i = 0; i < keys.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: field(form.parts[keys[i]]!, Body.parts[keys[i]]!, lengthUnit(m))),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < keys.length
                    ? field(form.parts[keys[i + 1]]!, Body.parts[keys[i + 1]]!, lengthUnit(m))
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
