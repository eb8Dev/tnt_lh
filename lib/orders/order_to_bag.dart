import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/cart_provider.dart';
import 'package:tnt_lh/providers/product_provider.dart';

/// An order line's options in the form the app sends them. The server
/// labels cakes its own way ("1kg | Standard | Eggless"); sent back as-is
/// that would read as a customer note, so it's turned back into the choice.
String? orderLineChoice(String? label) {
  final l = (label ?? '').trim();
  if (l.isEmpty) return null;
  if (RegExp(r'^[\d.]+kg \| (Standard|Customized)').hasMatch(l)) {
    return l.toLowerCase().contains('eggless') ? 'Eggless' : null;
  }
  return l;
}

/// Puts an order's items back in the bag at today's prices ("Your usual",
/// or editing an order by cancelling it). Returns how many lines were left
/// out because they're no longer on the menu.
Future<int> addOrderToBag(
  WidgetRef ref,
  Order order, {
  Map<String, List<Product>>? menu,
}) async {
  final lists = menu ?? await ref.read(storeMenuProvider(order.brand).future);
  final byId = {
    for (final list in (lists ?? const <String, List<Product>>{}).values)
      for (final p in list) p.id: p,
  };
  final cart = ref.read(cartProvider.notifier);
  var skipped = 0;
  for (final item in order.items) {
    final product = byId[item.product];
    if (product == null || !product.isAvailable) {
      skipped++;
      continue;
    }
    try {
      await cart.addToCart(
        product: product,
        quantity: item.quantity,
        customization: orderLineChoice(item.customization),
      );
    } catch (_) {
      skipped++;
    }
  }
  return skipped;
}
