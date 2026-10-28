import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/bolt_store.dart';
import '../../data/licenses.dart';
import '../../data/models/board.dart';
import '../../services/haptics.dart';
import '../../services/notice_board.dart';
import '../../theme/text_styles.dart';
import '../../theme/tokens.dart';
import '../../widgets/bolt_sheet.dart';
import '../../widgets/box.dart';
import '../../widgets/common.dart';
import '../../widgets/fields.dart';
import '../../widgets/forms.dart';
import '../../widgets/tap.dart';
import '../../widgets/time_wheel.dart';

const _audiences = {'all': 'Everyone', 'solo': 'Solo', 'clients': 'Clients', 'coaches': 'Coaches'};

/// "Every day · 18:00", "Mon, Wed · 07:30", "Once · Tue 20 Oct · 18:00".
String whenText(Push p) {
  final time = fromMin(p.at);
  if (p.date != null) return '${tx('Once')} · ${fmtDay(p.date!)} · $time';
  if (p.days.isEmpty) return '${tx('Every day')} · $time';
  final names = [
    for (final d in [...p.days]..sort()) weekdays[d % 7],
  ];
  return '${names.join(', ')} · $time';
}

/// The app owner's control over notifications on every phone: when the
/// built-in reminders go out and their own pushes, with what they say and
/// who gets them. Published to notices.json in Bolt's repo; phones read it
/// when Bolt opens and then remind on time even while closed.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late Board _draft = ref.read(boltProvider).settings.board.copy();
  late String _published = jsonEncode(_draft.toJson());
  String? _token;
  bool _loaded = false;
  bool _busy = false;

  NoticeBoard get _board => ref.read(noticeBoardProvider);
  bool get _dirty => jsonEncode(_draft.toJson()) != _published;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Starts from what is published now, in case it changed elsewhere.
  Future<void> _load() async {
    final (remote, token) = await (_board.fetch(), _board.token()).wait;
    if (!mounted) return;
    setState(() {
      if (remote != null) {
        _draft = remote;
        _published = jsonEncode(remote.toJson());
      }
      _token = token;
      _loaded = true;
    });
  }

  Future<void> _publish() async {
    final store = ref.read(boltProvider.notifier);
    final token = _token ?? await _askToken();
    if (token == null || !mounted) return;
    setState(() => _busy = true);
    final error = await _board.publish(_draft, token);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      Haptics.play(Feel.success);
      _published = jsonEncode(_draft.toJson());
      store.applyBoard(_draft.copy());
      store.toast(tx('Published. Phones pick it up when Bolt opens.'));
      setState(() {});
    } else {
      Haptics.play(Feel.error);
      store.toast(switch (error) {
        'token' => tx('GitHub said no. Check the token can write to the Bolt repo.'),
        'offline' => tx('No connection. Try again online.'),
        _ => tx('GitHub did not take it. Try again.'),
      });
    }
  }

  Future<String?> _askToken() async {
    final t = await askText(
      context,
      title: tx('GitHub token'),
      help: tx(
        'Publishing writes notices.json in the Bolt repo. Make a fine-grained token on GitHub with Contents read and write for the Bolt repo only, and paste it here. It stays on this phone, outside backups.',
      ),
      hint: 'github_pat_…',
      save: tx('Save'),
      initial: _token ?? '',
      clear: _token == null ? null : tx('Remove the token'),
    );
    if (t == null) return null;
    await _board.saveToken(t);
    if (mounted) setState(() => _token = t.isEmpty ? null : t);
    return t.isEmpty ? null : t;
  }

  Future<void> _pickSpan(String title, int current, List<int> options, ValueChanged<int> onPick) async {
    final v = await showBoltSheet<int>(
      context,
      (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: BoltText.a(20, weight: 900)),
          const SizedBox(height: 12),
          ChoiceChips(
            options: [for (final o in options) '$o'],
            labels: {for (final o in options) '$o': spanText(o)},
            selected: '$current',
            onSelect: (o) => Navigator.of(context).pop(int.parse(o)),
          ),
        ],
      ),
    );
    if (v != null) setState(() => onPick(v));
  }

  Future<void> _edit(Push? p) async {
    final store = ref.read(boltProvider.notifier);
    final draft = p?.copy() ?? Push(id: math.Random().nextInt(1 << 32).toRadixString(36), title: '', body: '');
    final out = await showBoltSheet<Push?>(
      context,
      (_) => _PushSheet(
        push: draft,
        isNew: p == null,
        today: store.now,
        onTest: (x) => ref
            .read(notificationsProvider)
            .showNow(
              isSerbian && x.titleSr.isNotEmpty ? x.titleSr : x.title,
              isSerbian && x.bodySr.isNotEmpty ? x.bodySr : x.body,
            ),
      ),
      maxHeight: .92,
    );
    if (out == null) return;
    setState(() {
      final i = _draft.pushes.indexWhere((x) => x.id == draft.id);
      // An empty title is how the sheet says "delete".
      if (out.title.trim().isEmpty) {
        if (i >= 0) _draft.pushes.removeAt(i);
      } else if (i >= 0) {
        _draft.pushes[i] = out;
      } else {
        _draft.pushes.add(out);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final t = _draft.times;
    Widget row(String label, String value, VoidCallback onTap, {String? sub}) => Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: BoltColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: BoltText.a(14, weight: 700)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: BoltText.a(12, color: BoltColors.muted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('$value ›', style: BoltText.m(13, weight: 700, color: BoltColors.neon)),
          ],
        ),
      ),
    );

    return BoltPage(
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, insets.top + 16, 20, 60 + insets.bottom),
        children: [
          Row(
            children: [
              BackBox(onTap: () => context.pop()),
              const SizedBox(width: 12),
              Kicker(tx('ADMIN')),
            ],
          ),
          const SizedBox(height: 14),
          Text(tx('Push notifications'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
          const SizedBox(height: 6),
          Text(
            tx(
              'What you set here goes to every phone with Bolt. Phones pick it up the next time Bolt opens, then remind on time even while closed.',
            ),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
          ),
          if (!_loaded) ...[
            const SizedBox(height: 10),
            Text(tx('Loading what is published…'), style: BoltText.a(12, color: BoltColors.muted3)),
          ],
          const SizedBox(height: 22),
          Kicker(tx('BUILT-IN REMINDERS'), size: 10),
          const SizedBox(height: 8),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 18,
            clip: true,
            child: Column(
              children: [
                row(tx('Morning brief'), fromMin(t.brief), () async {
                  final v = await pickTime(context, t.brief, title: tx('Morning brief'));
                  if (v != null) setState(() => t.brief = v);
                }, sub: tx('Training days: the workout and what to beat')),
                row(tx('Days-off nudge'), fromMin(t.nudge), () async {
                  final v = await pickTime(context, t.nudge, title: tx('Days-off nudge'));
                  if (v != null) setState(() => t.nudge = v);
                }, sub: tx('After 3 or more days without training')),
                row(
                  tx('Session reminder'),
                  tx('{time} before', {'time': spanText(t.before)}),
                  () => _pickSpan(tx('Session reminder'), t.before, const [30, 60, 90, 120, 180], (v) => t.before = v),
                  sub: tx('Before the usual check-in time on planned days'),
                ),
                row(
                  tx('Check-out reminder'),
                  tx('after {time}', {'time': spanText(t.checkout)}),
                  () => _pickSpan(tx('Check-out reminder'), t.checkout, const [
                    90,
                    120,
                    150,
                    180,
                    240,
                  ], (v) => t.checkout = v),
                  sub: tx('When someone is still checked in'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Kicker(tx('YOUR PUSHES'), size: 10)),
              Tap(
                onTap: () => _edit(null),
                child: Text(tx('+ New push'), style: BoltText.a(13, weight: 800, color: BoltColors.neon)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_draft.pushes.isEmpty)
            Text(
              tx(
                'None yet. A push can go out once or repeat on chosen days, to everyone or only solo users, clients or coaches.',
              ),
              style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
            ),
          for (final p in _draft.pushes) ...[
            Tap(
              onTap: () => _edit(p),
              child: BoltBox(
                color: BoltColors.surface1,
                stroke: const Stroke(BoltColors.lineSoft),
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Kicker(
                      '${whenText(p)} · ${tx(_audiences[p.to]!)}'.toUpperCase(),
                      size: 9,
                      spacing: .1,
                      color: BoltColors.neon,
                    ),
                    const SizedBox(height: 4),
                    Text(p.title, style: BoltText.a(15, weight: 800)),
                    if (p.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(p.body, style: BoltText.a(12, color: BoltColors.muted, height: 1.35)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          NeonButton(
            label: _busy ? tx('Publishing…') : (_dirty ? tx('Publish to every phone') : tx('Published')),
            height: 54,
            color: _dirty ? BoltColors.neon : BoltColors.surface2,
            textColor: _dirty ? BoltColors.ink : BoltColors.muted,
            onTap: _busy || !_dirty ? null : _publish,
          ),
          const SizedBox(height: 8),
          OutlineButton(
            label: tx('Copy as JSON'),
            color: BoltColors.text,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(_draft.toJson())));
              ref.read(boltProvider.notifier).toast(tx('Copied · paste it into notices.json on GitHub'));
            },
          ),
          const SizedBox(height: 18),
          BoltBox(
            color: BoltColors.surface1,
            stroke: const Stroke(BoltColors.lineSoft),
            radius: 18,
            clip: true,
            child: row(tx('GitHub token'), _token == null ? tx('Not set') : tx('On this phone'), _askToken),
          ),
          const SizedBox(height: 28),
          Text(tx('Keys'), style: BoltText.a(30, weight: 900, width: 112, spacing: -.02)),
          const SizedBox(height: 6),
          Text(
            tx(
              'A coach key opens Bolt only once you switch it on here. Until then that phone sees a screen saying its key is waiting for you.',
            ),
            style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          Kicker(tx('COACH KEYS'), size: 10),
          const SizedBox(height: 8),
          _keySwitches(),
          const SizedBox(height: 22),
          Kicker(tx('KEY LOG'), size: 10),
          const SizedBox(height: 8),
          _keyLog(),
        ],
      ),
    );
  }

  /// The owner's five coach keys, numbered as on their own list.
  Widget _keySwitches() {
    final on = ref.watch(boltProvider).settings.coachKeysOn;
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      clip: true,
      child: Column(
        children: [
          for (var i = 0; i < kCoachKeys; i++)
            Tap(
              onTap: () => ref.read(boltProvider.notifier).toggleCoachKey(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: BoltColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx('Coach {n}', {'n': i + 1}), style: BoltText.a(14, weight: 700)),
                          const SizedBox(height: 2),
                          Text(
                            on.contains(i) ? tx('Opens Bolt') : tx('Waiting for you'),
                            style: BoltText.a(12, color: on.contains(i) ? BoltColors.neon : BoltColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    BoltSwitch(on: on.contains(i)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Every go at the key screen, newest first: who, when, how it went.
  Widget _keyLog() {
    final log = ref.watch(boltProvider).settings.keyLog;
    if (log.isEmpty) {
      return Text(
        tx('Nothing yet. Every go at the key screen shows up here, refused ones included.'),
        style: BoltText.a(13, color: BoltColors.muted, height: 1.45),
      );
    }
    return BoltBox(
      color: BoltColors.surface1,
      stroke: const Stroke(BoltColors.lineSoft),
      radius: 18,
      clip: true,
      child: Column(
        children: [
          for (final e in log.reversed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: BoltColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(tx(e.name), style: BoltText.a(14, weight: 700))),
                  Text('${dayMonth(e.at)} · ${hm(e.at)}', style: BoltText.m(12, color: BoltColors.muted)),
                  const SizedBox(width: 10),
                  Text(
                    switch (e.how) {
                      'ok' => tx('opened'),
                      'pending' => tx('waiting'),
                      _ => tx('refused'),
                    },
                    style: BoltText.m(
                      12,
                      weight: 700,
                      color: switch (e.how) {
                        'ok' => BoltColors.neon,
                        'pending' => BoltColors.muted2,
                        _ => BoltColors.warn,
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Writes one push: its text in English and Serbian, when it goes out and
/// to whom. Pops the push, or one with an empty title to delete it.
class _PushSheet extends StatefulWidget {
  const _PushSheet({required this.push, required this.isNew, required this.today, required this.onTest});

  final Push push;
  final bool isNew;
  final DateTime today;
  final ValueChanged<Push> onTest;

  @override
  State<_PushSheet> createState() => _PushSheetState();
}

class _PushSheetState extends State<_PushSheet> {
  late final Push _p = widget.push;
  late final _title = TextEditingController(text: _p.title);
  late final _body = TextEditingController(text: _p.body);
  late final _titleSr = TextEditingController(text: _p.titleSr);
  late final _bodySr = TextEditingController(text: _p.bodySr);
  late String _repeat = _p.date != null ? 'once' : (_p.days.isEmpty ? 'daily' : 'days');

  @override
  void dispose() {
    for (final c in [_title, _body, _titleSr, _bodySr]) {
      c.dispose();
    }
    super.dispose();
  }

  Push _read() => _p
    ..title = _title.text.trim()
    ..body = _body.text.trim()
    ..titleSr = _titleSr.text.trim()
    ..bodySr = _bodySr.text.trim();

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 14; i++) addDays(widget.today, i)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.isNew ? tx('New push') : tx('Edit push'), style: BoltText.a(20, weight: 900)),
        FieldLabel(tx('ENGLISH')),
        BoltField(controller: _title, hint: tx('Title')),
        const SizedBox(height: 8),
        BoltTextArea(controller: _body, hint: tx('Message'), minHeight: 70),
        FieldLabel(tx('SERBIAN (OPTIONAL)')),
        BoltField(controller: _titleSr, hint: tx('Title')),
        const SizedBox(height: 8),
        BoltTextArea(controller: _bodySr, hint: tx('Message'), minHeight: 70),
        FieldLabel(tx('WHEN')),
        ChoiceChips(
          options: const ['once', 'daily', 'days'],
          labels: const {'once': 'Once', 'daily': 'Every day', 'days': 'On chosen days'},
          selected: _repeat,
          onSelect: (v) => setState(() {
            _repeat = v;
            _p.date = v == 'once' ? (_p.date ?? dk(widget.today)) : null;
            if (v != 'days') _p.days.clear();
            if (v == 'days' && _p.days.isEmpty) _p.days.addAll([1, 3, 5]);
          }),
        ),
        const SizedBox(height: 10),
        if (_repeat == 'once')
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in days)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tap(
                      onTap: () {
                        Haptics.play(Feel.tick);
                        setState(() => _p.date = dk(d));
                      },
                      child: BoltBox(
                        radius: 12,
                        color: _p.date == dk(d) ? BoltColors.neon : BoltColors.surface2,
                        stroke: Stroke(_p.date == dk(d) ? BoltColors.neon : BoltColors.line),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(
                          fmtDay(dk(d)),
                          style: BoltText.a(
                            12,
                            weight: 700,
                            color: _p.date == dk(d) ? BoltColors.ink : BoltColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (_repeat == 'days')
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                Tap(
                  onTap: () {
                    Haptics.play(Feel.tick);
                    setState(() => _p.days.contains(d) ? _p.days.remove(d) : _p.days.add(d));
                  },
                  child: BoltBox(
                    width: 40,
                    height: 40,
                    circle: true,
                    color: _p.days.contains(d) ? BoltColors.neon : BoltColors.surface2,
                    stroke: Stroke(_p.days.contains(d) ? BoltColors.neon : BoltColors.line),
                    alignment: Alignment.center,
                    child: Text(
                      weekdays[d % 7],
                      style: BoltText.a(11, weight: 800, color: _p.days.contains(d) ? BoltColors.ink : BoltColors.text),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 10),
        Tap(
          onTap: () async {
            final v = await pickTime(context, _p.at, title: tx('Time'));
            if (v != null) setState(() => _p.at = v);
          },
          child: BoltBox(
            radius: 14,
            color: BoltColors.surface2,
            stroke: const Stroke(BoltColors.line),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(tx('Time'), style: BoltText.a(14, weight: 700))),
                Text(fromMin(_p.at), style: BoltText.m(18, weight: 700, color: BoltColors.neon)),
              ],
            ),
          ),
        ),
        FieldLabel(tx('WHO GETS IT')),
        ChoiceChips(
          options: _audiences.keys.toList(),
          labels: _audiences,
          selected: _p.to,
          onSelect: (v) => setState(() => _p.to = v),
        ),
        const SizedBox(height: 18),
        NeonButton(
          label: tx('Save'),
          height: 52,
          scale: 1,
          onTap: () {
            final p = _read();
            if (p.title.isEmpty) return Haptics.play(Feel.error);
            Navigator.of(context).pop(p);
          },
        ),
        const SizedBox(height: 8),
        OutlineButton(
          label: tx('Try it on this phone'),
          color: BoltColors.text,
          borderColor: BoltColors.line,
          weight: 700,
          onTap: () {
            final p = _read();
            if (p.title.isEmpty) return Haptics.play(Feel.error);
            Haptics.play(Feel.tap);
            widget.onTest(p);
          },
        ),
        if (!widget.isNew) ...[
          const SizedBox(height: 8),
          OutlineButton(
            label: tx('Delete push'),
            color: BoltColors.warn,
            borderColor: BoltColors.line,
            weight: 700,
            onTap: () => Navigator.of(context).pop(_p..title = ''),
          ),
        ],
      ],
    );
  }
}
