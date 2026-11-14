import 'package:tnt_lh/core/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class StoreSwitcher extends StatelessWidget {
  final String activeBrand;
  final ValueChanged<String> onSelect;

  const StoreSwitcher({
    super.key,
    required this.activeBrand,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isTnt = activeBrand == 'teasntrees';

    return SizedBox(
      height: 40.h,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primary.withValues(alpha: 0.08)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / 2;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: isTnt ? 0 : segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                Row(
                  children: [
                    Expanded(
                      child: _segment(
                        context,
                        brand: 'teasntrees',
                        label: Brands.cafeName,
                        icon: PhosphorIcons.coffee(PhosphorIconsStyle.fill),
                        active: isTnt,
                        primary: primary,
                      ),
                    ),
                    Expanded(
                      child: _segment(
                        context,
                        brand: 'littleh',
                        label: Brands.bakeryName,
                        icon: PhosphorIcons.cake(PhosphorIconsStyle.fill),
                        active: !isTnt,
                        primary: primary,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _segment(
    BuildContext context, {
    required String brand,
    required String label,
    required IconData icon,
    required bool active,
    required Color primary,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (brand == activeBrand) return;

        HapticFeedback.selectionClick();
        onSelect(brand);
      },
      child: Center(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          style: GoogleFonts.poppins(
            fontSize: 12.5.sp,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? primary : Colors.black45,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18.w,
                child: Icon(
                  icon,
                  size: 16.sp,
                  color: active ? primary : Colors.black38,
                ),
              ),
              SizedBox(width: 6.w),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
