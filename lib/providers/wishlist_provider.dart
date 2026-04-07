import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/services/wishlist_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';

class WishlistNotifier extends AsyncNotifier<List<Product>> {
  @override
  FutureOr<List<Product>> build() async {
    final auth = ref.watch(authProvider);
    // We don't necessarily filter by brand here if the user wants global favorites,
    // but the API supports brand-based fetching if needed.
    // Let's make it global for now as per "global orders" pattern.

    if (auth.isAuthenticated) {
      return _fetchWishlist();
    }
    return [];
  }

  Future<List<Product>> _fetchWishlist() async {
    final result = await WishlistService.getWishlist();
    return result.map((json) => Product.fromJson(json)).toList();
  }

  Future<void> toggleFavorite(Product product) async {
    final previousState = state;
    final isFav = isFavorite(product.id);
    final brand = ref.read(brandProvider);

    // Optimistic Update: Update local state immediately
    if (state.hasValue) {
      final currentList = state.value!;
      if (isFav) {
        state = AsyncValue.data(
          currentList.where((p) => p.id != product.id).toList(),
        );
      } else {
        state = AsyncValue.data([...currentList, product]);
      }
    }

    try {
      if (isFav) {
        await WishlistService.removeFromWishlist(product.id, brand: brand);
      } else {
        await WishlistService.addToWishlist(product.id, brand: brand);
      }
      // Optional: Refresh from server to ensure sync, but keep it background
      _fetchWishlist().then((freshList) {
        state = AsyncValue.data(freshList);
      });
    } catch (e) {
      // Revert on failure
      state = previousState;
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
