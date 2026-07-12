import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The app's vertical/horizontal spacing scale. Before this, gaps were hand-
/// picked (2,4,6,8,10,12,14,16,20,24,32,36,40,48,60) which read as uneven.
/// Everything snaps to this small set. Values are logical px; use with `.h`/`.w`
/// at the call site, or the [Gap] helper which already applies `.h`.
class Space {
  Space._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double ml = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double huge = 48;
}

/// Control sizes. Buttons had drifted to 55/56/60/64/68 — chunky and uneven.
/// 48 is the standard primary CTA (Material's minimum touch target, and a
/// visible ~14% trim on the old 56); 44 suits secondary/compact actions.
class Sizes {
  Sizes._();

  static const double buttonPrimary = 48;
  static const double buttonCompact = 44;
  static const double field = 48;
}

/// A vertical gap on the spacing scale, e.g. `Gap(Space.md)`. Applies `.h` so
/// it scales with the device like the rest of the UI.
class Gap extends StatelessWidget {
  final double size;
  const Gap(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: size.h);
}

/// A horizontal gap on the spacing scale.
class GapW extends StatelessWidget {
  final double size;
  const GapW(this.size, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(width: size.w);
}
