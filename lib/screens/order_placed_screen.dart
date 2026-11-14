import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';
import 'package:tnt_lh/screens/store_home.dart';

/// "Order placed": a short celebration, then straight to tracking.
///
/// Replaces an alert dialog. Placing an order is the best moment in the app;
/// it deserves more than a system box with two buttons.
class OrderPlacedScreen extends StatefulWidget {
  final String orderId;
  final String? orderNumber;
  final String store;

  const OrderPlacedScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.store,
  });

  @override
  State<OrderPlacedScreen> createState() => _OrderPlacedScreenState();
}

class _OrderPlacedScreenState extends State<OrderPlacedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _goHome({required bool track}) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => StoreHomeScreen(
          initialIndex: track ? StoreHomeScreen.ordersTab : 0,
        ),
      ),
      (_) => false,
    );
    if (track && widget.orderId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              OrderDetailScreen(orderId: widget.orderId, brand: widget.store),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Brands.color(widget.store);
    final circle = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.45, curve: Curves.elasticOut),
    );
    final tick = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.25, 0.6, curve: Curves.easeOut),
    );
    final text = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.45, 0.9, curve: Curves.easeOut),
    );

    return PopScope(
      // Back from here goes to the menu, never to the (now empty) bag.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(track: false);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(Space.lg.r),
            child: Column(
              children: [
                const Spacer(flex: 2),
                SizedBox(
                  width: 150.r,
                  height: 150.r,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _c,
                        builder: (_, _) => CustomPaint(
                          size: Size.square(150.r),
                          painter: _Sprinkles(progress: _c.value, color: color),
                        ),
                      ),
                      ScaleTransition(
                        scale: circle,
                        child: Container(
                          width: 92.r,
                          height: 92.r,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: tick,
                            builder: (_, _) => CustomPaint(
                              painter: _Tick(progress: tick.value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Gap(Space.lg),
                FadeTransition(
                  opacity: text,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(text),
                    child: Column(
                      children: [
                        Text(
                          'Order placed!',
                          style: GoogleFonts.poppins(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Gap(Space.xxs),
                        Text(
                          widget.orderNumber == null
                              ? '${Brands.name(widget.store)} has your order.'
                              : 'Order #${widget.orderNumber} is with ${Brands.name(widget.store)}.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: Colors.black54,
                          ),
                        ),
                        Gap(Space.xxs),
                        Text(
                          "We'll let you know the moment they start on it.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: text,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: Sizes.buttonPrimary.h,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                          ),
                          onPressed: () => _goHome(track: true),
                          icon: Icon(PhosphorIcons.mapTrifold(), size: 18.sp),
                          label: Text(
                            'Track order',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      Gap(Space.xs),
                      TextButton(
                        onPressed: () => _goHome(track: false),
                        child: Text(
                          'Back to menu',
                          style: GoogleFonts.poppins(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The check mark, drawn stroke by stroke.
class _Tick extends CustomPainter {
  final double progress;
  _Tick({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.36);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..strokeWidth = w * 0.08
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Tick old) => old.progress != progress;
}

/// A ring of sprinkles that bursts out from the circle and fades.
class _Sprinkles extends CustomPainter {
  final double progress;
  final Color color;
  _Sprinkles({required this.progress, required this.color});

  static const _palette = [
    Color(0xFFF9B4CB),
    Color(0xFFA5BF45),
    Color(0xFFF5A623),
    Color(0xFFE5484D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = ((progress - 0.15) / 0.6).clamp(0.0, 1.0);
    if (t == 0 || t == 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 14; i++) {
      final angle = i * 2 * pi / 14 + (i.isEven ? 0.12 : -0.08);
      final r = size.width * (0.32 + 0.22 * eased) * (i.isEven ? 1 : 0.85);
      final p = center + Offset(cos(angle), sin(angle)) * r;
      final paint = Paint()
        ..color = (i % 3 == 0 ? color : _palette[i % _palette.length])
            .withValues(alpha: 1 - t);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + t * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 9, height: 3.5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Sprinkles old) => old.progress != progress;
}
