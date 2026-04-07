import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/socket_provider.dart';

class OrderNotifier extends AsyncNotifier<List<Order>> {
  @override
  FutureOr<List<Order>> build() async {
    final auth = ref.watch(authProvider);

    // Listen to Socket events for real-time updates
    ref.listen<SocketEvent?>(socketEventsProvider, (prev, next) {
      if (next != null) {
        if (next.name == 'order:status-updated' ||
            next.name == 'order:created') {
          fetchOrders(background: true);
        }
      }
    });

    if (auth.isAuthenticated) {
      return _fetchGlobalOrders();
    }
    return [];
  }

  Future<List<Order>> _fetchGlobalOrders() async {
    // Fetch from both brands concurrently
    final results = await Future.wait([
      OrderService.getMyOrders(brand: 'teasntrees'),
      OrderService.getMyOrders(brand: 'littleh'),
    ]);

    // Flatten and Sort by createdAt descending
    final allOrders = [...results[0], ...results[1]];
    allOrders.sort((a, b) {
      final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(0);
      final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(0);
      return dateB.compareTo(dateA);
    });

    return allOrders;
  }

  Future<void> fetchOrders({bool background = false}) async {
    if (!background) state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchGlobalOrders());
  }
}

final orderProvider = AsyncNotifierProvider<OrderNotifier, List<Order>>(() {
  return OrderNotifier();
});
