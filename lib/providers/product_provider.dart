import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/socket_provider.dart';
import 'package:tnt_lh/services/auth_service.dart';

/// Reload when the menu changes on the server (an admin or manager edits a
/// category or product: a new picture, price, item switched off) and after
/// a reconnect or coming back to the app, so every open app shows the menu
/// as it is now, not as it was at launch.
void _reloadOnCatalogChange(Ref ref) {
  ref.listen<SocketEvent?>(socketEventsProvider, (_, e) {
    if (e?.name == 'catalog:updated') ref.invalidateSelf();
  });
  ref.listen<int>(liveRefreshProvider, (_, _) => ref.invalidateSelf());
}

class ProductParams {
  final String? categoryId;
  final String? search;
  final String brand;

  ProductParams({this.categoryId, this.search, required this.brand});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductParams &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          search == other.search &&
          brand == other.brand;

  @override
  int get hashCode => categoryId.hashCode ^ search.hashCode ^ brand.hashCode;
}

final categoriesProvider = FutureProvider.family<List<Category>, String>((
  ref,
  brand,
) async {
  // The request is already brand-scoped (/api/:brand/...), so the backend
  // returns only this brand's categories. Re-filtering client-side risked
  // showing an empty screen whenever a brand field didn't match exactly.
  _reloadOnCatalogChange(ref);
  final raw = await AuthService.getCategories(brand: brand);
  return raw.map((e) => Category.fromJson(e)).toList();
});

/// A page of products, and whether there are more.
class ProductsState {
  final List<Product> products;
  final bool hasMore;
  final bool isLoadingMore;

  const ProductsState({
    required this.products,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  ProductsState copyWith({
    List<Product>? products,
    bool? hasMore,
    bool? isLoadingMore,
  }) => ProductsState(
    products: products ?? this.products,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// THE MENU WAS TRUNCATED AT 20 ITEMS.
///
/// This asked for products without a page size, so the API's default of 20
/// applied — while the live catalogue holds 286 products for Teas n Trees and
/// 105 for Little H. The customer could see about 7% of the menu and had no way
/// to reach the rest: no "load more", no end-of-list marker, the grid simply
/// stopped. Everything past the first twenty items was unsellable.
///
/// Now it pages, appending as the customer scrolls, and says so when it runs out.
class ProductsNotifier extends AsyncNotifier<ProductsState> {
  ProductsNotifier(this.params);

  final ProductParams params;

  static const _pageSize = 30;
  int _page = 1;

  @override
  Future<ProductsState> build() {
    _reloadOnCatalogChange(ref);
    return _loadFirstPage();
  }

  Future<ProductsState> _loadFirstPage() async {
    _page = 1;
    final page = await _fetch(1);
    return ProductsState(products: page.$1, hasMore: page.$2);
  }

  /// (products, hasMore)
  Future<(List<Product>, bool)> _fetch(int page) async {
    // Brand-scoped endpoint already filters by brand — see categoriesProvider.
    final raw = await AuthService.getProducts(
      categoryId: params.categoryId,
      search: params.search,
      brand: params.brand,
      page: page,
      limit: _pageSize,
    );
    final products = raw.map((e) => Product.fromJson(e)).toList();
    // The service hands back just the list, so infer "there's more" from a full
    // page. One redundant request at the very end is a fair price for not
    // reshaping every caller.
    return (products, products.length >= _pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final next = _page + 1;
      final page = await _fetch(next);
      _page = next;
      state = AsyncValue.data(
        ProductsState(
          products: [...current.products, ...page.$1],
          hasMore: page.$2,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Keep what's already on screen; scrolling again retries.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final productsProvider =
    AsyncNotifierProvider.family<
      ProductsNotifier,
      ProductsState,
      ProductParams
    >(ProductsNotifier.new);

/// The store's most-ordered items, for the Bestsellers row.
final popularProductsProvider = FutureProvider.family<List<Product>, String>((
  ref,
  brand,
) async {
  _reloadOnCatalogChange(ref);
  final raw = await AuthService.getProducts(
    brand: brand,
    limit: 10,
    sort: 'popular',
  );
  return raw.map((e) => Product.fromJson(e)).toList();
});

/// The store's whole menu, grouped by category, loaded once.
///
/// The sectioned "All" view used to fetch each category as it scrolled into
/// view (0.3–0.7 s each), so a quick scroll met a row of spinners. Pages of
/// 100 are fetched in parallel instead; every section then appears at once.
final storeMenuProvider =
    FutureProvider.family<Map<String, List<Product>>, String>((
      ref,
      brand,
    ) async {
      _reloadOnCatalogChange(ref);
      Future<List<Product>> page(int n) async => (await AuthService.getProducts(
        brand: brand,
        page: n,
        limit: 100,
      )).map((e) => Product.fromJson(e)).toList();

      final first = await Future.wait([page(1), page(2), page(3)]);
      final all = [for (final p in first) ...p];
      // A menu past 300 items: keep going one page at a time.
      var n = 4;
      var last = first.last;
      while (last.length == 100) {
        last = await page(n++);
        all.addAll(last);
      }

      final byCategory = <String, List<Product>>{};
      for (final p in all) {
        byCategory.putIfAbsent(p.categoryId ?? '', () => []).add(p);
      }
      return byCategory;
    });
