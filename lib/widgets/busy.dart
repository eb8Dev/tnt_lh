import 'package:flutter/material.dart';

/// Shown while something is being done (no spinners anywhere in the apps):
/// its child gently fades in and out.
class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: widget.child,
  );
}

/// "Please wait" in a busy button, in the button's colour.
class BusyLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const BusyLabel({super.key, this.text = 'Please wait', this.color});

  @override
  Widget build(BuildContext context) => Pulse(
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        color: color ?? Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// A small pulsing dot, for tight spots (an icon button, a chip).
class BusyDot extends StatelessWidget {
  final Color? color;
  final double size;
  const BusyDot({super.key, this.color, this.size = 10});

  @override
  Widget build(BuildContext context) => Pulse(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    ),
  );
}
