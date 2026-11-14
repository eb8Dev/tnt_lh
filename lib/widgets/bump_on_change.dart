import 'package:flutter/material.dart';

/// Gives its child a quick springy "bump" whenever [value] goes up.
///
/// Used on the bag icon: adding something makes the bag hop and its count
/// change, which says "it's in" without a message covering the screen.
class BumpOnChange extends StatefulWidget {
  final int value;
  final Widget child;

  const BumpOnChange({super.key, required this.value, required this.child});

  @override
  State<BumpOnChange> createState() => _BumpOnChangeState();
}

class _BumpOnChangeState extends State<BumpOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  // Up quickly, then settle back with a little overshoot.
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.28,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.28,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant BumpOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > oldWidget.value) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
