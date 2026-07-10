import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/wishlist_provider.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';

class ItemDetailsScreen extends ConsumerStatefulWidget {
  final Product product;
  const ItemDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends ConsumerState<ItemDetailsScreen> {
  int _quantity = 1;
  String? _selectedSize;
  bool _isEggless = false;
  final TextEditingController _customizationController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.product.sizeOptions.isNotEmpty) {
      _selectedSize = widget.product.sizeOptions[0].size;
    }
  }

  @override
  void dispose() {
    _customizationController.dispose();
    super.dispose();
  }

  double get _currentPrice {
    double base = widget.product.displayPrice;
    if (_selectedSize != null) {
      final opt = widget.product.sizeOptions.firstWhere(
        (e) => e.size == _selectedSize,
      );
      base = opt.price;
    }
    if (_isEggless && widget.product.cakePricing != null) {
      base += widget.product.cakePricing!.egglessExtraCharge;
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final isLittleH = widget.product.brand == 'littleh';
    final themeColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: EdgeInsets.all(8.0.r),
              child: TactileButton(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black,
                    size: 24.sp,
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.all(8.0.r),
                child: Consumer(
                  builder: (context, ref, child) {
                    final isFav = ref
                        .watch(wishlistProvider)
                        .maybeWhen(
                          data: (list) =>
                              list.any((p) => p.id == widget.product.id),
                          orElse: () => false,
                        );
                    return TactileButton(
                      onTap: () => ref
                          .read(wishlistProvider.notifier)
                          .toggleFavorite(widget.product),
                      child: Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? Colors.redAccent : Colors.black,
                          size: 24.sp,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: 8.w),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background:
                  widget.product.image != null &&
                      widget.product.image!.isNotEmpty
                  ? Image.network(widget.product.image!, fit: BoxFit.cover)
                  : Container(
                      color: Colors.grey.shade100,
                      child: Center(
                        child: Icon(
                          isLittleH
                              ? Icons.cake_rounded
                              : Icons.local_cafe_rounded,
                          size: 80.sp,
                          color: Colors.black12,
                        ),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36.r)),
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
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Text(
                          isLittleH ? "Little H" : "Teas N Trees",
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 18.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            widget.product.averageRating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    widget.product.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "₹$_currentPrice",
                    style: GoogleFonts.poppins(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    "Description",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    widget.product.description ??
                        "A premium handcrafted experience made with the finest ingredients and passion.",
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      height: 1.6.h,
                      fontSize: 14.sp,
                    ),
                  ),
                  if (widget.product.sizeOptions.isNotEmpty) ...[
                    SizedBox(height: 24.h),
                    Text(
                      "Select Size",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 12,
                      children: widget.product.sizeOptions.map((opt) {
                        final isSelected = _selectedSize == opt.size;
                        return TactileButton(
                          onTap: () => setState(() => _selectedSize = opt.size),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? themeColor : Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: isSelected
                                    ? themeColor
                                    : Colors.grey.shade200,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: themeColor.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              opt.size,
                              style: GoogleFonts.poppins(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (isLittleH &&
                      widget.product.cakePricing?.egglessAvailable == true) ...[
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Eggless Option",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                            ),
                            Text(
                              "+ ₹${widget.product.cakePricing!.egglessExtraCharge}",
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _isEggless,
                          activeTrackColor: themeColor,
                          onChanged: (val) => setState(() => _isEggless = val),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 24.h),
                  Text(
                    "Special Instructions",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _customizationController,
                    decoration: InputDecoration(
                      hintText: "Add any special requests...",
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        color: Colors.black26,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 120.h), // Space for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(themeColor),
    );
  }

  Widget _buildBottomAction(Color themeColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 56.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (_quantity > 1) setState(() => _quantity--);
                  },
                  icon: Icon(
                    Icons.remove_rounded,
                    size: 20.sp,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "$_quantity",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _quantity++),
                  icon: Icon(
                    Icons.add_rounded,
                    size: 20.sp,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: TactileButton(
              onTap: () {
                final List<String> customizations = [];
                if (_selectedSize != null) {
                  customizations.add("Size: $_selectedSize");
                }
                if (_isEggless) customizations.add("Eggless");
                if (_customizationController.text.isNotEmpty) {
                  customizations.add(_customizationController.text.trim());
                }

                final messenger = ScaffoldMessenger.of(context);
                final productName = widget.product.name;

                // Fire-and-reconcile: the cart updates optimistically, so don't
                // make the user watch a spinner for a round-trip.
                ref
                    .read(cartProvider.notifier)
                    .addToCart(
                      product: widget.product,
                      quantity: _quantity,
                      customization: customizations.isNotEmpty
                          ? customizations.join(", ")
                          : null,
                    )
                    .catchError((_) {
                      messenger.removeCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            "Couldn't add $productName. Please try again.",
                          ),
                          backgroundColor: Colors.redAccent.shade400,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.all(20),
                        ),
                      );
                    });

                SnackBarUtils.showThemedSnackBar(
                  context: context,
                  message: "Added to your bag!",
                );
                Navigator.pop(context);
              },
              child: Container(
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
                  "Add to Bag - ₹${_currentPrice * _quantity}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
