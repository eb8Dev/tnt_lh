import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/product_provider.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/wishlist_provider.dart';
import 'package:tnt_lh/screens/cafe/cafe_item_details_screen.dart';
import 'package:tnt_lh/screens/wishlist_screen.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

class BrandHomeContent extends ConsumerStatefulWidget {
  final String brand; // 'teasntrees' or 'littleh'
  const BrandHomeContent({super.key, required this.brand});

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
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
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
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: cat.image != null
                                        ? Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Image.network(
                                              cat.image!,
                                              errorBuilder: (_, _, _) => Icon(
                                                Icons.grid_view_rounded,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black54,
                                                size: 24,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.grid_view_rounded,
                                            size: 30,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black54,
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                cat.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => AddToCartSheet(product: product),
    );
  }

  void _handleQuickAdd(Product product) {
    // If product has options, show the sheet
    final bool hasSizeOptions = product.sizeOptions.isNotEmpty;
    final bool hasEgglessOption =
        product.brand == 'littleh' &&
        product.cakePricing != null &&
        product.cakePricing!.egglessAvailable;

    if (hasSizeOptions || hasEgglessOption) {
      _openAddToCartSheet(context, product);
    } else {
      // Direct add to cart
      ref
          .read(cartProvider.notifier)
          .addToCart(productId: product.id, quantity: 1, brand: product.brand);
      SnackBarUtils.showThemedSnackBar(
        context: context,
        message: "${product.name} added to bag!",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(logoAsset, fit: BoxFit.contain),
        ),
        centerTitle: true,
        title: Text(
          brandTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: Colors.black87, fontSize: 20),
        ),
        actions: [
          TactileButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistScreen()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.favorite_border_rounded,
                color: Colors.black87,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// Premium Creative Hero Section
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1000),
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
                              child: Container(
                                width: double.infinity,
                                height: 190,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36),
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
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(36),
                                  child: Stack(
                                    children: [
                                      // Subtle Animated Background Elements
                                      _buildFloatingShape(
                                        left: -20,
                                        top: -20,
                                        size: 100,
                                      ),
                                      _buildFloatingShape(
                                        right: 40,
                                        bottom: -30,
                                        size: 80,
                                      ),
                                      _buildFloatingShape(
                                        right: -10,
                                        top: 20,
                                        size: 60,
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.all(28.0),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isLittleH
                                                          ? Icons
                                                                .favorite_rounded
                                                          : Icons.spa_rounded,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isLittleH
                                                          ? "Handcrafted"
                                                          : "Purely Organic",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              heroTitle,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    height: 1.1,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 220,
                                              child: Text(
                                                heroSubtitle,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  height: 1.4,
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
                                                ? Icons.bakery_dining_rounded
                                                : Icons.local_cafe_rounded,
                                            size: 100,
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

                            const SizedBox(height: 32),

                            /// Redesigned Search Bar
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
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
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: Colors.black45,
                                    size: 20,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: Colors.black45,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 36),

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
                                        fontSize: 18,
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            /// Modern Category List
                            SizedBox(
                              height: 110,
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
                                        const SizedBox(width: 20),
                                    itemBuilder: (context, index) {
                                      if (index == 0) {
                                        final isSelected =
                                            _selectedCategoryIndex == -1;
                                        return _buildCategoryItem(
                                          "All",
                                          null,
                                          isSelected,
                                          () => _onCategorySelected(-1, null),
                                          Icons.grid_view_rounded,
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
                                            ? Icons.cake_rounded
                                            : Icons.local_cafe_rounded,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),
                            Text(
                              _selectedCategoryIndex == -1
                                  ? "Freshly Prepared"
                                  : "Selected for You",
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 18,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: productsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 3,
                    ),
                  ),
                  error: (err, _) => Center(child: Text("Error: $err")),
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.fastfood_rounded,
                              size: 64,
                              color: Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No items found in this section",
                              style: GoogleFonts.poppins(color: Colors.black38),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 20),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + (index * 100)),
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
          ],
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
            duration: const Duration(milliseconds: 300),
            height: 68,
            width: 68,
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
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                width: 1,
              ),
            ),
            child: Center(
              child: image != null
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Image.network(
                        image,
                        color: isSelected ? Colors.white : Colors.black87,
                        errorBuilder: (_, _, _) => Icon(
                          fallbackIcon,
                          color: isSelected ? Colors.white : Colors.black87,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      fallbackIcon,
                      color: isSelected ? Colors.white : Colors.black87,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 12,
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
            height: 145,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
            ),
            child: Row(
              children: [
                Hero(
                  tag: product.id,
                  child: Container(
                    width: 135,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Stack(
                        children: [
                          product.image != null && product.image!.isNotEmpty
                              ? Image.network(
                                  product.image!,
                                  fit: BoxFit.cover,
                                  height: double.infinity,
                                  width: double.infinity,
                                )
                              : Center(
                                  child: Icon(
                                    isLittleH
                                        ? Icons.cake_rounded
                                        : Icons.local_cafe_rounded,
                                    size: 40,
                                    color: Colors.black12,
                                  ),
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
                                    padding: const EdgeInsets.all(8),
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
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 16,
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
                    padding: const EdgeInsets.fromLTRB(12, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.description ??
                              "Handcrafted with passion and care",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.black38,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "₹${product.displayPrice}",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            if (cartQty > 0)
                              Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
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
                                      icon: const Icon(Icons.remove, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                      ),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    Text(
                                      "$cartQty",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
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
                                      icon: const Icon(Icons.add, size: 14),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 30,
                                      ),
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
                                  height: 42,
                                  width: 42,
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
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 24,
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

  Future<void> _addToCart() async {
    try {
      final List<String> customizations = [];
      if (_selectedSize != null) customizations.add("Size: $_selectedSize");
      if (_isEggless) customizations.add("Eggless");
      if (_customizationController.text.isNotEmpty) {
        customizations.add(_customizationController.text.trim());
      }

      await ref
          .read(cartProvider.notifier)
          .addToCart(
            productId: widget.product.id,
            quantity: _quantity,
            brand: widget.product.brand,
            customization: customizations.isNotEmpty
                ? customizations.join(", ")
                : null,
          );

      if (mounted) {
        Navigator.pop(context);
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "${widget.product.name} has been added to your bag!",
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(
          context: context,
          message: "Error: $e",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final isLittleH = widget.product.brand == 'littleh';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.black26,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.product.image != null
                      ? Image.network(widget.product.image!, fit: BoxFit.cover)
                      : const Icon(Icons.fastfood),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "₹$_currentPrice",
                      style: GoogleFonts.poppins(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.product.sizeOptions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              "Select Size",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: widget.product.sizeOptions.map((opt) {
                final isSelected = _selectedSize == opt.size;
                return TactileButton(
                  onTap: () => setState(() => _selectedSize = opt.size),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? themeColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? themeColor : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      opt.size,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Eggless Option (+₹${widget.product.cakePricing!.egglessExtraCharge})",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
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

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Quantity",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_quantity > 1) setState(() => _quantity--);
                      },
                      icon: const Icon(
                        Icons.remove_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "$_quantity",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _quantity++),
                      icon: const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          TactileButton(
            onTap: _addToCart,
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                "Add to Bag - ₹${_currentPrice * _quantity}",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
