import 'package:flutter/widgets.dart';

/// The prototype's `vIn`: fade in and rise 10 px, optionally after a delay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
    this.offset = 10,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// The prototype's `vPop`: scale .3 -> 1.1 -> 1 while fading in.
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 450),
    this.curve = Curves.ease,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration)..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = widget.curve.transform(_c.value);
        final scale = t < .6 ? .3 + (1.1 - .3) * (t / .6) : 1.1 - .1 * ((t - .6) / .4);
        final opacity = (t / .6).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Bars and progress lines that grow from 0 (600 ms), then follow changes.
class GrowTo extends StatelessWidget {
  const GrowTo({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 600),
  });

  final double value;
  final Widget Function(BuildContext context, double v) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: const Cubic(.2, .8, .2, 1),
      builder: (context, v, _) => builder(context, v),
    );
  }
}
