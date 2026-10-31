import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

import '../theme/tokens.dart';

/// Modal bottom sheet styled like the prototype: slides up 350 ms on
/// cubic(.2,.8,.2,1) over a 60 % black scrim, 28 px top corners, a handle.
class BoltSheetRoute<T> extends PopupRoute<T> {
  BoltSheetRoute({
    required this.builder,
    this.maxHeight = .86,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 26),
  });

  final WidgetBuilder builder;
  final double maxHeight;
  final EdgeInsets padding;

  @override
  Color get barrierColor => const Color(0x99000000);

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => tx('Close');

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final mq = MediaQuery.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: (mq.size.height - mq.viewInsets.bottom) * maxHeight),
          child: _SheetBody(padding: padding, route: this, child: builder(context)),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: const Cubic(.2, .8, .2, 1), reverseCurve: Curves.easeIn)),
      child: child,
    );
  }
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.child, required this.padding, required this.route});

  final Widget child;
  final EdgeInsets padding;
  final BoltSheetRoute route;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> with SingleTickerProviderStateMixin {
  double _drag = 0;

  /// Eases a sheet that was not pulled far enough back into place.
  late final _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  double _from = 0;

  @override
  void initState() {
    super.initState();
    _back.addListener(() => setState(() => _drag = _from * (1 - Curves.easeOutCubic.transform(_back.value))));
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _move(double dy) {
    _back.stop();
    setState(() => _drag = (_drag + dy).clamp(0, double.infinity));
  }

  void _release(double velocity) {
    if (_drag > 100 || velocity > 700) {
      Navigator.of(context).pop();
    } else if (_drag > 0) {
      _from = _drag;
      _back.forward(from: 0);
    }
  }

  /// A sheet that scrolls follows the finger down once its content is at
  /// the top, like one that fits.
  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) {
      _move(-n.overscroll);
    } else if (n is ScrollUpdateNotification && n.dragDetails != null && _drag > 0) {
      _move(-(n.scrollDelta ?? 0));
    } else if (n is ScrollEndNotification && _drag > 0) {
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Transform.translate(
      offset: Offset(0, _drag),
      child: Material(
        color: BoltColors.sheet,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(BoltRadii.sheet)),
          side: BorderSide(color: BoltColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (d) => _move(d.delta.dy),
          onVerticalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: SingleChildScrollView(
              padding: widget.padding.copyWith(bottom: widget.padding.bottom + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: BoltColors.handle, borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                  widget.child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showBoltSheet<T>(BuildContext context, WidgetBuilder builder, {double maxHeight = .86}) {
  return Navigator.of(context, rootNavigator: true).push(BoltSheetRoute<T>(builder: builder, maxHeight: maxHeight));
}
