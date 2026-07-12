import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/services/order_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/socket_provider.dart';

/// The customer's orders, a page at a time.
class OrdersState {
  final List<Order> orders;

  /// False once the server has no more pages, so the list can say "that's
  /// everything" instead of leaving the customer wondering if it's still loading.
  final bool hasMore;

  /// A further page is being appended. Distinct from the initial load: the list
  /// stays on screen and a spinner appears at the bottom.
  final bool isLoadingMore;

  const OrdersState({
    required this.orders,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  OrdersState copyWith({
    List<Order>? orders,
    bool? hasMore,
    bool? isLoadingMore,
  }) => OrdersState(
    orders: orders ?? this.orders,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// Orders used to be fetched as page 1 and nothing else, and the API caps a page
/// — so a customer with more than a page of history simply could not reach the
/// older ones. There was no "load more" and no end-of-list marker either; the
/// list just stopped, with no way to tell whether that was all of it.
///
/// It also made TWO requests, one per brand, then merged and sorted them on the
/// phone. That can't be paginated correctly: page 2 of a brand with three orders
/// is empty while the other brand still has fifty. The API already supports
/// `ignoreBrand`, which returns every brand's orders in one correctly sorted,
/// correctly paginated list — so this is now a single request as well.
class OrderNotifier extends AsyncNotifier<OrdersState> {
  static const _pageSize = 20;
  int _page = 1;

  @override
  FutureOr<OrdersState> build() async {
    final auth = ref.watch(authProvider);

    // Real-time updates. A new order, or a status change, makes the first page
    // stale — reload from the top rather than trying to patch the middle.
    ref.listen<SocketEvent?>(socketEventsProvider, (prev, next) {
      if (next != null) {
        if (next.name == 'order:status-updated' ||
            next.name == 'order:created') {
          refresh(background: true);
        }
      }
    });

    if (!auth.isAuthenticated) {
      return const OrdersState(orders: []);
    }
    return _loadFirstPage();
  }

  Future<OrdersState> _loadFirstPage() async {
    _page = 1;
    final result = await OrderService.getMyOrders(
      page: _page,
      limit: _pageSize,
      allBrands: true,
    );
    return OrdersState(orders: result.orders, hasMore: result.hasMore);
  }

  /// Pull-to-refresh, and the socket's "something changed" path.
  Future<void> refresh({bool background = false}) async {
    if (!background) state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadFirstPage);
  }

  /// Append the next page. Safe to call repeatedly — it no-ops while a page is
  /// already in flight, and once the server says there is nothing left.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final next = _page + 1;
      final result = await OrderService.getMyOrders(
        page: next,
        limit: _pageSize,
        allBrands: true,
      );
      _page = next;

      state = AsyncValue.data(
        OrdersState(
          orders: [...current.orders, ...result.orders],
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // A failed page must not wipe out the orders already on screen. Stop the
      // spinner and leave the list intact; scrolling again retries.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final orderProvider = AsyncNotifierProvider<OrderNotifier, OrdersState>(() {
  return OrderNotifier();
});
