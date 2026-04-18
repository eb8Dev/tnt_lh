import 'package:flutter/material.dart';
import 'dart:math' as math;

class StoreTransitionOverlay extends StatefulWidget {
  final Color color;
  final String logoAsset;
  final VoidCallback onTransitionPoint;
  final VoidCallback onComplete;

  const StoreTransitionOverlay({
    super.key,
    required this.color,
    required this.logoAsset,
    required this.onTransitionPoint,
    required this.onComplete,
  });

  static void show(
    BuildContext context, {
    required Color color,
    required String logoAsset,
    required VoidCallback onTransitionPoint,
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => StoreTransitionOverlay(
        color: color,
        logoAsset: logoAsset,
        onTransitionPoint: onTransitionPoint,
        onComplete: () {
          entry.remove();
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<StoreTransitionOverlay> createState() => _StoreTransitionOverlayState();
}

class _StoreTransitionOverlayState extends State<StoreTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;

  bool _transitionCalled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
    );

    _logoAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.8, 1.0, curve: Curves.easeIn),
    );

    _controller.addListener(() {
      if (_controller.value >= 0.6 && !_transitionCalled) {
        _transitionCalled = true;
        widget.onTransitionPoint();
      }
    });

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) * 1.2;
    // FAB is centerDocked, roughly at (width/2, height - 60)
    final fabCenter = Offset(size.width / 2, size.height - 60);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 1.0 - _fadeAnimation.value,
          child: Stack(
            children: [
              // Circular expansion
              CustomPaint(
                size: size,
                painter: CircularExpandPainter(
                  center: fabCenter,
                  radius: _expandAnimation.value * maxRadius,
                  color: widget.color,
                ),
              ),
              
              // Logo transition
              if (_controller.value > 0.2)
                Center(
                  child: Transform.scale(
                    scale: _logoAnimation.value,
                    child: Opacity(
                      opacity: (_logoAnimation.value * 2).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          widget.logoAsset,
                          width: 160,
                          height: 160,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class CircularExpandPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  CircularExpandPainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CircularExpandPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.color != color;
  }
}
