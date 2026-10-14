import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/bolt_store.dart';
import '../../data/models/bolt_data.dart';
import '../../data/models/people.dart';
import '../../theme/text_styles.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';

/// Edits the phone owner's profile, or one of a coach's trainees.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, this.tid});

  /// A coach's trainee; null edits the owner.
  final String? tid;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final String _id = widget.tid ?? Account.ownerId;
  late final BoltStore _store = ref.read(boltProvider.notifier);
  late final Trainee? _trainee = _store.trOrNull(_id);
  late final Coach? _coach = _trainee == null ? _store.coOrNull(_id) : null;
  late final _name = TextEditingController(text: _trainee?.name ?? _coach?.name ?? '');
  late final _coachName = TextEditingController(text: _trainee?.coachName ?? '');
  late final _specialty = TextEditingController(text: _coach?.role ?? '');
  late final _gym = TextEditingController(text: ref.read(boltProvider).settings.gymName);
  late String _goal = _trainee?.goal ?? 'General fitness';
  late String _split = _trainee?.split ?? 'ppl';
  late final BodyForm _body = BodyForm(
    _trainee?.body ?? _coach?.body ?? Body(),
    metric: ref.read(boltProvider).settings.kg,
  );

  @override
  void dispose() {
    for (final c in [_name, _coachName, _specialty, _gym]) {
      c.dispose();
    }
    _body.dispose();
    super.dispose();
  }

  void _save() {
    final owner = _id == Account.ownerId;
    final role = ref.read(boltProvider).account?.role;
    _store.saveProfile(
      _id,
      ProfileInput(
        name: _name.text,
        goal: _trainee == null ? null : _goal,
        split: _trainee == null ? null : _split,
        coachName: owner && role == Role.trainee ? _coachName.text : null,
        specialty: _coach == null ? null : _specialty.text,
        gym: owner ? _gym.text : null,
        body: _body.read(),
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(boltProvider);
    final owner = _id == Account.ownerId;
    final insets = MediaQuery.paddingOf(context);
    final ok = _name.text.trim().isNotEmpty;
    if (_trainee == null && _coach == null) return const BoltPage(child: SizedBox.expand());
    return BoltPage(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BackBox(onTap: () => context.pop()),
                const SizedBox(width: 12),
                Text(owner ? 'Edit profile' : 'Edit trainee', style: BoltText.a(24, weight: 900)),
              ],
            ),
            const FieldLabel('NAME', top: 22),
            BoltField(controller: _name, hint: 'Name', words: true, onChanged: (_) => setState(() {})),
            if (_coach != null) ...[
              const FieldLabel('SPECIALTY'),
              BoltField(controller: _specialty, hint: 'e.g. Strength & Hypertrophy'),
            ],
            if (_trainee != null) ...[
              const FieldLabel('GOAL'),
              ChoiceChips(options: kGoals, selected: _goal, onSelect: (g) => setState(() => _goal = g)),
              const FieldLabel('WEEKLY SPLIT'),
              SplitPicker(selected: _split, tpls: d.tpls, onSelect: (s) => setState(() => _split = s)),
            ],
            if (owner && d.account?.role == Role.trainee) ...[
              const FieldLabel('YOUR COACH'),
              BoltField(controller: _coachName, hint: 'Coach\'s name', words: true),
            ],
            if (owner) ...[const FieldLabel('GYM'), BoltField(controller: _gym, hint: 'Where you train', words: true)],
            const FieldLabel('BODY'),
            BodyFields(form: _body),
            const SizedBox(height: 22),
            NeonButton(label: 'Save', onTap: ok ? _save : null),
          ],
        ),
      ),
    );
  }
}
