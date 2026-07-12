import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/error_retry_view.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/utils/cart_error_listener.dart';
import 'package:tnt_lh/screens/checkout_screen.dart';
import 'package:tnt_lh/screens/store_home.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/utils/loading_indicator.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).fetchCart());
  }

  Future<void> _updateQuantity(String itemId, int newQty) async {
    try {
      if (newQty < 1) return;
      await ref.read(cartProvider.notifier).updateQuantity(itemId, newQty);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Failed to update: $e",
          isError: true,
        );
      }
    }
  }

  Future<void> _removeItem(String itemId, String brand) async {
    try {
      await ref.read(cartProvider.notifier).removeItem(itemId, brand: brand);
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Failed to remove: $e",
          isError: true,
        );
      }
    }
  }

  /// Shows a confirmation bottom sheet that switches to a loading state while
  /// the action runs, so the user never sees an unresponsive UI.
  Future<bool> _confirmAndRun({
    required String title,
    required String message,
    required String actionLabel,
    required String busyLabel,
    required Future<void> Function() action,
  }) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (_) => _ConfirmActionSheet(
        title: title,
        message: message,
        actionLabel: actionLabel,
        busyLabel: busyLabel,
        action: action,
      ),
    );
    return done ?? false;
  }

  Future<void> _clearCart() async {
    final cleared = await _confirmAndRun(
      title: "Clear All Bags?",
      message: "This will remove ALL items from both Cafe and Bakery.",
      actionLabel: "Clear Everything",
      busyLabel: "Clearing your bags…",
      action: () => ref.read(cartProvider.notifier).clearCart(),
    );

    if (cleared && mounted) {
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: "All bags cleared",
      );
    }
  }

  Future<void> _clearBrandCart(String brand) async {
    final brandName = brand == 'teasntrees' ? 'Cafe' : 'Bakery';
    final cleared = await _confirmAndRun(
      title: "Clear $brandName Bag?",
      message: "Remove all items from your $brandName bag?",
      actionLabel: "Clear Bag",
      busyLabel: "Clearing your $brandName bag…",
      action: () => ref.read(cartProvider.notifier).clearCart(brand: brand),
    );

    if (cleared && mounted) {
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: "$brandName bag cleared",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    listenForCartErrors(ref, context);
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "My Bags",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          TactileButton(
            onTap: _clearCart,
            child: Padding(
              padding: EdgeInsets.all(12.0.r),
              child: Icon(
                Icons.delete_sweep_rounded,
                color: Colors.black45,
                size: 24.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: cartState.when(
        loading: () => Center(child: HouseOfFlavorsLoader(size: 160.sp)),
        error: (err, stack) => ErrorRetryView(
          error: err,
          onRetry: () => ref.read(cartProvider.notifier).fetchCart(),
        ),
        data: (cart) {
          if (cart.items.isEmpty) {
            return _buildEmptyState();
          }

          final cafeItems = cart.items
              .where((i) => i.brand == 'teasntrees')
              .toList();
          final bakeryItems = cart.items
              .where((i) => i.brand == 'littleh')
              .toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  children: [
                    if (cafeItems.isNotEmpty)
                      _buildBrandSection(
                        "Teas N Trees (Cafe)",
                        cafeItems,
                        Color(0xFF57733C),
                        'teasntrees',
                      ),

                    if (bakeryItems.isNotEmpty) ...[
                      SizedBox(height: 40.h),
                      _buildBrandSection(
                        "Little H (Bakery)",
                        bakeryItems,
                        Color(0xFF8C3414),
                        'littleh',
                      ),
                    ],
                    SizedBox(height: 40.h),
                  ],
                ),
              ),

              _buildGlobalCheckoutFooter(cart),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandSection(
    String title,
    List<CartItem> items,
    Color themeColor,
    String brand,
  ) {
    final brandSubtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TactileButton(
                  onTap: () => _clearBrandCart(brand),
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18.sp,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                TactileButton(
                  onTap: () {
                    final brandCart = Cart(
                      items: items,
                      subtotal: brandSubtotal,
                      itemCount: items.length,
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CheckoutScreen(
                          cart: brandCart,
                          specificBrand: brand,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      "Checkout Store",
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20.h),
        ...items.map(
          (item) => Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: _buildCartItem(item),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Dismissible(
      key: Key("cart_item_${item.id}"),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(24.r),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_sweep_rounded,
          color: Color(0xFFEF5350), // Colors.red.shade400
          size: 32.sp,
        ),
      ),
      onDismissed: (_) => _removeItem(item.id, item.brand),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
        ),
        child: Row(
          children: [
            Container(
              height: 75.h,
              width: 75.w,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child:
                    item.product.image != null && item.product.image!.isNotEmpty
                    ? Image.network(
                        item.product.image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.fastfood_rounded,
                          color: Colors.black12,
                          size: 32.sp,
                        ),
                      )
                    : Icon(
                        Icons.fastfood_rounded,
                        color: Colors.black12,
                        size: 32.sp,
                      ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: Colors.black87,
                    ),
                  ),
                  if (item.customization != null)
                    Text(
                      item.customization!,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.black38,
                      ),
                    ),
                  SizedBox(height: 8.h),
                  Text(
                    "₹${item.price * item.quantity}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 36.h,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  TactileButton(
                    onTap: () {
                      if (item.quantity == 1) {
                        _removeItem(item.id, item.brand);
                      } else {
                        _updateQuantity(item.id, item.quantity - 1);
                      }
                    },
                    child: Container(
                      width: 32.w,
                      height: 32.h,
                      alignment: Alignment.center,
                      child: Icon(
                        item.quantity == 1
                            ? Icons.delete_outline_rounded
                            : Icons.remove_rounded,
                        size: 18.sp,
                        color: item.quantity == 1
                            ? Colors.redAccent
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0.w),
                    child: Text(
                      "${item.quantity}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  TactileButton(
                    onTap: () => _updateQuantity(item.id, item.quantity + 1),
                    child: Container(
                      width: 32.w,
                      height: 32.h,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add_rounded,
                        size: 18.sp,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
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
              Icons.shopping_basket_rounded,
              size: 80.sp,
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            "Your bags are empty",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "Discover something delicious today",
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
              height: 56.h,
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
                "Start Exploring",
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

  Widget _buildGlobalCheckoutFooter(Cart cart) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Total Amount",
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  color: Colors.black38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "₹${cart.subtotal}",
                style: GoogleFonts.poppins(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          TactileButton(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CheckoutScreen(cart: cart)),
            ),
            child: Container(
              width: 180.w,
              height: 60.h,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Checkout All",
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 20.sp,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation bottom sheet that swaps to an inline loading state while the
/// action runs, then pops `true` on success. Replaces the old AlertDialogs.
class _ConfirmActionSheet extends StatefulWidget {
  final String title;
  final String message;
  final String actionLabel;
  final String busyLabel;
  final Future<void> Function() action;

  const _ConfirmActionSheet({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.busyLabel,
    required this.action,
  });

  @override
  State<_ConfirmActionSheet> createState() => _ConfirmActionSheetState();
}

class _ConfirmActionSheetState extends State<_ConfirmActionSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.action();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't clear your bag. Please try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block back-dismissal while the action is in flight.
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              if (_busy) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 22.w,
                      height: 22.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: const Color(0xFFA9BCA4),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        widget.busyLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ] else ...[
                Text(
                  widget.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  widget.message,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: Colors.black54,
                  ),
                ),
                if (_error != null) ...[
                  SizedBox(height: 12.h),
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _run,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: Text(
                          widget.actionLabel,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
