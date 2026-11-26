import 'package:flutter/material.dart';

/// The Indian food mark: a square outline with a dot (veg green, egg amber)
/// or a triangle (non-veg red).
class FoodMark extends StatelessWidget {
  const FoodMark({super.key, required this.type, this.size = 12});

  final String type;
  final double size;

  static const veg = Color(0xFF1F8A3B);
  static const egg = Color(0xFFC98A00);
  static const nonveg = Color(0xFFB3261E);

  static Color colorOf(String type) => switch (type) {
    'egg' => egg,
    'nonveg' => nonveg,
    _ => veg,
  };

  @override
  Widget build(BuildContext context) {
    final color = colorOf(type);
    return Semantics(
      label: switch (type) {
        'egg' => 'Contains egg',
        'nonveg' => 'Non-veg',
        _ => 'Veg',
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: color, width: size * 0.12),
          borderRadius: BorderRadius.circular(size * 0.15),
        ),
        alignment: Alignment.center,
        child: type == 'nonveg'
            ? CustomPaint(
                size: Size(size * 0.5, size * 0.45),
                painter: _Triangle(color),
              )
            : Container(
                width: size * 0.45,
                height: size * 0.45,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
      ),
    );
  }
}

class _Triangle extends CustomPainter {
  _Triangle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.color != color;
}
