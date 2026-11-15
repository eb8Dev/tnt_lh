import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/services/wishlist_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';

class WishlistNotifier extends AsyncNotifier<List<Product>> {
  @override
  FutureOr<List<Product>> build() async {
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
    // We don't necessarily filter by brand here if the user wants global favorites,
    // but the API supports brand-based fetching if needed.
    // Let's make it global for now as per "global orders" pattern.

    if (signedIn) {
      return _fetchWishlist();
    }
    return [];
  }

  Future<List<Product>> _fetchWishlist() async {
    final result = await WishlistService.getWishlist();
    return result.map((json) => Product.fromJson(json)).toList();
  }

  /// Bumped on every toggle; a refresh that started before the latest tap
  /// is stale and mustn't overwrite it (two quick taps used to flicker).
  int _edits = 0;

  Future<void> toggleFavorite(Product product) async {
    final isFav = isFavorite(product.id);
    final mine = ++_edits;

    // Optimistic: the heart changes the moment it's tapped.
    final current = state.value ?? const <Product>[];
    state = AsyncValue.data(
      isFav
          ? current.where((p) => p.id != product.id).toList()
          : [...current, product],
    );

    try {
      // The item's own store, not whichever store is being browsed.
      if (isFav) {
        await WishlistService.removeFromWishlist(
          product.id,
          brand: product.brand,
        );
      } else {
        await WishlistService.addToWishlist(product.id, brand: product.brand);
      }
      final fresh = await _fetchWishlist();
      if (mine == _edits) state = AsyncValue.data(fresh);
    } catch (e) {
      if (mine == _edits) {
        // Put the heart back the way it was.
        final now = state.value ?? const <Product>[];
        state = AsyncValue.data(
          isFav
              ? [...now.where((p) => p.id != product.id), product]
              : now.where((p) => p.id != product.id).toList(),
        );
      }
      rethrow;
    }
  }

  bool isFavorite(String productId) {
    final list = state.value ?? [];
    return list.any((p) => p.id == productId);
  }
}

final wishlistProvider = AsyncNotifierProvider<WishlistNotifier, List<Product>>(
  () {
    return WishlistNotifier();
  },
);
