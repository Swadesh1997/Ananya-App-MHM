import 'package:flutter/material.dart';

import 'package:ananya/utils/constants.dart';

/// "Probahini is writing" — three dots rising in turn, inside an empty reply
/// bubble.
///
/// This used to be a spinner beside the hardcoded English word "Typing...",
/// which read as the app loading rather than as an answer on its way, and read
/// as nothing at all to a girl using the app in Bangla. Shaping it like the
/// bubble the answer will arrive in says the same thing without any words: a
/// message is coming, and it lands here.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// One cycle covers all three dots. Each dot takes a third of it and they
  /// overlap, so the motion reads as a wave rather than three separate blinks.
  static const _cycle = Duration(milliseconds: 1100);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the system "remove animations" setting: the dots still show, they
    // just hold still. A looping animation is exactly what that setting is for.
    final animate = !MediaQuery.of(context).disableAnimations;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            child: const Icon(Icons.health_and_safety, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  _Dot(controller: _controller, index: i, animate: animate),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final bool animate;

  const _Dot({
    required this.controller,
    required this.index,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    const size = 7.0;

    Widget dot(double t) {
      // t runs 0 -> 1 -> 0 across this dot's slot in the cycle. The dot lifts
      // slightly and brightens together, which reads as one gesture.
      return Transform.translate(
        offset: Offset(0, -3 * t),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PRIMARY_COLOR.withValues(alpha: 0.35 + 0.55 * t),
          ),
        ),
      );
    }

    if (!animate) return dot(0.4);

    // Each dot's slot starts a fifth of a cycle after the previous one, so the
    // three overlap instead of firing one at a time.
    final begin = index * 0.2;
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, begin + 0.4, curve: Curves.easeInOut),
    );

    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) {
        // Fold the 0->1 slot into 0->1->0 so the dot returns to rest.
        final v = curve.value;
        final t = v <= 0.5 ? v * 2 : (1 - v) * 2;
        return dot(t);
      },
    );
  }
}
