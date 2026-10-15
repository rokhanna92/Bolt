import 'package:flutter/material.dart' hide Split;

import '../core/format.dart';
import '../core/units.dart';
import '../data/models/bolt_data.dart';
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
                tx(labels?[o] ?? o),
                style: BoltText.a(13, weight: 700, color: o == selected ? BoltColors.ink : BoltColors.text),
              ),
            ),
          ),
      ],
    );
  }
}

/// Weekly split cards with a 7-day preview, like the Library: the built-in
/// splits, then the owner's own.
class SplitPicker extends StatelessWidget {
  const SplitPicker({super.key, required this.selected, required this.onSelect, required this.data, this.onEdit});

  final String selected;
  final ValueChanged<String> onSelect;
  final BoltData data;

  /// Shows "Edit" on custom splits.
  final ValueChanged<String>? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final k in splitIds(data)) ...[
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
                      Expanded(child: Text(tx(splitOf(data, k).name), style: BoltText.a(14, weight: 800))),
                      if (onEdit != null && data.splits.containsKey(k))
                        Tap(
                          onTap: () => onEdit!(k),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Text(tx('Edit'), style: BoltText.a(12, weight: 800, color: BoltColors.neon)),
                          ),
                        ),
                      if (k == selected) Text('✓', style: BoltText.a(14, weight: 800, color: BoltColors.neon)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SplitWeek(split: splitOf(data, k), tpls: data.tpls),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Monday to Sunday with each training day's workout code.
class SplitWeek extends StatelessWidget {
  const SplitWeek({super.key, required this.split, required this.tpls});

  final Split split;
  final Map<String, WorkoutTemplate> tpls;

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final d in split.days) d.weekday: d.tpl};
    return Row(
      children: [
        for (final (i, wd) in kWeekOrder.indexed) ...[
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
                  Text(weekdays[wd % 7][0], style: BoltText.m(8, color: BoltColors.muted3)),
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
    : sex = body.sex,
      weight = TextEditingController(text: weightValue(body.weightKg, metric: metric)),
      height = TextEditingController(text: lengthValue(body.heightCm, metric: metric)),
      parts = {
        for (final p in Body.parts.keys) p: TextEditingController(text: lengthValue(body.cm[p], metric: metric)),
      };

  final bool metric;

  /// `m`, `f` or null.
  String? sex;
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
      sex: sex,
      cm: cm,
    );
  }

  void dispose() {
    for (final c in [weight, height, ...parts.values]) {
      c.dispose();
    }
  }
}

/// The fields for a [BodyForm]: male or female, weight and height, then
/// measurements in two columns.
class BodyFields extends StatefulWidget {
  const BodyFields({super.key, required this.form});

  final BodyForm form;

  @override
  State<BodyFields> createState() => _BodyFieldsState();
}

class _BodyFieldsState extends State<BodyFields> {
  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final m = form.metric;
    Widget field(TextEditingController c, String hint, String unit) =>
        BoltField(controller: c, hint: '${tx(hint)} ($unit)', number: true, suffix: unit);
    final keys = Body.parts.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceChips(
          options: const ['m', 'f'],
          labels: const {'m': 'Male', 'f': 'Female'},
          selected: form.sex,
          onSelect: (s) => setState(() => form.sex = form.sex == s ? null : s),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: field(form.weight, 'Weight', weightUnit(m))),
            const SizedBox(width: 8),
            Expanded(child: field(form.height, 'Height', lengthUnit(m))),
          ],
        ),
        FieldLabel(tx('MEASUREMENTS')),
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
