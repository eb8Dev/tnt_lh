import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/screens/bag_screen.dart';
import 'package:tnt_lh/utils/formatters.dart';
import 'package:tnt_lh/widgets/bump_on_change.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

/// "3 items · ₹540 · View bag", floating over the menu once something is in
/// the bag, the way food apps do it. The bag used to be a tab of its own.
///
/// It describes the store being browsed. If the other store's bag also has
/// items, a second line says so, since the bag page shows one store at a time.
class ViewBagBar extends ConsumerWidget {
  const ViewBagBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider).value?.items ?? const [];
    final store = ref.watch(brandProvider);

    final here = items.where((i) => i.brand == store);
    final count = here.fold<int>(0, (n, i) => n + i.quantity);
    final total = here.fold<double>(0, (s, i) => s + i.price * i.quantity);
    final otherStore = store == Brands.cafeKey
        ? Brands.bakeryKey
        : Brands.cafeKey;
    final otherCount = items
        .where((i) => i.brand == otherStore)
        .fold<int>(0, (n, i) => n + i.quantity);

    final visible = count > 0 || otherCount > 0;
    final color = Theme.of(context).colorScheme.primary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        alignment: Alignment.bottomCenter,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: !visible
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: const ValueKey('bar'),
              padding: EdgeInsets.fromLTRB(Space.md.w, 0, Space.md.w, 8.h),
              child: TactileButton(
                scaleOnTap: 0.97,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BagScreen(store: count > 0 ? store : otherStore),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: Space.md.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      BumpOnChange(
                        value: count + otherCount,
                        child: Icon(
                          PhosphorIcons.shoppingBag(PhosphorIconsStyle.fill),
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                      GapW(Space.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              count > 0
                                  ? '$count ${count == 1 ? 'item' : 'items'} · ${AppFormatters.rupees(total)}'
                                  : 'Your ${Brands.name(otherStore)} bag',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (count > 0 && otherCount > 0)
                              Text(
                                '+ $otherCount from ${Brands.name(otherStore)}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.sp,
                                ),
                              )
                            else if (count == 0)
                              Text(
                                '$otherCount ${otherCount == 1 ? 'item' : 'items'} waiting',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.sp,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        'View bag',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                        color: Colors.white,
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
