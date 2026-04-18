import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/services/cart_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';

class CartNotifier extends AsyncNotifier<Cart> {
  @override
  FutureOr<Cart> build() async {
    final auth = ref.watch(authProvider);
    // Note: We still watch brandProvider to trigger rebuilds if needed,
    // but the cart state will now be global.
    ref.watch(brandProvider);

    if (auth.isAuthenticated) {
      return _fetchCartInternal();
    }
    return Cart(items: [], subtotal: 0, itemCount: 0);
  }

  Future<Cart> _fetchCartInternal() async {
    // Backend returns unified cart for user
    try {
      final result = await CartService.getCart();
      if (result['success'] == true && result['data'] is Map<String, dynamic>) {
        return Cart.fromJson(result['data']);
      }
      return Cart(items: [], subtotal: 0, itemCount: 0);
    } catch (e) {
      return Cart(items: [], subtotal: 0, itemCount: 0);
    }
  }

  Future<void> fetchCart({bool background = false}) async {
    if (!background) state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchCartInternal());
  }

  /// Helper to get items for a specific brand
  List<CartItem> getItemsForBrand(String brand) {
    final cart = state.value;
    if (cart == null) return [];
    return cart.items.where((item) => item.brand == brand).toList();
  }

  /// Helper to get subtotal for a specific brand
  double getSubtotalForBrand(String brand) {
    return getItemsForBrand(
      brand,
    ).fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<void> addToCart({
    required String productId,
    required int quantity,
    required String brand,
    String? customization,
  }) async {
    await CartService.addToCart(
      productId: productId,
      quantity: quantity,
      brand: brand,
      customization: customization,
    );
    await fetchCart(background: true);
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    final brand = ref.read(brandProvider);
    await CartService.updateItemQuantity(itemId, quantity, brand: brand);
    await fetchCart(background: true);
  }

  Future<void> removeItem(String itemId, {String? brand}) async {
    final targetBrand = brand ?? ref.read(brandProvider);
    await CartService.removeItem(itemId, brand: targetBrand);
    await fetchCart(background: true);
  }

  Future<void> clearCart({String? brand}) async {
    try {
      // If the backend is returning "Catched" for the global clear, we should do a client-side sequential clear
      // This is more reliable if the backend DELETE endpoint is broken.
      
      final currentCart = state.value;
      if (currentCart == null || currentCart.items.isEmpty) return;

      final itemsToClear = brand == null
          ? currentCart.items
          : currentCart.items.where((i) => i.brand == brand).toList();

      if (itemsToClear.isEmpty) return;

      // Sequential clear (Reliable fallback)
      for (final item in itemsToClear) {
        try {
          await CartService.removeItem(item.id, brand: item.brand);
        } catch (e) {
          debugPrint("Failed to remove item ${item.id} during clear: $e");
        }
      }

      // Final re-fetch to ensure everything is in sync
      await fetchCart(background: true);
      
    } catch (e) {
      debugPrint("CartNotifier.clearCart error: $e");
      rethrow;
    }
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(() {
  return CartNotifier();
});
