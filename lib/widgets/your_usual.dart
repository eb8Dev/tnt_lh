import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/order_provider.dart';
import 'package:tnt_lh/providers/product_provider.dart';
import 'package:tnt_lh/utils/formatters.dart';

/// "Your usual": the customer's last delivered order from this store, one tap
/// to put it back in the bag. Items still on the menu are added at today's
/// price; ones that aren't are skipped. Hidden until there is such an order.
class YourUsualCard extends ConsumerStatefulWidget {
  final String brand;
  const YourUsualCard({super.key, required this.brand});

  @override
  ConsumerState<YourUsualCard> createState() => _YourUsualCardState();
}

/// An order line's options in the form the app sends them. The server
/// labels cakes its own way ("1kg | Standard | Eggless"); sent back as-is
/// that would read as a customer note, so it's turned back into the choice.
String? _asChoice(String? label) {
  final l = (label ?? '').trim();
  if (l.isEmpty) return null;
  if (RegExp(r'^[\d.]+kg \| (Standard|Customized)').hasMatch(l)) {
    return l.toLowerCase().contains('eggless') ? 'Eggless' : null;
  }
  return l;
}

class _YourUsualCardState extends ConsumerState<YourUsualCard> {
  bool _added = false;
  bool _busy = false;

  Future<void> _addAll(Order order, Map<String, List<Product>> menu) async {
    final byId = {
      for (final list in menu.values)
        for (final p in list) p.id: p,
    };
    final cart = ref.read(cartProvider.notifier);
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    var skipped = 0;
    for (final item in order.items) {
      final product = byId[item.product];
      if (product == null || !product.isAvailable) {
        skipped++;
        continue;
      }
      try {
        await cart.addToCart(
          product: product,
          quantity: item.quantity,
          customization: _asChoice(item.customization),
        );
      } catch (_) {
        skipped++;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _added = true;
    });
    if (skipped > 0) {
      noticeSheet(
        context,
        isError: false,
        title: 'Added to your bag',
        message:
            '$skipped ${skipped == 1 ? 'item isn\'t' : 'items aren\'t'} on the menu right now, so we left ${skipped == 1 ? 'it' : 'them'} out.',
      );
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(orderProvider).value?.orders ?? const <Order>[];
    final last = orders
        .where(
          (o) =>
              o.brand == widget.brand &&
              {'delivered', 'completed'}.contains(o.status.toLowerCase()),
        )
        .firstOrNull;
    final menu = ref.watch(storeMenuProvider(widget.brand)).value;
    if (last == null || menu == null || last.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final primary = Theme.of(context).colorScheme.primary;
    final summary = last.items
        .map((i) => '${i.quantity}× ${i.name}')
        .join(', ');

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 2.h),
      child: Container(
        padding: EdgeInsets.fromLTRB(12.w, 10.h, 8.w, 10.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(7.r),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                PhosphorIcons.arrowCounterClockwise(PhosphorIconsStyle.bold),
                size: 16.sp,
                color: primary,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your usual · ${AppFormatters.rupees(last.subtotal)}',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: _added
                  ? Padding(
                      key: const ValueKey('done'),
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: Icon(
                        PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        color: primary,
                        size: 24.sp,
                      ),
                    )
                  : FilledButton(
                      key: const ValueKey('add'),
                      onPressed: _busy ? null : () => _addAll(last, menu),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        minimumSize: Size(0, 34.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        textStyle: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _busy
                          ? SizedBox(
                              width: 14.r,
                              height: 14.r,
                              child: const CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Add to bag'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
