import 'package:flutter/widgets.dart';

/// The prototype's `vIn`: fade in and rise 10 px, optionally after a delay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 350),
    this.offset = 10,
    this.play = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  /// False shows [child] in place at once.
  final bool play;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.duration);
  late final _a = CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    if (!widget.play) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
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
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, widget.offset * (1 - _a.value)), child: child),
        child: widget.child,
      ),
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

/// Text that rolls to a new value: the old one fades up and out while the
/// new one rises in. For counters and stats that change in front of you.
class RollText extends StatelessWidget {
  const RollText(this.text, {super.key, required this.style, this.maxLines});

  final String text;
  final TextStyle style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        clipBehavior: Clip.none,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, a) {
        final incoming = child.key == ValueKey(text);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: Offset(0, incoming ? .35 : -.35), end: Offset.zero).animate(a),
            child: child,
          ),
        );
      },
      child: Text(text, key: ValueKey(text), maxLines: maxLines, style: style),
    );
  }
}

/// A quick swell (1 -> [scale] -> 1) whenever [on] turns true, e.g. a set
/// the moment it is ticked.
class Bump extends StatefulWidget {
  const Bump({super.key, required this.on, required this.child, this.scale = 1.07});

  final bool on;
  final Widget child;
  final double scale;

  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  late final _s = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: widget.scale).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(begin: widget.scale, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 60,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(Bump old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _s, child: widget.child);
}
