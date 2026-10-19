import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'bolt_sheet.dart';
import 'common.dart';

InputDecoration _decoration(String hint, EdgeInsets padding, {bool filled = true, Color fill = BoltColors.surface1}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: BoltColors.line),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: BoltText.a(14, color: BoltColors.muted3),
    isDense: true,
    filled: filled,
    fillColor: fill,
    contentPadding: padding,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
  );
}

/// Multi-line note field (`textarea` in the prototype).
class BoltTextArea extends StatelessWidget {
  const BoltTextArea({super.key, required this.controller, required this.hint, this.minHeight = 84, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final double minHeight;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        minLines: 3,
        maxLines: 6,
        style: BoltText.a(14, height: 1.4),
        decoration: _decoration(hint, const EdgeInsets.all(12)),
      ),
    );
  }
}

/// Single-line field, 50 px tall by default.
class BoltField extends StatelessWidget {
  const BoltField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.height = 50,
    this.fontSize = 15,
    this.radius = 14,
    this.fill = BoltColors.surface1,
    this.weight = 400,
    this.padding = 14,
    this.number = false,
    this.suffix,
    this.words = false,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final double height;
  final double fontSize;
  final double radius;
  final Color fill;
  final double weight;
  final double padding;

  /// Decimal keyboard, for measurements.
  final bool number;

  /// Unit shown inside the field, e.g. "kg".
  final String? suffix;

  /// Capitalise words, for names.
  final bool words;

  /// Opens the keyboard straight away.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: BoltColors.line),
    );
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        // Fill the fixed height like the prototype's inputs.
        expands: true,
        maxLines: null,
        textInputAction: TextInputAction.done,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        textCapitalization: words ? TextCapitalization.words : TextCapitalization.sentences,
        textAlignVertical: TextAlignVertical.center,
        style: BoltText.a(fontSize, weight: weight),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BoltText.a(fontSize, weight: weight, color: BoltColors.muted3),
          isDense: true,
          filled: true,
          fillColor: fill,
          contentPadding: EdgeInsets.symmetric(horizontal: padding),
          suffixText: suffix,
          suffixStyle: BoltText.m(12, color: BoltColors.muted),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

/// A sheet with one field and Save, popping what was typed. [clear] adds a
/// second button that pops an empty string. The sheet owns its controller,
/// so the field outlives the closing animation.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String hint,
  required String save,
  String initial = '',
  String? help,
  String? suffix,
  bool number = false,
  String? clear,
}) => showBoltSheet<String>(
  context,
  (_) => _TextSheet(
    title: title,
    hint: hint,
    save: save,
    initial: initial,
    help: help,
    suffix: suffix,
    number: number,
    clear: clear,
  ),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.hint,
    required this.save,
    required this.initial,
    required this.help,
    required this.suffix,
    required this.number,
    required this.clear,
  });

  final String title, hint, save, initial;
  final String? help, suffix, clear;
  final bool number;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pop(String v) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title, style: BoltText.a(20, weight: 900)),
        if (widget.help != null) ...[
          const SizedBox(height: 6),
          Text(widget.help!, style: BoltText.a(13, color: BoltColors.muted, height: 1.45)),
        ],
        const SizedBox(height: 12),
        BoltField(controller: _c, hint: widget.hint, number: widget.number, suffix: widget.suffix, autofocus: true),
        const SizedBox(height: 14),
        NeonButton(label: widget.save, height: 52, scale: 1, onTap: () => _pop(_c.text.trim())),
        if (widget.clear != null) ...[
          const SizedBox(height: 8),
          OutlineButton(
            label: widget.clear!,
            color: BoltColors.warn,
            borderColor: BoltColors.line,
            onTap: () => _pop(''),
          ),
        ],
      ],
    );
  }
}
