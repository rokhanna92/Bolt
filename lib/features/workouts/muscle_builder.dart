import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

import '../../data/rules.dart';
import '../../data/seed/muscles.dart';
import '../../data/seed/templates.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/tap.dart';

/// What the muscle builder hands back.
class MuscleBuild {
  const MuscleBuild(this.muscles, this.ex, {required this.save});

  final List<String> muscles;
  final List<ExSeed> ex;

  /// Also keep it in the Library as a template.
  final bool save;
}

/// Pick the muscles to train; Bolt picks the exercises. Shuffle for others,
/// drop any you do not want. Pops with a [MuscleBuild].
class MuscleBuilderSheet extends StatefulWidget {
  const MuscleBuilderSheet({super.key, this.libraryOnly = false, this.forName});

  /// Built from the Library: always saved as a template.
  final bool libraryOnly;

  /// Whose day this is, for a coach: "for Ana".
  final String? forName;

  @override
  State<MuscleBuilderSheet> createState() => _MuscleBuilderSheetState();
}

class _MuscleBuilderSheetState extends State<MuscleBuilderSheet> {
  final _rnd = math.Random();
  final _muscles = <String>[];
  var _ex = <ExSeed>[];
  var _save = false;

  void _build() => setState(() => _ex = workoutForMuscles(_muscles, _rnd));

  void _toggle(String m) {
    _muscles.contains(m) ? _muscles.remove(m) : _muscles.add(m);
    _build();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _muscles.isNotEmpty && _ex.isNotEmpty;
    final sets = _ex.fold(0, (a, e) => a + e.sets);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Build from muscles'), style: BoltText.a(20, weight: 900)),
        const SizedBox(height: 4),
        Text(
          widget.forName == null
              ? tx('Tap the muscles to train, in the order you want them. Bolt puts the big lifts first.')
              : tx('Tap the muscles {name} should train, in the order you want them. Bolt puts the big lifts first.', {
                  'name': widget.forName,
                }),
          style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in kMuscles.entries)
              Tap(
                onTap: () => _toggle(e.key),
                child: BoltBox(
                  radius: 99,
                  color: _muscles.contains(e.key) ? BoltColors.neon : BoltColors.surface2,
                  stroke: Stroke(_muscles.contains(e.key) ? BoltColors.neon : BoltColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    _muscles.contains(e.key) ? '${_muscles.indexOf(e.key) + 1}  ${tx(e.value.name)}' : tx(e.value.name),
                    style: BoltText.a(
                      13,
                      weight: 700,
                      color: _muscles.contains(e.key) ? BoltColors.ink : BoltColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (_muscles.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musclesTitle(_muscles).toUpperCase(),
                      style: BoltText.a(18, weight: 900, color: BoltColors.neon),
                    ),
                    const SizedBox(height: 2),
                    Kicker(
                      '${plural(_ex.length, 'exercise')} · ${plural(sets, 'set')} · ~${(sets * 3).clamp(20, 120)} MIN'
                          .toUpperCase(),
                      size: 9,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Tap(
                onTap: _build,
                child: BoltBox(
                  radius: 10,
                  stroke: const Stroke(BoltColors.line),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(tx('Shuffle'), style: BoltText.a(12, weight: 800, color: BoltColors.neon)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _ex.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: BoltColors.divider)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Text('${i + 1}'.padLeft(2, '0'), style: BoltText.m(11, color: BoltColors.muted3)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_ex[i].name, style: BoltText.a(14, weight: 700))),
                  Text('${_ex[i].sets} × ${_ex[i].reps}', style: BoltText.m(11, color: BoltColors.muted)),
                  Tap(onTap: () => setState(() => _ex = [..._ex]..removeAt(i)), child: const CloseGlyph()),
                ],
              ),
            ),
          if (!widget.libraryOnly) ...[
            const SizedBox(height: 10),
            Tap(
              onTap: () => setState(() => _save = !_save),
              child: Row(
                children: [
                  BoltBox(
                    width: 22,
                    height: 22,
                    radius: 6,
                    color: _save ? BoltColors.neon : Colors.transparent,
                    stroke: Stroke(_save ? BoltColors.neon : BoltColors.line, 1.5),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tx('Also save it to the Library to reuse and put in splits'),
                      style: BoltText.a(13, weight: 600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        NeonButton(
          label: widget.libraryOnly ? tx('Save to Library') : tx('Use this workout'),
          height: 52,
          scale: 1,
          color: ok ? BoltColors.neon : BoltColors.line,
          textColor: ok ? BoltColors.ink : BoltColors.muted,
          onTap: ok
              ? () => Navigator.of(context).pop(MuscleBuild([..._muscles], _ex, save: widget.libraryOnly || _save))
              : null,
        ),
      ],
    );
  }
}
