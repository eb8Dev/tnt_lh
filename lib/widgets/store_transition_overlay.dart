import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The store-switch transition — a calm vertical "fall" that fits the flat,
/// floating redesign (the old radial wipe + elastic logo pop read as a splash
/// screen). A solid panel in the target brand's colour:
///   1. drops in from the top and lands to cover the screen,
///   2. holds briefly while the brand wordmark fades in (no bounce),
///   3. keeps falling out the bottom, revealing the already-reskinned store
///      from the top down.
/// The brand swap ([onTransitionPoint]) happens while fully covered, so the
/// recolour is never seen mid-flight.
class StoreTransitionOverlay extends StatefulWidget {
  final Color color;
  final String logoAsset;
  final VoidCallback onTransitionPoint;
  final VoidCallback onComplete;

  /// The tapped store segment (fraction of the screen per axis). Retained for
  /// call-site compatibility; the fall itself is purely vertical.
  final Alignment originAlignment;

  const StoreTransitionOverlay({
    super.key,
    required this.color,
    required this.logoAsset,
    required this.onTransitionPoint,
    required this.onComplete,
    this.originAlignment = const Alignment(0, -0.75),
  });

  static void show(
    BuildContext context, {
    required Color color,
    required String logoAsset,
    required VoidCallback onTransitionPoint,
    Alignment originAlignment = const Alignment(0, -0.75),
  }) {
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => StoreTransitionOverlay(
        color: color,
        logoAsset: logoAsset,
        onTransitionPoint: onTransitionPoint,
        originAlignment: originAlignment,
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
  bool _transitionCalled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    // Swap the brand while the screen is fully covered (mid-hold), so the
    // recolour is hidden.
    _controller.addListener(() {
      if (_controller.value >= 0.5 && !_transitionCalled) {
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

  /// Vertical position of the panel in screen-height units:
  /// -1 = just above the top, 0 = covering, +1 = fallen out the bottom.
  double _panelY(double t) {
    const dropEnd = 0.30; // panel has landed (~375ms)
    const holdEnd = 0.66; // covered pause ends (~450ms of breathing room)
    if (t < dropEnd) {
      final p = Curves.easeOutCubic.transform(t / dropEnd);
      return -1.0 + p; // -1 -> 0
    }
    if (t < holdEnd) {
      return 0.0; // fully covering — the pause
    }
    final p = Curves.easeInCubic.transform((t - holdEnd) / (1 - holdEnd));
    return p; // 0 -> +1
  }

  /// Wordmark opacity: fades in as the panel lands, holds through the covered
  /// pause so it can actually be read, then fades out as it drops away.
  double _logoOpacity(double t) {
    if (t < 0.22) return 0;
    if (t < 0.34) return (t - 0.22) / 0.12; // fade in
    if (t < 0.60) return 1; // hold — ~325ms fully visible
    if (t < 0.70) return 1 - (t - 0.60) / 0.10; // fade out
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final dy = _panelY(t) * size.height;
          final logoOpacity = _logoOpacity(t).clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(0, dy),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The falling colour panel.
                ColoredBox(color: widget.color),
                // The wordmark rides with it, fading in on the way down with a
                // faint settle (no bounce) so the pause reads as deliberate.
                Center(
                  child: Opacity(
                    opacity: logoOpacity,
                    child: Transform.scale(
                      scale: 0.96 + 0.04 * logoOpacity,
                      child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 26.w,
                        vertical: 22.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                        child: Image.asset(
                          widget.logoAsset,
                          // Wide enough for the Cream N Crust wordmark; the
                          // squarer Teas N Trees mark just centres inside it.
                          width: 220.w,
                          height: 84.h,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
