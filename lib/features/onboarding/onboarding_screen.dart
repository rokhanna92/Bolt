import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bolt_store.dart';
import '../../data/licenses.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/people.dart';
import '../../data/seed/splits.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
import '../../widgets/motion.dart';
import '../../widgets/tap.dart';

/// First launch: how do you train, a license code for coaches, who are you,
/// and (optionally) your body.
/// Finishing creates the phone owner's profile; the router takes it from there.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  Role _role = Role.solo;
  bool _admin = false;
  String? _codeError;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _coach = TextEditingController();
  final _specialty = TextEditingController();
  final _gym = TextEditingController();
  String _goal = 'General fitness';
  String _split = 'ppl';
  bool _autoPlan = true;
  BodyForm? _body;

  @override
  void dispose() {
    for (final c in [_code, _name, _coach, _specialty, _gym]) {
      c.dispose();
    }
    _body?.dispose();
    super.dispose();
  }

  BodyForm get _bodyForm {
    final metric = ref.read(boltProvider).settings.kg;
    if (_body == null || _body!.metric != metric) {
      final old = _body?.read();
      _body?.dispose();
      _body = BodyForm(old ?? Body(), metric: metric);
    }
    return _body!;
  }

  void _finish({required bool withBody}) {
    ref
        .read(boltProvider.notifier)
        .createProfile(
          _role,
          ProfileInput(
            name: _name.text,
            goal: _goal,
            split: _split,
            coachName: _coach.text,
            specialty: _specialty.text,
            gym: _gym.text,
            body: withBody ? _bodyForm.read() : null,
          ),
          autoPlan: _role == Role.solo && _autoPlan,
          admin: _admin,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(boltProvider.select((d) => d.settings.kg));
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: BoltPage(
        child: ScreenScroll(
          top: _step == 0 ? 40 : 16,
          bottom: 40,
          children: [
            FadeSlideIn(
              key: ValueKey(_step),
              child: switch (_step) {
                0 => _roleStep(),
                1 => _codeStep(),
                2 => _aboutStep(),
                _ => _bodyStep(),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Steps: 0 role, 1 license code (coaches only), 2 about you, 3 body.
  void _back() => setState(() => _step = _step == 2 && _role != Role.coach ? 0 : _step - 1);

  Widget _header(String kicker, String title, {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            BackBox(onTap: _back),
            const SizedBox(width: 12),
            Kicker(kicker),
          ],
        ),
        const SizedBox(height: 16),
        Text(title, style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub, style: BoltText.a(13, color: BoltColors.muted, height: 1.45)),
        ],
      ],
    );
  }

  Widget _roleStep() {
    Widget option(Role role, String icon, String title, String desc) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tap(
        onTap: () => setState(() {
          _role = role;
          _admin = false;
          _step = role == Role.coach ? 1 : 2;
        }),
        scale: .98,
        child: BoltBox(
          color: BoltColors.surface1,
          stroke: const Stroke(BoltColors.lineSoft),
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BoltBox(
                width: 46,
                height: 46,
                radius: 14,
                stroke: const Stroke(BoltColors.neon, 1.5),
                alignment: Alignment.center,
                child: BoltIcon(icon, color: BoltColors.neon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: BoltText.a(16, weight: 800)),
                    const SizedBox(height: 3),
                    Text(desc, style: BoltText.a(12, color: BoltColors.muted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Chevron(),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('BOLT', style: BoltText.a(40, weight: 900, width: 125, spacing: .02, color: BoltColors.neon, height: 1)),
        const SizedBox(height: 6),
        Text('Plan it, lift it, log it.', style: BoltText.a(13, color: BoltColors.muted, height: 1.5)),
        const SizedBox(height: 28),
        const Kicker('HOW DO YOU TRAIN?'),
        const SizedBox(height: 10),
        option(Role.solo, 'barbell', 'On my own', 'Plan your own sessions, log workouts and track your gym time.'),
        option(
          Role.trainee,
          'kettlebell',
          'With a coach',
          'Follow the plan your coach sends you. Accept it, move days, log it.',
        ),
        option(
          Role.coach,
          'group',
          'I coach people',
          'Plan your trainees\' weeks and send each of them their plan. Needs a coach license code.',
        ),
        const SizedBox(height: 14),
        Text(
          'Everything you enter stays on this phone.',
          textAlign: TextAlign.center,
          style: BoltText.a(12, color: BoltColors.muted2),
        ),
      ],
    );
  }

  Widget _codeStep() {
    final ok = _code.text.trim().length >= 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          'COACH LICENSE',
          'Your coach code',
          sub: 'Coaching in Bolt needs a 5-digit license code. No code? Go back and train on your own or with a coach.',
        ),
        const FieldLabel('CODE', top: 22),
        BoltField(
          controller: _code,
          hint: '5-digit code',
          number: true,
          onChanged: (_) => setState(() => _codeError = null),
        ),
        if (_codeError != null) ...[
          const SizedBox(height: 8),
          Text(_codeError!, style: BoltText.a(13, weight: 600, color: BoltColors.warn)),
        ],
        const SizedBox(height: 22),
        NeonButton(
          label: 'Unlock',
          color: ok ? BoltColors.neon : BoltColors.line,
          textColor: ok ? BoltColors.ink : BoltColors.muted,
          onTap: ok ? _unlock : null,
        ),
      ],
    );
  }

  void _unlock() {
    final license = ref.read(licenseProvider)(_code.text);
    if (license == null) {
      setState(() => _codeError = 'That code is not valid. Check it and try again.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _admin = license == License.admin;
      _step = 2;
    });
  }

  Widget _aboutStep() {
    final coach = _role == Role.coach;
    final ok = _name.text.trim().isNotEmpty;
    final tpls = ref.read(boltProvider).tpls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(_admin ? 'ADMIN · STEP 1 OF 2' : 'STEP 1 OF 2', 'About you'),
        const FieldLabel('NAME', top: 22),
        BoltField(controller: _name, hint: 'Your name', words: true, onChanged: (_) => setState(() {})),
        if (coach) ...[
          const FieldLabel('SPECIALTY'),
          BoltField(controller: _specialty, hint: 'e.g. Strength & Hypertrophy (optional)'),
        ] else ...[
          const FieldLabel('GOAL'),
          ChoiceChips(options: kGoals, selected: _goal, onSelect: (g) => setState(() => _goal = g)),
          const FieldLabel('WEEKLY SPLIT'),
          SplitPicker(selected: _split, tpls: tpls, onSelect: (s) => setState(() => _split = s)),
        ],
        if (_role == Role.trainee) ...[
          const FieldLabel('YOUR COACH'),
          BoltField(controller: _coach, hint: 'Coach\'s name (optional)', words: true),
        ],
        const FieldLabel('GYM'),
        BoltField(controller: _gym, hint: 'Where you train (optional)', words: true),
        const SizedBox(height: 22),
        NeonButton(
          label: 'Continue',
          color: ok ? BoltColors.neon : BoltColors.line,
          textColor: ok ? BoltColors.ink : BoltColors.muted,
          onTap: ok
              ? () {
                  FocusScope.of(context).unfocus();
                  setState(() => _step = 3);
                }
              : null,
        ),
      ],
    );
  }

  Widget _bodyStep() {
    final store = ref.read(boltProvider.notifier);
    final metric = ref.read(boltProvider).settings.kg;
    final form = _bodyForm;
    Widget unitTab(String label, bool on) => Expanded(
      child: Tap(
        onTap: () {
          if (on != metric) store.toggleUnits();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on == metric ? BoltColors.neon : const Color(0x00C6FF1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on == metric ? BoltColors.neon : BoltColors.line),
          ),
          child: Text(
            label,
            style: BoltText.a(13, weight: 800, color: on == metric ? BoltColors.ink : BoltColors.text),
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          'STEP 2 OF 2',
          'Your body',
          sub: 'Optional. Add what you know to track progress. You can change it any time in your profile.',
        ),
        const SizedBox(height: 16),
        Row(children: [unitTab('kg · cm', true), const SizedBox(width: 6), unitTab('lb · in', false)]),
        const SizedBox(height: 14),
        BodyFields(key: ValueKey(metric), form: form),
        if (_role == Role.solo) ...[
          const SizedBox(height: 18),
          Tap(
            onTap: () => setState(() => _autoPlan = !_autoPlan),
            child: BoltBox(
              color: BoltColors.surface1,
              stroke: const Stroke(BoltColors.lineSoft),
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plan my next 3 weeks', style: BoltText.a(14, weight: 700)),
                        const SizedBox(height: 2),
                        Text('From your ${kSplits[_split]!.name}', style: BoltText.a(12, color: BoltColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  BoltSwitch(on: _autoPlan),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        NeonButton(
          label: _role == Role.coach ? 'Start coaching' : 'Start training',
          onTap: () => _finish(withBody: true),
        ),
        const SizedBox(height: 10),
        Center(
          child: Tap(
            onTap: () => _finish(withBody: false),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Skip for now', style: BoltText.a(13, weight: 700, color: BoltColors.muted)),
            ),
          ),
        ),
      ],
    );
  }
}
