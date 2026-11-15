import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A shimmering placeholder block. A moving highlight sweeps across a muted base
/// so a loading list reads as "almost there" instead of an anxious spinner.
/// Honors reduced-motion by falling back to a static block.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.margin,
  });

  const Skeleton.circle({super.key, required double size, this.margin})
    : width = size,
      height = size,
      radius = size;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final base = Colors.black.withValues(alpha: 0.06);
    final highlight = Colors.black.withValues(alpha: 0.02);

    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius.r),
        color: base,
      ),
      clipBehavior: Clip.antiAlias,
      child: reduceMotion
          ? null
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return FractionallySizedBox(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [base, highlight, base],
                        stops: const [0.1, 0.5, 0.9],
                        begin: Alignment(-1 - 2 * _controller.value, 0),
                        end: Alignment(1 - 2 * _controller.value, 0),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// A placeholder that matches a product row card (image + two text lines).
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108.h,
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
      ),
      child: Row(
        children: [
          Skeleton(width: 96.w, height: 96.h, radius: 20),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Skeleton(width: 140.w, height: 15.h),
                SizedBox(height: 8.h),
                Skeleton(width: 90.w, height: 11.h),
                SizedBox(height: 12.h),
                Skeleton(width: 64.w, height: 18.h, radius: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A vertical list of product skeletons — drop-in for a loading product list.
class ProductListSkeleton extends StatelessWidget {
  final int count;
  const ProductListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    // shrinkWrap: it is also placed inside other scrollables (the home
    // screen's), where an unbounded ListView fails layout and the loading
    // state rendered as nothing at all.
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, _) => SizedBox(height: 16.h),
      itemBuilder: (_, _) => const ProductCardSkeleton(),
    );
  }
}

/// The menu while it loads, shaped like the real thing: a section title and
/// two columns of cards (4:3 photo, name, price). A list of rows used to
/// stand in for a grid, so the screen jumped when the menu arrived.
class MenuGridSkeleton extends StatelessWidget {
  final int cards;
  final bool title;

  /// Off when it sits inside something that already has side margins.
  final bool inset;
  const MenuGridSkeleton({
    super.key,
    this.cards = 6,
    this.title = true,
    this.inset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: inset
          ? EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h)
          : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title) ...[
            Skeleton(width: 130.w, height: 16.h),
            SizedBox(height: 12.h),
          ],
          LayoutBuilder(
            builder: (context, box) {
              final w = (box.maxWidth - 12.w) / 2;
              return Wrap(
                spacing: 12.w,
                runSpacing: 12.h,
                children: [
                  for (var i = 0; i < cards; i++)
                    Container(
                      width: w,
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Skeleton(
                            width: w,
                            height: (w - 8.r) * 3 / 4,
                            radius: 12,
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(6.w, 10.h, 6.w, 8.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Skeleton(width: w * 0.7, height: 12.h),
                                SizedBox(height: 8.h),
                                Skeleton(width: w * 0.35, height: 12.h),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
