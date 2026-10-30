import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wide screens (foldables open, tablets) get more content, not bigger
/// content.
///
/// Layouts are designed for a 390-wide phone, and flutter_screenutil scales
/// every `.w`/`.sp` by screenWidth / designWidth. On an unfolded Pixel Fold
/// (~850 wide) that made text and cards about 2.2x — the same two columns,
/// just larger. Raising the design width on wide screens caps that factor.
class Responsive {
  Responsive._();

  static const double designWidth = 390;
  static const double designHeight = 844;

  /// Largest scale a wide screen gets over the phone design.
  static const double maxScale = 1.15;

  /// Design size to give ScreenUtil for a screen of [screen] logical pixels.
  static Size designSizeFor(Size screen) =>
      Size(math.max(designWidth, screen.width / maxScale), designHeight);

  /// Grid columns that fit [width] with tiles at least [minTileWidth] wide:
  /// 2 on a phone, 3–4 on an open foldable, more on a tablet.
  static int columnsFor(double width, {double minTileWidth = 175}) =>
      (width / minTileWidth).floor().clamp(2, 6);

  /// Landscape tablets and wide windows: side navigation and two-pane
  /// layouts. Portrait tablets (600–840) keep the phone structure with more
  /// columns and centred pages.
  static const double expandedWidth = 840;

  /// Any tablet or wide window, either orientation.
  static const double tabletWidth = 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletWidth;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expandedWidth;

  /// Widest a form, sheet or detail page should run: beyond this lines get
  /// too long to read and buttons stretch across the screen.
  static const double maxContentWidth = 600;
}

/// Centres [child] and keeps it no wider than [Responsive.maxContentWidth].
/// A no-op on phones.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? Responsive.maxContentWidth,
      ),
      child: child,
    ),
  );
}

/// A whole page kept to a readable width on wide screens, with the theme's
/// background filling the sides. Wrap a screen's Scaffold in it. A no-op on
/// phones.
class CenteredPage extends StatelessWidget {
  const CenteredPage({super.key, required this.child, this.maxWidth = 640});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}
