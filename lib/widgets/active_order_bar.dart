import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/providers/order_provider.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';

/// A floating "your order is on the way" card that rides just above the
/// floating bottom nav on every tab while an order is in progress. Requested by
/// testers, and the norm on every food app — an order in flight should be one
/// tap away no matter where the customer wanders.
class ActiveOrderBar extends ConsumerWidget {
  const ActiveOrderBar({super.key});

  /// A short, human status line. Backend statuses are terse and inconsistent
  /// ('out-for-delivery', 'in_transit'); collapse them to something a customer
  /// reads at a glance.
  ({String text, IconData icon}) _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return (text: 'Waiting for the store to confirm', icon: PhosphorIcons.clock());
      case 'confirmed':
      case 'preparing':
        return (text: 'Your order is being prepared', icon: PhosphorIcons.cookingPot());
      case 'ready':
        return (text: 'Ready — waiting for a rider', icon: PhosphorIcons.package());
      case 'assigned':
      case 'accepted':
      case 'heading_to_pickup':
      case 'arrived_at_pickup':
        return (text: 'Rider is picking up your order', icon: PhosphorIcons.storefront());
      case 'picked_up':
      case 'out-for-delivery':
      case 'in_transit':
        return (text: 'On the way to you', icon: PhosphorIcons.moped());
      case 'arrived':
        return (text: 'Your rider has arrived', icon: PhosphorIcons.mapPin());
      default:
        return (text: 'Order in progress', icon: PhosphorIcons.receipt());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Order? order = ref.watch(activeOrderProvider);

    // AnimatedSize so it slides in/out cleanly as orders start and finish.
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: order == null
          ? const SizedBox(width: double.infinity)
          : _bar(context, order),
    );
  }

  Widget _bar(BuildContext context, Order order) {
    final primary = Theme.of(context).colorScheme.primary;
    final label = _statusLabel(order.status);

    return Container(
      margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OrderDetailScreen(orderId: order.id, brand: order.brand),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(label.icon, color: Colors.white, size: 18.sp),
                SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Order #${order.orderNumber} · tap to track',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
                Icon(
                  PhosphorIcons.caretRight(),
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
