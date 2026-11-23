import 'package:tnt_lh/core/spacing.dart';
import 'package:tnt_lh/core/responsive.dart';
import 'package:tnt_lh/core/brand.dart';
import 'package:flutter/material.dart';
import 'package:tnt_lh/widgets/app_sheets.dart';
import 'package:tnt_lh/widgets/motion.dart';
import 'package:tnt_lh/utils/formatters.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/wishlist_provider.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';
import 'package:tnt_lh/widgets/product_image.dart';

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
    final themeColor = Theme.of(context).colorScheme.primary;

    if (Responsive.isExpanded(context)) {
      return _buildTwoPane(isLittleH, themeColor);
    }

    return CenteredPage(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              // About a third of the screen: at 400 the photo took nearly
              // half of it and pushed the name, price and options down.
              expandedHeight: (MediaQuery.sizeOf(context).height * 0.36).clamp(
                240.0,
                340.0,
              ),
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: _buildBackButton(),
              actions: [
                _buildFavButton(),
                SizedBox(width: 8.w),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: ProductImage(
                  url: widget.product.image,
                  isLittleH: isLittleH,
                  iconSize: 80,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildDetailsPanel(themeColor)),
          ],
        ),
        bottomSheet: _buildBottomAction(themeColor),
      ),
    );
  }

  /// Height of the bottom action bar: its vertical padding + the 56h button,
  /// plus whatever the OS reserves at the bottom (gesture bar / nav bar).
  double get _bottomActionHeight =>
      16.h + 48.h + 24.h + MediaQuery.of(context).viewPadding.bottom;

  Widget _buildBackButton() => Padding(
    padding: EdgeInsets.all(8.0.r),
    child: TactileButton(
      onTap: () => Navigator.pop(context),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Icon(
          PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
          color: Colors.black,
          size: 24.sp,
        ),
      ),
    ),
  );

  Widget _buildFavButton() => Padding(
    padding: EdgeInsets.all(8.0.r),
    child: Consumer(
      builder: (context, ref, child) {
        final isFav = ref
            .watch(wishlistProvider)
            .maybeWhen(
              data: (list) => list.any((p) => p.id == widget.product.id),
              orElse: () => false,
            );
        return Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: isFav ? 'Remove from wishlist' : 'Add to wishlist',
            onPressed: () async {
              HapticFeedback.selectionClick();
              try {
                await ref
                    .read(wishlistProvider.notifier)
                    .toggleFavorite(widget.product);
              } catch (_) {
                if (context.mounted) {
                  noticeSheet(
                    context,
                    message: "Couldn't update your wishlist. Please try again.",
                  );
                }
              }
            },
            icon: PopOnActivate(
              active: isFav,
              child: Icon(
                isFav
                    ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                    : PhosphorIcons.heart(),
                color: isFav ? Colors.redAccent : Colors.black,
                size: 22.sp,
              ),
            ),
          ),
        );
      },
    ),
  );

  bool get isLittleH => widget.product.brand == 'littleh';

  Widget _buildDetailsPanel(Color themeColor) => Container(
    padding: EdgeInsets.fromLTRB(
      Space.md.w,
      Space.ml.h,
      Space.md.w,
      Space.md.h,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                isLittleH ? Brands.bakeryName : Brands.cafeName,
                style: Brands.nameStyle(
                  isLittleH ? Brands.bakeryName : Brands.cafeName,
                  GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
              ),
            ),
            // "★ 0.0" on every new dish read as "rated zero".
            if (widget.product.averageRating > 0)
              Row(
                children: [
                  Icon(
                    PhosphorIcons.star(PhosphorIconsStyle.fill),
                    color: Colors.amber,
                    size: 16.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    widget.product.averageRating.toStringAsFixed(1),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: Space.sm.h),
        Text(
          widget.product.name,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22.sp,
            height: 1.2,
          ),
        ),
        SizedBox(height: Space.xxs.h),
        Text(
          AppFormatters.rupees(_currentPrice),
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: themeColor,
          ),
        ),
        // Only when there is one. A "Description" heading over an
        // empty space looked broken, and the old stand-in copy
        // described every dish the same way.
        if ((widget.product.description ?? '').trim().isNotEmpty) ...[
          SizedBox(height: Space.sm.h),
          Text(
            widget.product.description!.trim(),
            style: GoogleFonts.poppins(
              color: Colors.black54,
              height: 1.5,
              fontSize: 14.sp,
            ),
          ),
        ],
        if (widget.product.sizeOptions.isNotEmpty) ...[
          SizedBox(height: Space.ml.h),
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
                      color: isSelected ? themeColor : Colors.grey.shade200,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    opt.size,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.black87,
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
          SizedBox(height: Space.ml.h),
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
                    "+ ${AppFormatters.rupees(widget.product.cakePricing!.egglessExtraCharge)}",
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
        SizedBox(height: Space.ml.h),
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
        // The action bar is a bottomSheet, so it overlays the scroll
        // content. Reserve exactly its height (top pad + button +
        // bottom pad) plus the system inset, rather than a magic 120
        // that silently breaks if the bar changes.
        SizedBox(height: _bottomActionHeight),
      ],
    ),
  );

  /// Landscape tablets: photo on the left, details and the add button on the
  /// right, instead of a phone layout stretched across the screen.
  Widget _buildTwoPane(bool isLittleH, Color themeColor) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(
                        url: widget.product.image,
                        isLittleH: isLittleH,
                        iconSize: 80,
                      ),
                      Positioned(top: 8, left: 8, child: _buildBackButton()),
                      Positioned(top: 8, right: 8, child: _buildFavButton()),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildDetailsPanel(themeColor),
                    ),
                  ),
                  _buildBottomAction(themeColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(Color themeColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        Space.md.w,
        Space.sm.h,
        Space.md.w,
        Space.sm.h + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Consumer(
        builder: (context, ref, _) {
          // What's already in the bag, so "- 1 +" reads as "how many more"
          // and not as the bag's quantity.
          final inBag = ref.watch(
            cartProvider.select(
              (c) => (c.value?.items ?? const [])
                  .where((i) => i.product.id == widget.product.id)
                  .fold<int>(0, (n, i) => n + i.quantity),
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inBag > 0)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
                  child: Text(
                    '$inBag in your bag',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: themeColor,
                    ),
                  ),
                ),
              Row(
                children: [
                  Container(
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_quantity > 1) setState(() => _quantity--);
                          },
                          icon: Icon(
                            PhosphorIcons.minus(PhosphorIconsStyle.bold),
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
                            PhosphorIcons.plus(PhosphorIconsStyle.bold),
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
                          customizations.add(
                            _customizationController.text.trim(),
                          );
                        }

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
                            // The cart's error listener already explains a
                            // failed add (in a sheet), wherever the customer is.
                            .catchError((_) {});

                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 48.h,
                        // The store's colour, as on the bag's Place order. Black
                        // here and brand colour there felt like two apps.
                        decoration: BoxDecoration(
                          color: themeColor,
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "Add${ref.watch(cartProvider.select((c) => (c.value?.items ?? const []).any((i) => i.product.id == widget.product.id))) ? ' $_quantity more' : ' to bag'} · ${AppFormatters.rupees(_currentPrice * _quantity)}",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
