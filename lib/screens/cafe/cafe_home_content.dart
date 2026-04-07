import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/product_provider.dart';
import 'package:tnt_lh/providers/wishlist_provider.dart';
import 'package:tnt_lh/screens/cafe/cafe_item_details_screen.dart';
import 'package:tnt_lh/screens/wishlist_screen.dart';

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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
                        return GestureDetector(
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
                                        ? const Color(0xFFA9BCA4)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFA9BCA4,
                                              ).withValues(alpha: 0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: cat.image != null
                                        ? Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Image.network(
                                              cat.image!,
                                              errorBuilder: (_, _, _) =>
                                                  Icon(
                                                    Icons.category,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.category,
                                            size: 30,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
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
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: Colors.black,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => AddToCartSheet(product: product),
    );
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
    final heroTitle = isLittleH ? "Baked with Heart" : "Brewed for You";
    final heroSubtitle = isLittleH
        ? "Artisanal treats fresh from our oven."
        : "Premium artisanal blends for your soul.";
    final logoAsset = isLittleH
        ? "assets/images/little_h_logo_no_bg.png"
        : "assets/images/teas_n_trees_no_bg.png";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Image.asset(logoAsset, fit: BoxFit.contain),
        ),
        centerTitle: true,
        title: Text(
          brandTitle,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WishlistScreen()),
              );
            },
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
                                height: 180,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFA9BCA4),
                                      Color(0xFF8E9E89),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFA9BCA4,
                                      ).withValues(alpha: 0.3),
                                      blurRadius: 25,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
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
                                                      horizontal: 10,
                                                      vertical: 4,
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
                                                      size: 12,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isLittleH
                                                          ? "Handcrafted"
                                                          : "Purely Organic",
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              heroTitle,
                                              style: GoogleFonts.poppins(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                height: 1.1,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 200,
                                              child: Text(
                                                heroSubtitle,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Cute floating element on the right
                                      Positioned(
                                        right: 30,
                                        bottom: 40,
                                        child: RotationTransition(
                                          turns: Tween<double>(
                                            begin: -0.02,
                                            end: 0.02,
                                          ).animate(_pulseController),
                                          child: Icon(
                                            isLittleH
                                                ? Icons.bakery_dining_rounded
                                                : Icons.local_cafe_rounded,
                                            size: 80,
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

                            const SizedBox(height: 28),

                            /// Redesigned Search Bar
                            Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.grey.shade100),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: isLittleH
                                      ? "Search our bakery..."
                                      : "Find your drink...",
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.black54,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            /// Categories Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Categories",
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                GestureDetector(
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
                                      color: const Color(0xFFA9BCA4),
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
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFA9BCA4),
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
                                            ? Icons.cake
                                            : Icons.local_cafe,
                                      );
                                    },
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 12),
                            Text(
                              _selectedCategoryIndex == -1
                                  ? "All Items"
                                  : "Popular Choice",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: productsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFA9BCA4)),
                  ),
                  error: (err, _) => Center(child: Text("Error: $err")),
                  data: (products) {
                    if (products.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.no_food_outlined,
                              size: 64,
                              color: Colors.grey.shade200,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "No items found",
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
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
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 200),
        tween: Tween<double>(begin: 1.0, end: isSelected ? 1.0 : 1.0),
        builder: (context, scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFA9BCA4)
                    : Colors.grey.shade50,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFA9BCA4).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: image != null
                    ? Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Image.network(
                          image,
                          color: isSelected ? Colors.white : Colors.black87,
                          errorBuilder: (_, _, _) => Icon(
                            fallbackIcon,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      )
                    : Icon(
                        fallbackIcon,
                        color: isSelected ? Colors.white : Colors.black87,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final isLittleH = widget.brand == 'littleh';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(product: product),
          ),
        );
      },
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Hero(
              tag: product.id,
              child: Container(
                width: 130,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                  color: Colors.grey.shade50,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      product.image != null && product.image!.isNotEmpty
                          ? Image.network(
                              product.image!,
                              fit: BoxFit.cover,
                              height: 130,
                              width: 130,
                            )
                          : Center(
                              child: Icon(
                                isLittleH ? Icons.cake : Icons.local_cafe,
                                size: 40,
                                color: Colors.grey.shade300,
                              ),
                            ),

                      // Favorite Toggle on Image
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final wishlistState = ref.watch(wishlistProvider);
                            final isFav = wishlistState.maybeWhen(
                              data: (list) =>
                                  list.any((p) => p.id == product.id),
                              orElse: () => false,
                            );

                            return GestureDetector(
                              onTap: () => ref
                                  .read(wishlistProvider.notifier)
                                  .toggleFavorite(product),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFav
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 18,
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description ?? "Experience the authentic taste",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade500,
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
                            color: Colors.black,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openAddToCartSheet(context, product),
                          child: Container(
                            height: 36,
                            width: 36,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
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
  }
}
