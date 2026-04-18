import 'package:flutter/material.dart';
import 'dart:math' as math;

class HouseOfFlavorsLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const HouseOfFlavorsLoader({super.key, this.size = 150.0, this.color});

  @override
  State<HouseOfFlavorsLoader> createState() => _HouseOfFlavorsLoaderState();
}

class _HouseOfFlavorsLoaderState extends State<HouseOfFlavorsLoader>
    with TickerProviderStateMixin {
  late AnimationController _steamController;
  late AnimationController _pulseController;
  late AnimationController _switchController;

  @override
  void initState() {
    super.initState();
    _steamController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _steamController.dispose();
    _pulseController.dispose();
    _switchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cafeColor = const Color(0xFF57733C);
    final bakeryColor = const Color(0xFF8C3414);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_steamController, _pulseController, _switchController]),
        builder: (context, child) {
          final isCafePhase = _switchController.value < 0.5;
          final Color activeColor = Color.lerp(
            cafeColor,
            bakeryColor,
            Curves.easeInOut.transform(_switchController.value),
          )!;

          return Stack(
            alignment: Alignment.center,
            children: [
              // 1. Warm "Oven/Brew" Glow
              Container(
                width: widget.size * 0.8,
                height: widget.size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      activeColor.withValues(alpha: 0.2 * _pulseController.value),
                      activeColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),

              // 2. Rising Steam/Aroma Waves
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _SteamPainter(
                  progress: _steamController.value,
                  color: activeColor.withValues(alpha: 0.3),
                ),
              ),

              // 3. Floating Ingredients (Coffee Beans / Wheat Particles)
              ...List.generate(6, (index) {
                final double seed = index / 6;
                final double t = (_steamController.value + seed) % 1.0;
                return Positioned(
                  bottom: widget.size * (0.2 + (0.6 * t)),
                  left: widget.size * (0.3 + (0.4 * math.sin(t * 2 * math.pi + index))),
                  child: Opacity(
                    opacity: (1.0 - t) * 0.5,
                    child: Container(
                      width: 8,
                      height: 12,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),

              // 4. The Iconic Centerpiece
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The Steaming Icon
                  Transform.translate(
                    offset: Offset(0, -10 * _pulseController.value),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Cross-fading Logos
                          Opacity(
                            opacity: isCafePhase ? 1.0 : 0.0,
                            child: Image.asset(
                              "assets/images/teas_n_trees_no_bg.png",
                              width: widget.size * 0.5,
                              height: widget.size * 0.5,
                            ),
                          ),
                          Opacity(
                            opacity: isCafePhase ? 0.0 : 1.0,
                            child: Image.asset(
                              "assets/images/little_h_logo_no_bg.png",
                              width: widget.size * 0.5,
                              height: widget.size * 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The "Vapor" Base (Shadow)
                  Container(
                    width: widget.size * 0.2 * (0.8 + 0.2 * _pulseController.value),
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.all(Radius.elliptical(20, 4)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SteamPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SteamPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final double centerX = size.width / 2;
    final double startY = size.height * 0.6;

    for (int i = -1; i <= 1; i++) {
      final double xOffset = i * 25.0;
      final double individualProgress = (progress + (i * 0.2)) % 1.0;
      
      final path = Path();
      final double currentY = startY - (individualProgress * 80);
      
      // Wavy steam line
      path.moveTo(centerX + xOffset, startY);
      
      for (double j = 0; j < individualProgress; j += 0.05) {
        final double y = startY - (j * 80);
        final double x = centerX + xOffset + math.sin(j * 10 + progress * 5) * 8;
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Fade out steam
      final double opacity = (1.0 - individualProgress).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SteamPainter oldDelegate) => 
      oldDelegate.progress != progress || oldDelegate.color != color;
}

