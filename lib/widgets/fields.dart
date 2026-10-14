import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

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
        textAlignVertical: TextAlignVertical.center,
        style: BoltText.a(fontSize, weight: weight),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: BoltText.a(fontSize, weight: weight, color: BoltColors.muted3),
          isDense: true,
          filled: true,
          fillColor: fill,
          contentPadding: EdgeInsets.symmetric(horizontal: padding),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}
