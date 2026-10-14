import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bolt_store.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// White pill above the nav. Slides up 300 ms, gone after 2.6 s.
class ToastLayer extends ConsumerStatefulWidget {
  const ToastLayer({super.key});

  @override
  ConsumerState<ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends ConsumerState<ToastLayer> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(toastProvider, (_, next) {
      _timer?.cancel();
      if (next != null) {
        _timer = Timer(const Duration(milliseconds: 2600), () => ref.read(toastProvider.notifier).clear(next.id));
      }
    });
    final t = ref.watch(toastProvider);
    final bottom = MediaQuery.paddingOf(context).bottom + 104;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: IgnorePointer(
        // Sits above the navigator, outside any page's Material.
        child: Material(
          type: MaterialType.transparency,
          child: Center(
            child: t == null
                ? const SizedBox.shrink()
                : TweenAnimationBuilder<double>(
                    key: ValueKey(t.id),
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.ease,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
                    ),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 330),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: BoltColors.text,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 10))],
                      ),
                      child: Text(
                        t.text,
                        textAlign: TextAlign.center,
                        style: BoltText.a(13, weight: 700, color: BoltColors.ink),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
