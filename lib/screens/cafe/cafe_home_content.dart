import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/product_provider.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/utils/cart_error_listener.dart';
import 'package:tnt_lh/providers/wishlist_provider.dart';
import 'package:tnt_lh/screens/cafe/cafe_item_details_screen.dart';
import 'package:tnt_lh/screens/wishlist_screen.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';
import 'package:tnt_lh/widgets/product_image.dart';
import 'package:tnt_lh/widgets/skeleton.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

class BrandHomeContent extends ConsumerStatefulWidget {
  final String brand; // 'teasntrees' or 'littleh'
  final VoidCallback? onSwitchStore;
  const BrandHomeContent({super.key, required this.brand, this.onSwitchStore});

  @override
  ConsumerState<BrandHomeContent> createState() => _BrandHomeContentState();
}

class _BrandHomeContentState extends ConsumerState<BrandHomeContent>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = -1; // -1 for "All"
  String? _selectedCategoryId;
  String _searchQuery = "";

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late AnimationController _floatController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _floatController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
    });
  }

  void _onCategorySelected(int index, String? id) {
    setState(() {
      _selectedCategoryIndex = index;
      _selectedCategoryId = id;
      _searchQuery = "";
      _searchController.clear();
    });
  }

  void _openCategorySheet(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  SizedBox(height: 12.h),
                  Container(
                    width: 40.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(24.0.r),
                    child: Text(
                      "Explore Categories",
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final isSelected = _selectedCategoryId == cat.id;
                        return TactileButton(
                          onTap: () {
                            Navigator.pop(context);
                            _onCategorySelected(index, cat.id);
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.3)
                                            : Colors.black.withValues(
                                                alpha: 0.03,
                                              ),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: cat.image != null
                                        ? Padding(
                                            padding: EdgeInsets.all(12.0.r),
                                            child: Image.network(
                                              cat.image!,
                                              errorBuilder: (_, _, _) => Icon(
                                                PhosphorIcons.squaresFour(),
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black54,
                                                size: 24.sp,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            PhosphorIcons.squaresFour(),
                                            size: 30.sp,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black54,
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                cat.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _openAddToCartSheet(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      builder: (_) => AddToCartSheet(product: product),
    );
  }

  void _handleQuickAdd(Product product) {
    // Open the options sheet only when there is a real choice to make — any
    // choice that changes the price must be explicit before it hits the cart.
    final bool hasSizeOptions = product.sizeOptions.isNotEmpty;

    final cake = product.cakePricing;

    // A real cake is priced per kilogram, so weight (and often customization)
    // must be chosen. Every product carries a default `cakePricing` sub-doc,
    // so its mere presence proves nothing — basePricePerKg does.
    final bool isCake = cake != null && cake.basePricePerKg > 0;

    // Eggless only makes sense for bakery items. NOTE: `egglessAvailable`
    // defaults to true on EVERY product in the backend schema (drinks
    // included), so it cannot be trusted alone — the brand check is what
    // actually gates this. See the schema TODO: eggless should be an explicit
    // per-product flag with its own surcharge.
    final bool offersEggless =
        product.brand == 'littleh' && cake != null && cake.egglessAvailable;

    if (hasSizeOptions || isCake || offersEggless) {
      _openAddToCartSheet(context, product);
      return;
    }

    // Direct add. The cart provider updates optimistically, so the bag badge
    // and this confirmation land immediately; a failure rolls back and tells
    // the user rather than silently leaving a phantom item.
    SnackBarUtils.showThemedSnackBar(
      context: context,
      message: "${product.name} added to bag!",
    );
    _addDirectly(product);
  }

  Future<void> _addDirectly(Product product) async {
    try {
      await ref
          .read(cartProvider.notifier)
          .addToCart(product: product, quantity: 1);
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: "Couldn't add ${product.name}. Please try again.",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    listenForCartErrors(ref, context);
    final categoriesAsync = ref.watch(categoriesProvider(widget.brand));
    final productsAsync = ref.watch(
      productsProvider(
        ProductParams(
          categoryId: _selectedCategoryId,
          search: _searchQuery.isEmpty ? null : _searchQuery,
          brand: widget.brand,
        ),
      ),
    );

    final isLittleH = widget.brand == 'littleh';
    final brandTitle = isLittleH ? "Little H" : "Teas N Trees";

    // --- SMART GREETING LOGIC ---
    final hour = DateTime.now().hour;

    String greeting;
    String timeBasedSubtitle;

    if (hour < 12) {
      greeting = isLittleH ? "Fresh from the Oven" : "Good Morning";
      timeBasedSubtitle = isLittleH
          ? "Start your day with warm, freshly baked goodness."
          : "A fresh start to your morning, just for you.";
    } else if (hour < 17) {
      greeting = isLittleH ? "Midday Bakes" : "Good Afternoon";
      timeBasedSubtitle = isLittleH
          ? "Perfect time for a fresh snack or pastry."
          : "Take a break and enjoy something delicious.";
    } else {
      greeting = isLittleH ? "Evening Treats" : "Good Evening";
      timeBasedSubtitle = isLittleH
          ? "End your day with something warm and sweet."
          : "Relax and enjoy your evening snack.";
    }
    final heroTitle = greeting;
    final heroSubtitle = timeBasedSubtitle;
    // ----------------------------

    final logoAsset = isLittleH
        ? "assets/images/little_h_logo_no_bg.png"
        : "assets/images/teas_n_trees_no_bg.png";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        // The Little H wordmark was crammed into the default ~56px leading slot,
        // so it rendered tiny and clipped. Give it real width + a fixed height.
        leadingWidth: isLittleH ? 132.w : 72.w,
        leading: Padding(
          padding: EdgeInsets.only(left: 16.0, top: 10.h, bottom: 10.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              logoAsset,
              height: 40.h,
              fit: BoxFit.contain,
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          brandTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.black87,
            fontSize: 20.sp,
          ),
        ),
        actions: [
          TactileButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WishlistScreen()),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(8.0.r),
              child: Consumer(
                builder: (context, ref, _) {
                  // Count of saved items so the heart carries a live badge,
                  // matching the bag. Reads the same wishlistProvider the
                  // product cards toggle, so it updates instantly.
                  final count = ref
                      .watch(wishlistProvider)
                      .maybeWhen(data: (list) => list.length, orElse: () => 0);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        count > 0
                            ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                            : PhosphorIcons.heart(),
                        color: count > 0 ? const Color(0xFFE5484D) : Colors.black87,
                        size: 24.sp,
                      ),
                      if (count > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: EdgeInsets.all(4.r),
                            constraints: BoxConstraints(
                              minWidth: 16.w,
                              minHeight: 16.w,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE5484D),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Premium Creative Hero Section
                            TweenAnimationBuilder<double>(
                              duration: Duration(milliseconds: 1000),
                              tween: Tween<double>(begin: 0, end: 1),
                              curve: Curves.easeOutQuart,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                // A horizontal fling on the hero is a second,
                                // discoverable path to switch stores (besides
                                // the centre button). Safe here — the hero is a
                                // fixed banner above the scrolling content.
                                onHorizontalDragEnd: (details) {
                                  final v = details.primaryVelocity ?? 0;
                                  if (v.abs() > 250) widget.onSwitchStore?.call();
                                },
                                child: Container(
                                  width: double.infinity,
                                  // Min-height rather than a fixed height: the
                                  // hero stays compact but grows instead of
                                  // overflowing when text (or the user's font
                                  // scale) needs more room.
                                  constraints: BoxConstraints(minHeight: 150.h),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36.r),
                                  gradient: LinearGradient(
                                    colors: [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(context).colorScheme.secondary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 30,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(36.r),
                                  child: Stack(
                                    children: [
                                      // Subtle Animated Background Elements
                                      _buildFloatingShape(
                                        left: -20,
                                        top: -20,
                                        size: 100.sp,
                                      ),
                                      _buildFloatingShape(
                                        right: 40,
                                        bottom: -30,
                                        size: 80.sp,
                                      ),
                                      _buildFloatingShape(
                                        right: -10,
                                        top: 20,
                                        size: 60.sp,
                                      ),

                                      Padding(
                                        padding: EdgeInsets.all(16.0.r),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Cute Badge
                                            ScaleTransition(
                                              scale: Tween<double>(
                                                begin: 1.0,
                                                end: 1.05,
                                              ).animate(_pulseController),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12.w,
                                                  vertical: 6.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        20.r,
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isLittleH
                                                          ? Icons
                                                                .favorite_rounded
                                                          : PhosphorIcons.leaf(PhosphorIconsStyle.duotone),
                                                      color: Colors.white,
                                                      size: 14.sp,
                                                    ),
                                                    SizedBox(width: 6.w),
                                                    Text(
                                                      isLittleH
                                                          ? "Handcrafted"
                                                          : "Purely Organic",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: Colors.white,
                                                            fontSize: 11.sp,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 16.h),
                                            Text(
                                              heroTitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.1.h,
                                                  ),
                                            ),
                                            SizedBox(height: 8.h),
                                            SizedBox(
                                              width: 220.w,
                                              child: Text(
                                                heroSubtitle,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14.sp,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  height: 1.4.h,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Cute floating element on the right
                                      Positioned(
                                        right: 20,
                                        bottom: 30,
                                        child: RotationTransition(
                                          turns: Tween<double>(
                                            begin: -0.02,
                                            end: 0.02,
                                          ).animate(_pulseController),
                                          child: Icon(
                                            isLittleH
                                                ? PhosphorIcons.bread(PhosphorIconsStyle.duotone)
                                                : PhosphorIcons.coffee(PhosphorIconsStyle.duotone),
                                            size: 100.sp,
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            ),

                            SizedBox(height: 20.h),

                            /// Redesigned Search Bar
                            Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 15,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: isLittleH
                                      ? "Search our bakery..."
                                      : "Find your perfect drink...",
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.black26,
                                    fontSize: 14.sp,
                                  ),
                                  prefixIcon: Icon(
                                    PhosphorIcons.magnifyingGlass(),
                                    color: Colors.black45,
                                    size: 20.sp,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            PhosphorIcons.x(PhosphorIconsStyle.bold),
                                            size: 18.sp,
                                            color: Colors.black45,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16.h,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 20.h),

                            /// Categories Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Explore Menu",
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                        fontSize: 18.sp,
                                      ),
                                ),
                                TactileButton(
                                  onTap: () {
                                    categoriesAsync.whenData(
                                      (categories) =>
                                          _openCategorySheet(categories),
                                    );
                                  },
                                  child: Text(
                                    "See All",
                                    style: GoogleFonts.poppins(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 20.h),

                            /// Modern Category List
                            SizedBox(
                              height: 110.h,
                              child: categoriesAsync.when(
                                loading: () => Center(
                                  child: CircularProgressIndicator(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    strokeWidth: 3,
                                  ),
                                ),
                                error: (err, _) =>
                                    Center(child: Text('Error: $err')),
                                data: (categories) {
                                  return ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount:
                                        (categories.length > 6
                                            ? 6
                                            : categories.length) +
                                        1,
                                    separatorBuilder: (_, _) =>
                                        SizedBox(width: 20.w),
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        final isSelected =
                                            _selectedCategoryIndex == -1;
                                        return _buildCategoryItem(
                                          "All",
                                          null,
                                          isSelected,
                                          () => _onCategorySelected(-1, null),
                                          PhosphorIcons.squaresFour(),
                                        );
                                      }

                                      final cat = categories[index - 1];
                                      final isSelected =
                                          _selectedCategoryIndex == (index - 1);
                                      return _buildCategoryItem(
                                        cat.name,
                                        cat.image,
                                        isSelected,
                                        () => _onCategorySelected(
                                          index - 1,
                                          cat.id,
                                        ),
                                        isLittleH
                                            ? PhosphorIcons.cake(PhosphorIconsStyle.duotone)
                                            : PhosphorIcons.coffee(PhosphorIconsStyle.duotone),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            SizedBox(height: 16.h),
                            Text(
                              _selectedCategoryIndex == -1
                                  ? "Freshly Prepared"
                                  : "Selected for You",
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 18.sp,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: RefreshIndicator(
                  onRefresh: _refresh,
                  color: Theme.of(context).colorScheme.primary,
                  child: productsAsync.when(
                    loading: () => const ProductListSkeleton(),
                    error: (err, _) => _pullableMessage(
                      icon: PhosphorIcons.wifiSlash(),
                      message: "Couldn't load items.\nPull down to try again.",
                    ),
                    data: (products) {
                      if (products.isEmpty) {
                        // Say why it's empty and offer the way out, rather than
                        // a dead end: a search miss can be cleared, a category
                        // filter can be widened.
                        final searching = _searchQuery.trim().isNotEmpty;
                        final filtered = _selectedCategoryId != null;

                        if (searching) {
                          return _pullableMessage(
                            icon: PhosphorIcons.magnifyingGlass(),
                            message:
                                "Nothing matches \"$_searchQuery\".\nTry a different spelling or a broader word.",
                            actionLabel: "Clear search",
                            onAction: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          );
                        }
                        if (filtered) {
                          return _pullableMessage(
                            icon: PhosphorIcons.forkKnife(PhosphorIconsStyle.duotone),
                            message: "Nothing in this category yet.",
                            actionLabel: "Browse everything",
                            onAction: () => _onCategorySelected(-1, null),
                          );
                        }
                        return _pullableMessage(
                          icon: PhosphorIcons.forkKnife(PhosphorIconsStyle.duotone),
                          message:
                              "No items found in this section.\nPull down to refresh.",
                        );
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 100.h),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => SizedBox(height: 16.h),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return TweenAnimationBuilder<double>(
                            duration: Duration(
                              milliseconds: 400 + (index * 100),
                            ),
                            tween: Tween<double>(begin: 0, end: 1),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildProductCard(product),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Re-fetches categories and products for the current selection. Invalidating
  /// the providers is what makes the screen recoverable — a FutureProvider
  /// otherwise caches an empty/failed result until the app is restarted.
  Future<void> _refresh() async {
    final params = ProductParams(
      categoryId: _selectedCategoryId,
      search: _searchQuery.isEmpty ? null : _searchQuery,
      brand: widget.brand,
    );
    ref.invalidate(categoriesProvider(widget.brand));
    ref.invalidate(productsProvider(params));
    // Await the new fetch so the refresh spinner tracks real work.
    await ref.read(productsProvider(params).future);
  }

  /// An empty/error state that is still scrollable, so pull-to-refresh works
  /// even when there is nothing to scroll.
  Widget _pullableMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64.sp, color: Colors.black12),
                SizedBox(height: 16.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.black38),
                ),
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: 20.h),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingShape({
    double? left,
    double? top,
    double? right,
    double? bottom,
    required double size,
  }) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 15 * _floatController.value),
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(
    String name,
    String? image,
    bool isSelected,
    VoidCallback onTap,
    IconData fallbackIcon,
  ) {
    return TactileButton(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: 68.h,
            width: 68.w,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                width: 1.w,
              ),
            ),
            child: Center(
              child: image != null
                  ? Padding(
                      padding: EdgeInsets.all(16.0.r),
                      child: Image.network(
                        image,
                        color: isSelected ? Colors.white : Colors.black87,
                        errorBuilder: (_, _, _) => Icon(
                          fallbackIcon,
                          color: isSelected ? Colors.white : Colors.black87,
                          size: 24.sp,
                        ),
                      ),
                    )
                  : Icon(
                      fallbackIcon,
                      color: isSelected ? Colors.white : Colors.black87,
                      size: 26.sp,
                    ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.black : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLittleH = widget.brand == 'littleh';

    return Consumer(
      builder: (context, ref, child) {
        final cartAsync = ref.watch(cartProvider);
        int cartQty = 0;
        String? cartItemId;

        cartAsync.whenData((cart) {
          final existing = cart.items
              .where((i) => i.product.id == product.id)
              .toList();
          if (existing.isNotEmpty) {
            cartQty = existing.fold(0, (sum, item) => sum + item.quantity);
            cartItemId = existing.first.id;
          }
        });

        return TactileButton(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItemDetailsScreen(product: product),
              ),
            );
          },
          child: Container(
            height: 145.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
            ),
            child: Row(
              children: [
                Hero(
                  tag: product.id,
                  child: Container(
                    width: 135.w,
                    margin: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26.r),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26.r),
                      child: Stack(
                        children: [
                          ProductImage(
                            url: product.image,
                            isLittleH: isLittleH,
                            iconSize: 40,
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Consumer(
                              builder: (context, ref, child) {
                                final wishlistState = ref.watch(
                                  wishlistProvider,
                                );
                                final isFav = wishlistState.maybeWhen(
                                  data: (list) =>
                                      list.any((p) => p.id == product.id),
                                  orElse: () => false,
                                );
                                return TactileButton(
                                  onTap: () => ref
                                      .read(wishlistProvider.notifier)
                                      .toggleFavorite(product),
                                  child: Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.1,
                                          ),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isFav
                                          ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                                          : PhosphorIcons.heart(),
                                      size: 16.sp,
                                      color: isFav
                                          ? Colors.redAccent
                                          : Colors.black54,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          product.description ??
                              "Handcrafted with passion and care",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.black38,
                            fontSize: 12.sp,
                            height: 1.3.h,
                          ),
                        ),
                        Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "₹${product.displayPrice}",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.sp,
                                color: Colors.black87,
                              ),
                            ),
                            if (cartQty > 0)
                              Container(
                                height: 32.h,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        if (cartItemId != null) {
                                          if (cartQty == 1) {
                                            ref
                                                .read(cartProvider.notifier)
                                                .removeItem(
                                                  cartItemId!,
                                                  brand: product.brand,
                                                );
                                          } else {
                                            ref
                                                .read(cartProvider.notifier)
                                                .updateQuantity(
                                                  cartItemId!,
                                                  cartQty - 1,
                                                );
                                          }
                                        }
                                      },
                                      icon: Icon(PhosphorIcons.minus(PhosphorIconsStyle.bold), size: 14.sp),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(minWidth: 30),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    Text(
                                      "$cartQty",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.sp,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        if (cartItemId != null) {
                                          ref
                                              .read(cartProvider.notifier)
                                              .updateQuantity(
                                                cartItemId!,
                                                cartQty + 1,
                                              );
                                        }
                                      },
                                      icon: Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), size: 14.sp),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(minWidth: 30),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              )
                            else
                              TactileButton(
                                onTap: () => _handleQuickAdd(product),
                                child: Container(
                                  height: 42.h,
                                  width: 42.w,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    PhosphorIcons.plus(PhosphorIconsStyle.bold),
                                    color: Colors.white,
                                    size: 24.sp,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddToCartSheet extends ConsumerStatefulWidget {
  final Product product;
  const AddToCartSheet({super.key, required this.product});

  @override
  ConsumerState<AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<AddToCartSheet> {
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

  void _addToCart() {
    final List<String> customizations = [];
    if (_selectedSize != null) customizations.add("Size: $_selectedSize");
    if (_isEggless) customizations.add("Eggless");
    if (_customizationController.text.isNotEmpty) {
      customizations.add(_customizationController.text.trim());
    }
    final customization = customizations.isNotEmpty
        ? customizations.join(", ")
        : null;

    // Captured before popping — the sheet's context is gone afterwards.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(cartProvider.notifier);
    final productName = widget.product.name;

    // Confirm and close immediately. The cart updates optimistically, so
    // awaiting the network here just froze the sheet for a couple of seconds.
    SnackBarUtils.showThemedSnackBar(
      context: context,
      message: "$productName has been added to your bag!",
    );
    Navigator.pop(context);

    // Reconcile in the background; surface a failure instead of swallowing it.
    notifier
        .addToCart(
          product: widget.product,
          quantity: _quantity,
          customization: customization,
        )
        .catchError((_) {
          messenger.removeCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text("Couldn't add $productName. Please try again."),
              backgroundColor: Colors.redAccent.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(20),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final isLittleH = widget.product.brand == 'littleh';

    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Add to Bag",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                  color: Colors.black26,
                  size: 24.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Container(
                height: 80.h,
                width: 80.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: widget.product.image != null
                      ? Image.network(widget.product.image!, fit: BoxFit.cover)
                      : Icon(PhosphorIcons.forkKnife(PhosphorIconsStyle.duotone)),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                    Text(
                      "₹$_currentPrice",
                      style: GoogleFonts.poppins(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.product.sizeOptions.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Text(
              "Select Size",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 10,
              children: widget.product.sizeOptions.map((opt) {
                final isSelected = _selectedSize == opt.size;
                return TactileButton(
                  onTap: () => setState(() => _selectedSize = opt.size),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? themeColor : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected ? themeColor : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      opt.size,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          if (isLittleH &&
              widget.product.cakePricing?.egglessAvailable == true) ...[
            SizedBox(height: 20.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Eggless Option (+₹${widget.product.cakePricing!.egglessExtraCharge})",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
                Switch.adaptive(
                  value: _isEggless,
                  activeTrackColor: themeColor,
                  onChanged: (val) => setState(() => _isEggless = val),
                ),
              ],
            ),
          ],

          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Quantity",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_quantity > 1) setState(() => _quantity--);
                      },
                      icon: Icon(
                        PhosphorIcons.minus(PhosphorIconsStyle.bold),
                        size: 18.sp,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "$_quantity",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: Icon(
                        PhosphorIcons.plus(PhosphorIconsStyle.bold),
                        size: 18.sp,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),
          TactileButton(
            onTap: _addToCart,
            child: Container(
              height: 48.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: Offset(0, 6),
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
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}
