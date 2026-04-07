import 'package:flutter/material.dart';
import 'dart:math' as math;

class HouseOfFlavorsLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const HouseOfFlavorsLoader({super.key, this.size = 60.0, this.color});

  @override
  State<HouseOfFlavorsLoader> createState() => _HouseOfFlavorsLoaderState();
}

class _HouseOfFlavorsLoaderState extends State<HouseOfFlavorsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? const Color(0xFFA9BCA4);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Rotating outer dots
              ...List.generate(8, (index) {
                final angle = (index * 45) * (math.pi / 180);
                final rotation = _controller.value * 2 * math.pi;

                // Opacity based on position in rotation
                double opacity =
                    1.0 - ((index / 8.0) + _controller.value) % 1.0;

                return Transform.rotate(
                  angle: rotation,
                  child: Transform.translate(
                    offset: Offset(
                      (widget.size / 2.5) * math.cos(angle),
                      (widget.size / 2.5) * math.sin(angle),
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: opacity),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),

              // Pulsing center icon (Zen Leaf)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.2),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Icon(
                      Icons.spa_rounded,
                      color: themeColor,
                      size: widget.size * 0.4,
                    ),
                  );
                },
                onEnd: () {
                  // This is just to create a basic loop for the pulse if needed
                },
              ),

              // Second pulse overlay
              Opacity(
                opacity: (1.0 - _controller.value).clamp(0, 1),
                child: Transform.scale(
                  scale: 1.0 + (_controller.value * 0.5),
                  child: Container(
                    width: widget.size * 0.5,
                    height: widget.size * 0.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final String? message;
  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HouseOfFlavorsLoader(size: 80),
          if (message != null) ...[
            const SizedBox(height: 24),
            Text(
              message!,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
