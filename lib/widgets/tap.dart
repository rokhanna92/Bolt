import 'package:flutter/widgets.dart';

/// A tap target that shrinks slightly while pressed (the prototype's
/// `:active { transform: scale(...) }`). [scale] 1 means no press effect.
/// Screen readers announce it as a button.
class Tap extends StatefulWidget {
  const Tap({super.key, required this.onTap, required this.child, this.scale = 1, this.onLongPress});

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final double scale;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  void _set(bool v) {
    if (widget.scale != 1 && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: widget.scale == 1
          ? widget.child
          : AnimatedScale(
              scale: _down ? widget.scale : 1,
              duration: const Duration(milliseconds: 100),
              child: widget.child,
            ),
    );
    return widget.onTap == null ? detector : Semantics(button: true, child: detector);
  }
}
