import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'box.dart';
import 'common.dart';
import 'tap.dart';

/// A category that opens to show its cards. Shut, it still names what is
/// inside, so a long list fits on a screen or two.
class BoltAccordion extends StatefulWidget {
  const BoltAccordion({
    super.key,
    required this.title,
    required this.preview,
    required this.children,
    this.initiallyOpen = false,
    this.highlight = false,
    this.summary,
  });

  final String title;
  final List<String> preview;
  final List<Widget> children;
  final bool initiallyOpen;

  /// Holds what is currently chosen, so it stays findable when shut.
  final bool highlight;

  /// Said while shut instead of [preview], like what is chosen inside.
  final String? summary;

  @override
  State<BoltAccordion> createState() => _BoltAccordionState();
}

class _BoltAccordionState extends State<BoltAccordion> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: Tap(
            onTap: () {
              Haptics.play(Feel.tick);
              setState(() => _open = !_open);
            },
            child: BoltBox(
              color: BoltColors.surface1,
              stroke: widget.highlight
                  ? Stroke(BoltColors.neon, 1.5)
                  : Stroke(_open ? BoltColors.line : BoltColors.lineSoft),
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: BoltText.a(16, weight: 800)),
                        // Open, the cards below say it already.
                        if (!_open) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.summary ?? widget.preview.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BoltText.a(12, color: widget.summary == null ? BoltColors.muted : BoltColors.neon),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${widget.preview.length}', style: BoltText.m(12, weight: 700, color: BoltColors.neon)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? .25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Chevron(size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
