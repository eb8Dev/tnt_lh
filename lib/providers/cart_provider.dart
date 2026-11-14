import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/cart_model.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/services/cart_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/providers/socket_provider.dart';

/// Carries the message from a cart write that failed *after* the UI had already
/// moved optimistically. Screens listen to this and show a snackbar, so a failed
/// write is never silent even though the call itself returned immediately.
class CartErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String? message) => state = message;
}

final cartErrorProvider = NotifierProvider<CartErrorNotifier, String?>(
  CartErrorNotifier.new,
);

class CartNotifier extends AsyncNotifier<Cart> {
  /// Prefix for the temporary id given to an item that exists on screen but has
  /// not come back from the server yet. Encodes the product id so a follow-up
  /// tap on +/- can be re-pointed at the real cart-item id once it lands.
  static const String _optimisticPrefix = '__optimistic__';

  final Map<String, Timer> _writeTimers = {};
  final Map<String, Future<void>> _inFlightAdds = {};
  Timer? _reconcileTimer;

  @override
  FutureOr<Cart> build() async {
    // Only signing in or out rebuilds the cart. It used to watch the whole auth
    // state and the selected store too, and every rebuild runs onDispose below,
    // which cancels the debounced quantity writes still waiting to be sent: edit
    // your profile, or switch store, within a moment of changing a quantity and
    // the change was silently lost. The cart is one cart across both stores, so
    // switching store needs no refetch.
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));

    ref.listen<int>(liveRefreshProvider, (_, _) {
      if (signedIn && _writeTimers.isEmpty) fetchCart(background: true);
    });

    ref.onDispose(() {
      for (final t in _writeTimers.values) {
        t.cancel();
      }
      _writeTimers.clear();
      _reconcileTimer?.cancel();
    });

    if (signedIn) {
      return _fetchCartInternal();
    }
    return Cart(items: [], subtotal: 0, itemCount: 0);
  }

  Cart _recalculate(List<CartItem> items) => Cart(
    items: items,
    subtotal: items.fold(0.0, (sum, i) => sum + i.price * i.quantity),
    itemCount: items.fold(0, (sum, i) => sum + i.quantity),
  );

  void _reportError(Object error) {
    ref
        .read(cartErrorProvider.notifier)
        .report(error.toString().replaceFirst('Exception: ', ''));
  }

  Future<Cart> _fetchCartInternal() async {
    // Backend returns the unified cart for the user. Let failures propagate so
    // the UI can show a real error state instead of a fake "empty cart".
    final result = await CartService.getCart();
    if (result['success'] == true && result['data'] is Map<String, dynamic>) {
      return Cart.fromJson(result['data']);
    }
    // Success-but-empty (e.g. 404 the service maps to an empty cart).
    return Cart(items: [], subtotal: 0, itemCount: 0);
  }

  /// Bumped on every local (optimistic) change.
  int _localEdits = 0;

  bool get _settling => _writeTimers.isNotEmpty || _inFlightAdds.isNotEmpty;

  Future<void> fetchCart({bool background = false}) async {
    if (!background) state = const AsyncValue.loading();
    final editsAtStart = _localEdits;
    final result = await AsyncValue.guard(() => _fetchCartInternal());
    // A background refresh that fails must not replace a good cart with an
    // error screen (e.g. a flaky refresh right after a successful add).
    if (background && result is AsyncError && state.hasValue) {
      return;
    }
    // The bag couldn't keep up with quick edits: tap + four times and the
    // count went 2, 3, 2, 4, 5 as reconciling fetches landed, each carrying
    // the server's view from before the latest taps. A background fetch that
    // started before a local edit, or lands while writes are still queued, is
    // stale by definition. Drop it and reconcile once things settle.
    if (background &&
        state.hasValue &&
        (editsAtStart != _localEdits || _settling)) {
      _scheduleReconcile();
      return;
    }
    state = result;
  }

  /// Pulls the server's cart back in once the taps stop, so prices and item ids
  /// settle without a round-trip sitting in front of every button press.
  void _scheduleReconcile() {
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(
      const Duration(milliseconds: 500),
      () => fetchCart(background: true),
    );
  }

  /// Holding "+" should send one request, not one per tap.
  void _debounceWrite(String key, Future<void> Function() write) {
    _writeTimers[key]?.cancel();
    _writeTimers[key] = Timer(const Duration(milliseconds: 350), () async {
      _writeTimers.remove(key);
      final rollback = state.value;
      try {
        await write();
        _scheduleReconcile();
      } catch (e) {
        _reportError(e);
        // The optimistic state is now a lie; take the server's word for it.
        if (rollback != null) await fetchCart(background: true);
      }
    });
  }

  /// An item added moments ago has a placeholder id. Wait for its POST to land,
  /// refetch, and hand back the id the server actually assigned.
  /// One cart line: a product with a particular set of options. Keying
  /// optimistic lines by product alone meant an egg and an eggless Tres
  /// Leches added in quick succession shared one temporary id.
  static String _lineKey(String productId, String? customization) =>
      '$productId|${customization ?? ''}';

  Future<String?> _resolveItemId(String itemId) async {
    if (!itemId.startsWith(_optimisticPrefix)) return itemId;
    final key = itemId.substring(_optimisticPrefix.length);
    final productId = key.split('|').first;
    final options = key.substring(productId.length + 1);
    await _inFlightAdds[key];
    // Ask the server for the real id without replacing what's on screen:
    // other edits may still be queued, and the screen is ahead of the server.
    final server = await _fetchCartInternal();
    final known = state.value?.items.map((i) => i.id).toSet() ?? {};
    final candidates = server.items
        .where((i) => i.product.id == productId && !known.contains(i.id))
        .toList();
    // The server may word the options its own way ("Eggless" stays
    // "Eggless"; nothing becomes "1kg | Standard"), so prefer an exact match
    // and otherwise take the line this screen doesn't know about yet.
    final real =
        (candidates
                    .where((i) => (i.customization ?? '') == options)
                    .firstOrNull ??
                candidates.firstOrNull)
            ?.id;
    final current = state.value;
    if (real != null && current != null) {
      state = AsyncData(
        _recalculate([
          for (final i in current.items)
            i.id == itemId ? i.copyWith(id: real) : i,
        ]),
      );
    }
    return real;
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
    required Product product,
    required int quantity,
    String? customization,
  }) async {
    final previous = state.value;

    // Put the item on screen now. The badge, the stepper and the subtotal all
    // read `items`, so bumping only `itemCount` left the card looking dead
    // until the refetch returned.
    if (previous != null) {
      final items = [...previous.items];
      // Same product with different options (egg / eggless, sizes) is a
      // separate line. Empty and missing options are the same thing.
      final index = items.indexWhere(
        (i) =>
            i.product.id == product.id &&
            (i.customization ?? '') == (customization ?? ''),
      );
      if (index >= 0) {
        items[index] = items[index].copyWith(
          quantity: items[index].quantity + quantity,
        );
      } else {
        items.add(
          CartItem(
            id: '$_optimisticPrefix${_lineKey(product.id, customization)}',
            product: product,
            quantity: quantity,
            price: product.price,
            customization: customization,
            brand: product.brand,
          ),
        );
      }
      state = AsyncData(_recalculate(items));
      _localEdits++;
    }

    final request = CartService.addToCart(
      productId: product.id,
      quantity: quantity,
      brand: product.brand,
      customization: customization,
    );
    final key = _lineKey(product.id, customization);
    _inFlightAdds[key] = request.then((_) {}).catchError((_) {});

    try {
      await request;
    } catch (e) {
      if (previous != null) state = AsyncData(previous); // roll back
      rethrow;
    } finally {
      _inFlightAdds.remove(key);
    }

    _scheduleReconcile();
  }

  Future<void> updateQuantity(String itemId, int quantity) async {
    if (quantity < 1) return removeItem(itemId);

    final previous = state.value;
    if (previous == null) return;

    final items = previous.items
        .map((i) => i.id == itemId ? i.copyWith(quantity: quantity) : i)
        .toList();
    state = AsyncData(_recalculate(items));
    _localEdits++;

    final brand = previous.items
        .firstWhere((i) => i.id == itemId, orElse: () => previous.items.first)
        .brand;

    _debounceWrite(itemId, () async {
      final realId = await _resolveItemId(itemId);
      if (realId == null) throw Exception('That item is no longer in your bag');
      await CartService.updateItemQuantity(realId, quantity, brand: brand);
    });
  }

  Future<void> removeItem(String itemId, {String? brand}) async {
    final previous = state.value;
    if (previous == null) return;

    final target = previous.items.where((i) => i.id == itemId).firstOrNull;
    final targetBrand = brand ?? target?.brand ?? ref.read(brandProvider);

    state = AsyncData(
      _recalculate(previous.items.where((i) => i.id != itemId).toList()),
    );
    _localEdits++;

    // A pending debounced quantity write for this item is now meaningless.
    _writeTimers.remove(itemId)?.cancel();

    try {
      final realId = await _resolveItemId(itemId);
      if (realId != null) {
        await CartService.removeItem(realId, brand: targetBrand);
      }
    } catch (e) {
      state = AsyncData(previous); // put it back
      _reportError(e);
      rethrow;
    }

    _scheduleReconcile();
  }

  Future<void> clearCart({String? brand}) async {
    final currentCart = state.value;
    if (currentCart == null || currentCart.items.isEmpty) return;

    if (brand == null) {
      // DELETE /cart clears the whole cart atomically in one request.
      await CartService.clearCart();
    } else {
      // There is no per-brand clear endpoint, so remove that brand's items
      // individually. Errors propagate so the UI can report a failed clear.
      final itemsToClear = currentCart.items
          .where((i) => i.brand == brand)
          .toList();
      if (itemsToClear.isEmpty) return;
      for (final item in itemsToClear) {
        await CartService.removeItem(item.id, brand: item.brand);
      }
    }

    await fetchCart(background: true);
  }
}

final cartProvider = AsyncNotifierProvider<CartNotifier, Cart>(() {
  return CartNotifier();
});
