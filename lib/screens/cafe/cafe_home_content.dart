import 'package:tnt_lh/core/responsive.dart';
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
import 'package:tnt_lh/widgets/store_switcher.dart';
import 'package:tnt_lh/widgets/tactile_button.dart';
import 'package:tnt_lh/widgets/product_image.dart';
import 'package:tnt_lh/widgets/skeleton.dart';
import 'package:tnt_lh/utils/snack_bar_utils.dart';

class BrandHomeContent extends ConsumerStatefulWidget {
  final String brand; // 'teasntrees' or 'littleh'

  /// Called with the brand the user picked in the top store switcher.
  final ValueChanged<String>? onSelectStore;
  const BrandHomeContent({super.key, required this.brand, this.onSelectStore});

  @override
  ConsumerState<BrandHomeContent> createState() => _BrandHomeContentState();
}

class _BrandHomeContentState extends ConsumerState<BrandHomeContent> {
  int _selectedCategoryIndex = -1; // -1 for "All"
  String? _selectedCategoryId;
  String _searchQuery = "";

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Persistent controller for the horizontal category chip bar so its scroll
  // position survives the pinned header rebuilding on every vertical scroll.
  final ScrollController _categoryBarController = ScrollController();
  // Attached to whichever chip is currently selected, so we can scroll it into
  // view after a pick (especially one made from the Menu sheet, where the
  // chosen category may be far off-screen in the chip row).
  final GlobalKey _selectedChipKey = GlobalKey();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _categoryBarController.dispose();
    _debounce?.cancel();
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
    // Jump back to the top so the freshly filtered menu starts at item one
    // instead of wherever the previous category was scrolled to.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    // Bring the selected chip into view (near the left edge) so the customer
    // can always see what they just picked — the key problem when the choice
    // came from the Menu sheet and the chip was scrolled off the right.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedChipKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Pull the next page in slightly before the customer reaches the bottom so
  /// the long menu keeps flowing. Shared by the scroll listener.
  bool _onScrollNotification(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 600) {
      ref
          .read(
            productsProvider(
              ProductParams(
                categoryId: _selectedCategoryId,
                search: _searchQuery.isEmpty ? null : _searchQuery,
                brand: widget.brand,
              ),
            ).notifier,
          )
          .loadMore();
    }
    return false;
  }

  /// The Zomato-style "Menu" sheet: a scannable list of every category with its
  /// item count, so the customer can jump straight to a section instead of
  /// scrolling the whole catalogue. Tapping a row filters the menu to that
  /// category (and closes the sheet). Counts come from the backend; when a build
  /// predates that field they're simply omitted.
  void _openCategorySheet(List<Category> categories) {
    final primary = Theme.of(context).colorScheme.primary;
    final totalCount = categories.fold<int?>(0, (sum, c) {
      if (sum == null || c.productCount == null) return null;
      return sum + c.productCount!;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.92,
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
                    padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 12.h),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.forkKnife(PhosphorIconsStyle.fill),
                          color: primary,
                          size: 20.sp,
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          "Menu",
                          style: GoogleFonts.poppins(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.only(bottom: 12.h),
                      // +1 for the leading "All items" row.
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _menuRow(
                            label: "All items",
                            count: totalCount,
                            selected: _selectedCategoryId == null,
                            onTap: () {
                              Navigator.pop(sheetContext);
                              _onCategorySelected(-1, null);
                            },
                          );
                        }
                        final cat = categories[index - 1];
                        return _menuRow(
                          label: cat.name,
                          count: cat.productCount,
                          selected: _selectedCategoryId == cat.id,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            _onCategorySelected(index - 1, cat.id);
                          },
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

  /// One row of the menu sheet: category name on the left, item count on the
  /// right (Zomato style). The active category is tinted so it's easy to see
  /// where you are.
  Widget _menuRow({
    required String label,
    required int? count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return TactileButton(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 15.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 15.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? primary : Colors.black87,
                ),
              ),
            ),
            if (count != null) ...[
              SizedBox(width: 12.w),
              Text(
                "$count",
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? primary : Colors.black38,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The floating "Menu" pill (Zomato style) that opens the jump-to-category
  /// sheet.
  Widget _buildMenuButton(List<Category> categories) {
    final primary = Theme.of(context).colorScheme.primary;
    return TactileButton(
      onTap: () => _openCategorySheet(categories),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: primary,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.forkKnife(PhosphorIconsStyle.fill),
              color: Colors.white,
              size: 18.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              "Menu",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
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
    final primary = Theme.of(context).colorScheme.primary;

    // Landscape tablets: categories become a sidebar.
    final expanded = Responsive.isExpanded(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // The Zomato-style "Menu" button — a jump-to-category shortcut so a long
      // catalogue is navigable without endless scrolling. Hidden while there are
      // no categories to jump to. It floats just above the bottom nav (the
      // parent reserves that space, so this sits clear of it).
      floatingActionButton: categoriesAsync.maybeWhen(
        // Not on landscape tablets: the category sidebar is always visible.
        data: (cats) => cats.isEmpty || Responsive.isExpanded(context)
            ? null
            : _buildMenuButton(cats),
        orElse: () => null,
      ),
      body: SafeArea(
        bottom: false,
        child: expanded
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCategorySidebar(categoriesAsync),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      color: primary,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Store switcher + wishlist + greeting scroll away — they're
                            // only needed now and then, so browsing reclaims their space.
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  16.w,
                                  8.h,
                                  16.w,
                                  0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: StoreSwitcher(
                                        activeBrand: widget.brand,
                                        onSelect: (b) =>
                                            widget.onSelectStore?.call(b),
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    _buildWishlistButton(context),
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _buildGreeting(isLittleH),
                            ),
                            // Search sticks to the very top once you scroll past the header.
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _PinnedHeaderDelegate(
                                height: 56.h,
                                child: Container(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  padding: EdgeInsets.fromLTRB(
                                    16.w,
                                    2.h,
                                    16.w,
                                    6.h,
                                  ),
                                  child: _buildSearchBar(isLittleH),
                                ),
                              ),
                            ),
                            // Category chips pin just under the search bar (on landscape
                            // tablets they are a sidebar instead, see build()).
                            if (!expanded)
                              SliverPersistentHeader(
                                pinned: true,
                                delegate: _PinnedHeaderDelegate(
                                  height: 56.h,
                                  child: _buildCategoryBar(categoriesAsync),
                                ),
                              ),
                            ..._productSlivers(productsAsync),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                color: primary,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Store switcher + wishlist + greeting scroll away — they're
                      // only needed now and then, so browsing reclaims their space.
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: StoreSwitcher(
                                  activeBrand: widget.brand,
                                  onSelect: (b) =>
                                      widget.onSelectStore?.call(b),
                                ),
                              ),
                              SizedBox(width: 10.w),
                              _buildWishlistButton(context),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildGreeting(isLittleH)),
                      // Search sticks to the very top once you scroll past the header.
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedHeaderDelegate(
                          height: 56.h,
                          child: Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
                            child: _buildSearchBar(isLittleH),
                          ),
                        ),
                      ),
                      // Category chips pin just under the search bar (on landscape
                      // tablets they are a sidebar instead, see build()).
                      if (!expanded)
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedHeaderDelegate(
                            height: 56.h,
                            child: _buildCategoryBar(categoriesAsync),
                          ),
                        ),
                      ..._productSlivers(productsAsync),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// A slim, one-line time-based greeting. Replaces the old full-bleed gradient
  /// hero, which ate ~40% of a small screen before a single product was
  /// visible. Scrolls away with the content.
  Widget _buildGreeting(bool isLittleH) {
    final hour = DateTime.now().hour;
    String title;
    if (hour < 12) {
      title = isLittleH ? "Fresh from the oven" : "Good morning";
    } else if (hour < 17) {
      title = isLittleH ? "Midday bakes" : "Good afternoon";
    } else {
      title = isLittleH ? "Evening treats" : "Good evening";
    }
    final subtitle = isLittleH
        ? "Handcrafted, baked fresh today"
        : "Freshly brewed, just for you";

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 6.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5.sp,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isLittleH
                ? PhosphorIcons.cookie(PhosphorIconsStyle.duotone)
                : PhosphorIcons.coffee(PhosphorIconsStyle.duotone),
            size: 30.sp,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isLittleH) {
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: isLittleH
              ? "Search cakes, breads, pastries..."
              : "Search coffee, tea, snacks...",
          hintStyle: GoogleFonts.poppins(
            color: Colors.black26,
            fontSize: 13.5.sp,
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
          contentPadding: EdgeInsets.symmetric(vertical: 14.h),
        ),
      ),
    );
  }

  Widget _buildWishlistButton(BuildContext context) {
    return TactileButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WishlistScreen()),
        );
      },
      child: Container(
        height: 46.h,
        width: 46.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Consumer(
          builder: (context, ref, _) {
            final count = ref
                .watch(wishlistProvider)
                .maybeWhen(data: (list) => list.length, orElse: () => 0);
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  count > 0
                      ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                      : PhosphorIcons.heart(),
                  color: count > 0 ? const Color(0xFFE5484D) : Colors.black54,
                  size: 22.sp,
                ),
                if (count > 0)
                  Positioned(
                    right: 4.w,
                    top: 4.h,
                    child: Container(
                      padding: EdgeInsets.all(3.r),
                      constraints: BoxConstraints(
                        minWidth: 14.w,
                        minHeight: 14.w,
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
                          fontSize: 8.sp,
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
    );
  }

  /// The pinned category filter. Compact pill chips that stay in reach while the
  /// long menu scrolls — the main findability win over the old 110px circle row
  /// that scrolled away and left the customer with no filter at hand.
  /// Landscape tablets: the categories as a list down the left, so the full
  /// width to the right is products.
  Widget _buildCategorySidebar(AsyncValue<List<Category>> categoriesAsync) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget row(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? primary : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      width: 240,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      child: categoriesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
        data: (categories) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 16, 10),
              child: Text(
                'Menu',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.black45,
                ),
              ),
            ),
            row(
              'All',
              _selectedCategoryIndex == -1,
              () => _onCategorySelected(-1, null),
            ),
            for (var i = 0; i < categories.length; i++)
              row(
                categories[i].name,
                _selectedCategoryId == categories[i].id,
                () => _onCategorySelected(i, categories[i].id),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBar(AsyncValue<List<Category>> categoriesAsync) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      alignment: Alignment.centerLeft,
      child: categoriesAsync.when(
        loading: () => ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: 5,
          itemBuilder: (_, _) => Padding(
            padding: EdgeInsets.only(right: 10.w, top: 9.h, bottom: 9.h),
            child: Skeleton(width: 74.w, height: 36.h, radius: 12),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
        data: (categories) {
          final allSelected = _selectedCategoryIndex == -1;
          final chips = <Widget>[
            _buildCategoryChip(
              key: allSelected ? _selectedChipKey : null,
              label: "All",
              selected: allSelected,
              onTap: () => _onCategorySelected(-1, null),
            ),
          ];
          for (var i = 0; i < categories.length; i++) {
            final cat = categories[i];
            final selected = _selectedCategoryId == cat.id;
            chips.add(
              _buildCategoryChip(
                key: selected ? _selectedChipKey : null,
                label: cat.name,
                selected: selected,
                onTap: () => _onCategorySelected(i, cat.id),
              ),
            );
          }
          chips.add(_buildAllCategoriesChip(categories));
          // SingleChildScrollView + Row (not a lazy ListView) so every chip is
          // built — the selected chip's GlobalKey must resolve even when it's
          // far off to the right, otherwise we can't scroll it into view.
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _categoryBarController,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(children: chips),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    Key? key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      key: key,
      child: Padding(
        padding: EdgeInsets.only(right: 10.w),
        child: TactileButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: selected ? primary : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: selected
                    ? primary
                    : Colors.black.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? primary.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: selected ? 10 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A trailing icon chip that opens the full category grid sheet.
  Widget _buildAllCategoriesChip(List<Category> categories) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(right: 16.w),
        child: TactileButton(
          onTap: () => _openCategorySheet(categories),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Icon(
              PhosphorIcons.slidersHorizontal(),
              size: 18.sp,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the product area as slivers for the CustomScrollView.
  List<Widget> _productSlivers(AsyncValue<ProductsState> productsAsync) {
    return productsAsync.when(
      loading: () => [const SliverToBoxAdapter(child: ProductListSkeleton())],
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _stateMessage(
            icon: PhosphorIcons.wifiSlash(),
            message: "Couldn't load items.\nPull down to try again.",
          ),
        ),
      ],
      data: (productsState) {
        final products = productsState.products;
        if (products.isEmpty) {
          final searching = _searchQuery.trim().isNotEmpty;
          final filtered = _selectedCategoryId != null;
          if (searching) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _stateMessage(
                  icon: PhosphorIcons.magnifyingGlass(),
                  message:
                      "Nothing matches \"$_searchQuery\".\nTry a different spelling or a broader word.",
                  actionLabel: "Clear search",
                  onAction: () {
                    _searchController.clear();
                    setState(() => _searchQuery = "");
                  },
                ),
              ),
            ];
          }
          if (filtered) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _stateMessage(
                  icon: PhosphorIcons.forkKnife(PhosphorIconsStyle.duotone),
                  message: "Nothing in this category yet.",
                  actionLabel: "Browse everything",
                  onAction: () => _onCategorySelected(-1, null),
                ),
              ),
            ];
          }
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _stateMessage(
                icon: PhosphorIcons.forkKnife(PhosphorIconsStyle.duotone),
                message:
                    "No items found in this section.\nPull down to refresh.",
              ),
            ),
          ];
        }
        return [
          // The grid's own width, not the screen's: on tablets the rail and the
          // category sidebar take part of it.
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 4.h),
              sliver: SliverGrid.builder(
                gridDelegate: _gridDelegate(
                  context,
                  constraints.crossAxisExtent,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) =>
                    _buildGridCard(products[index]),
              ),
            ),
          ),
          // The paging footer sits full-width below the grid (a grid can't hold
          // a spanning row cleanly).
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: _buildMenuFooter(productsState),
            ),
          ),
        ];
      },
    );
  }

  /// A centered empty/error state. The enclosing CustomScrollView is always
  /// scrollable, so pull-to-refresh still works over it.
  Widget _stateMessage({
    required IconData icon,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
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
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
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

  /// The end of the menu should say so. The grid used to just stop at whatever
  /// the first page held — and since that was 20 items out of nearly 300, the
  /// customer had no way to know there was any more.
  Widget _buildMenuFooter(ProductsState state) {
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

    if (state.hasMore) return SizedBox(height: 24.h);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h),
      child: Center(
        child: Text(
          "You've seen the whole menu",
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: Colors.black.withValues(alpha: 0.35),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// A creative, image-forward grid tile: the photo fills the card with a
  /// rating badge, wishlist heart, and the add/stepper control all layered over
  /// it, then a clean name + price footer sits below. Deliberately not a plain
  /// image-over-text column.
  /// 2 columns on a phone, more on an open foldable or tablet. Each tile is
  /// as tall as its 4:3 image plus the one-line name and the price.
  SliverGridDelegate _gridDelegate(BuildContext context, double width) {
    final columns = Responsive.columnsFor(width, minTileWidth: 175.w);
    final gap = 12.w;
    final tileWidth = (width - 32.w - gap * (columns - 1)) / columns;
    final scaler = MediaQuery.textScalerOf(context);
    final textBlock =
        scaler.scale(13.sp) * 1.15 + 2.h + scaler.scale(14.sp) * 1.5 + 10.h;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: 12.h,
      crossAxisSpacing: gap,
      mainAxisExtent: tileWidth * 3 / 4 + textBlock + 2,
    );
  }

  Widget _buildGridCard(Product product) {
    final isLittleH = widget.brand == 'littleh';

    return Consumer(
      builder: (context, ref, child) {
        final (int cartQty, String? cartItemId) = ref.watch(
          cartProvider.select<(int, String?)>((async) {
            final cart = async.value;
            if (cart == null) return (0, null);
            final existing = cart.items
                .where((i) => i.product.id == product.id)
                .toList();
            if (existing.isEmpty) return (0, null);
            return (
              existing.fold<int>(0, (sum, item) => sum + item.quantity),
              existing.first.id,
            );
          }),
        );

        final primary = Theme.of(context).colorScheme.primary;
        final hasRating = product.averageRating > 0;

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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.black.withValues(alpha: 0.02)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Image with layered controls -----------------------------
                // 4:3, so a card is about as tall as it is wide and a phone
                // shows two full rows (it was ~1.5x taller than wide).
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: EdgeInsets.all(6.r),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18.r),
                          child: Hero(
                            tag: product.id,
                            child: ProductImage(
                              url: product.image,
                              isLittleH: isLittleH,
                              iconSize: 40,
                            ),
                          ),
                        ),
                      ),
                      // Rating badge, top-left (only when there's a real rating).
                      if (hasRating)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3AA65B),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  PhosphorIcons.star(PhosphorIconsStyle.fill),
                                  color: Colors.white,
                                  size: 10.sp,
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  product.averageRating.toStringAsFixed(1),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Wishlist heart, top-right.
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Consumer(
                          builder: (context, ref, child) {
                            final isFav = ref
                                .watch(wishlistProvider)
                                .maybeWhen(
                                  data: (list) =>
                                      list.any((p) => p.id == product.id),
                                  orElse: () => false,
                                );
                            return TactileButton(
                              onTap: () => ref
                                  .read(wishlistProvider.notifier)
                                  .toggleFavorite(product),
                              child: Container(
                                padding: EdgeInsets.all(6.r),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isFav
                                      ? PhosphorIcons.heart(
                                          PhosphorIconsStyle.fill,
                                        )
                                      : PhosphorIcons.heart(),
                                  size: 14.sp,
                                  color: isFav
                                      ? Colors.redAccent
                                      : Colors.black54,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Add / stepper, bottom-right, floating on the image.
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: cartQty > 0
                            ? _gridStepper(
                                qty: cartQty,
                                primary: primary,
                                onMinus: () {
                                  if (cartItemId == null) return;
                                  if (cartQty == 1) {
                                    ref
                                        .read(cartProvider.notifier)
                                        .removeItem(
                                          cartItemId,
                                          brand: product.brand,
                                        );
                                  } else {
                                    ref
                                        .read(cartProvider.notifier)
                                        .updateQuantity(
                                          cartItemId,
                                          cartQty - 1,
                                        );
                                  }
                                },
                                onPlus: () {
                                  if (cartItemId == null) return;
                                  ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(cartItemId, cartQty + 1);
                                },
                              )
                            : TactileButton(
                                onTap: () => _handleQuickAdd(product),
                                child: Container(
                                  height: 34.w,
                                  width: 34.w,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.15,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    PhosphorIcons.plus(PhosphorIconsStyle.bold),
                                    color: primary,
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                // --- Name + price footer -------------------------------------
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "₹${product.displayPrice}",
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The compact +/- pill shown on a grid tile once the item is in the bag.
  Widget _gridStepper({
    required int qty,
    required Color primary,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      height: 34.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _gridStepBtn(
            PhosphorIcons.minus(PhosphorIconsStyle.bold),
            primary,
            onMinus,
          ),
          Container(
            constraints: BoxConstraints(minWidth: 18.w),
            alignment: Alignment.center,
            child: Text(
              "$qty",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 13.sp,
                color: primary,
              ),
            ),
          ),
          _gridStepBtn(
            PhosphorIcons.plus(PhosphorIconsStyle.bold),
            primary,
            onPlus,
          ),
        ],
      ),
    );
  }

  Widget _gridStepBtn(IconData icon, Color color, VoidCallback onTap) {
    return TactileButton(
      onTap: onTap,
      child: SizedBox(
        width: 28.w,
        height: 34.h,
        child: Icon(icon, size: 14.sp, color: color),
      ),
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
                  // Had no errorBuilder at all: a URL that existed but 404'd
                  // (the legacy Cloudinary links) rendered Flutter's broken
                  // image glyph right in the customer's face.
                  child: ProductImage(
                    url: widget.product.image,
                    isLittleH: widget.product.brand == 'littleh',
                    iconSize: 28,
                  ),
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

/// Pins a fixed-height widget (the search bar, the category chip row) to the top
/// of the scroll view, so it stays in reach no matter how far down the menu the
/// customer has scrolled.
class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _PinnedHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}
