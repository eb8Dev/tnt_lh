import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:tnt_lh/widgets/skeleton.dart';
import 'package:tnt_lh/widgets/error_retry_view.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/providers/order_provider.dart';
import 'package:tnt_lh/providers/status_provider.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/utils/formatters.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(orderProvider.notifier).refresh());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Fetch the next page a little before the customer actually hits the bottom,
  /// so the list keeps flowing instead of stalling on a spinner.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(orderProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(orderProvider);

    return CenteredPage(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            "My Orders",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.black87,
              fontSize: 20.sp,
            ),
          ),
        ),
        body: ordersState.when(
          loading: () => const ProductListSkeleton(count: 4),
          error: (err, stack) => ErrorRetryView(
            error: err,
            onRetry: () => ref.invalidate(orderProvider),
          ),
          data: (ordersState) {
            final orders = ordersState.orders;
            if (orders.isEmpty) {
              return _buildEmptyState();
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(orderProvider.notifier).refresh(),
              color: Theme.of(context).colorScheme.primary,
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(20, 10, 20, 100),
                // +1 for the "you owe us a rating" nudge, +1 for the footer that
                // either loads the next page or says we've reached the end.
                itemCount: orders.length + 2,
                separatorBuilder: (_, _) => SizedBox(height: 16.h),
                itemBuilder: (context, index) {
                  if (index == 0) return _buildRatingNudge();
                  if (index == orders.length + 1) {
                    return _buildListFooter(ordersState);
                  }
                  return _buildOrderCard(orders[index - 1]);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  /// The end of the list should say something. Before this, the list simply
  /// stopped at whatever the first page held, and the customer had no way to
  /// tell whether that was all their orders or just all we'd bothered to load.
  Widget _buildListFooter(OrdersState state) {
    if (state.isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24.h),
        child: Center(
          child: SizedBox(
            width: 22.sp,
            height: 22.sp,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    if (state.hasMore) {
      // Scrolling pulls the next page in automatically; this is just something
      // to look at while that happens.
      return SizedBox(height: 24.h);
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h),
      child: Center(
        child: Text(
          "That's all your orders",
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: Colors.black.withValues(alpha: 0.35),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// The backend already knows when a delivered order is still unrated. Nudge
  /// for it here instead of letting the rating card go unseen.
  Widget _buildRatingNudge() {
    final pending = ref
        .watch(customerStatusProvider)
        .maybeWhen(data: (s) => s.orderAwaitingRating, orElse: () => null);
    if (pending == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: TactileButton(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: pending),
          ),
        ),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E5),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: const Color(0xFFF5A623).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                PhosphorIcons.star(PhosphorIconsStyle.fill),
                color: const Color(0xFFF5A623),
                size: 26.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "How was your last order?",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      "Rate the food and your rider — it takes a second.",
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                size: 14.sp,
                color: Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final isTeas = order.brand == 'teasntrees';

    return TactileButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: (isTeas ? Brands.cafeColor : Brands.bakeryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    isTeas ? Brands.cafeName : Brands.bakeryName,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isTeas ? Brands.cafeColor : Brands.bakeryColor,
                    ),
                  ),
                ),
                Text(
                  AppFormatters.formatDate(order.createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order #${order.orderNumber}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "${order.items.length} ${order.items.length == 1 ? 'item' : 'items'} • ₹${order.total}",
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    AppFormatters.statusLabel(order.status).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Divider(height: 1.h, color: Color(0xFFF5F5F5)),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  // Nothing to track once it is over.
                  [
                        'delivered',
                        'cancelled',
                      ].contains(order.status.toLowerCase())
                      ? "View details"
                      : "Track order",
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Icon(
                  PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                  size: 14.sp,
                  color: Colors.black26,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(40.r),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Icon(
              PhosphorIcons.receipt(PhosphorIconsStyle.fill),
              size: 80.sp,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            "No orders yet",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "Your delicious history will appear here",
            style: GoogleFonts.poppins(color: Colors.black38, fontSize: 14.sp),
          ),
          SizedBox(height: 40.h),
          TactileButton(
            onTap: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => StoreHomeScreen()),
              (route) => false,
            ),
            child: Container(
              width: 220.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                "Order Something",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'out for delivery':
        return Colors.amber.shade700;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
