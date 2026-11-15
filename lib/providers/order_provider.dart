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
    // Signing in or out is what matters. Watching the whole auth state reloaded
    // the list (and threw away every page loaded past the first) whenever the
    // profile was edited or a loading flag flipped.
    final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));

    // Back from the background, or the socket reconnected: updates may have
    // been missed, so reload quietly.
    ref.listen<int>(liveRefreshProvider, (_, _) {
      if (signedIn) refresh(background: true);
    });

    // Real-time updates. A new order, or a status change, makes the first page
    // stale — reload from the top rather than trying to patch the middle.
    ref.listen<SocketEvent?>(socketEventsProvider, (prev, next) {
      if (next != null) {
        if (next.name == 'order:status-updated' ||
            next.name == 'order:update' ||
            next.name == 'order:created') {
          refresh(background: true);
        }
      }
    });

    if (!signedIn) {
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
    final result = await AsyncValue.guard(_loadFirstPage);
    // A quiet refresh that fails (a flaky signal on resume) must not replace
    // the orders on screen with an error page.
    if (background && result is AsyncError && state.hasValue) return;
    state = result;
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

/// An order that hasn't finished, and whether it has gone quiet.
typedef ActiveOrder = ({Order order, bool delayed});

/// The most recent order that is still in progress, or null.
///
/// Feeds the persistent "your order is on the way" bar that testers asked to see
/// while browsing other pages. Derived from [orderProvider] so it stays in sync
/// with the socket-driven status updates for free.
///
/// "Not finished" is not the same as "in progress". An order the store or rider
/// never closed out stays in a live status forever, and the bar used to keep
/// promising "On the way to you" for months. These are same-city deliveries
/// that take an hour or two, so:
///  - nothing has moved for [_delayedAfter]: still shown, but flagged
///    `delayed` so the bar stops promising and offers help instead;
///  - nothing has moved for [_abandonedAfter]: no longer treated as active at
///    all. It stays in the Orders tab, where it can be reported.
const _delayedAfter = Duration(hours: 3);
const _abandonedAfter = Duration(hours: 24);

/// Ticks once a minute, so the "delayed" and "abandoned" cut-offs below are
/// re-checked as time passes, not only when the order list happens to reload.
final _minuteTickProvider = StreamProvider<int>(
  (ref) => Stream.periodic(const Duration(minutes: 1), (i) => i),
);

final activeOrderProvider = Provider<ActiveOrder?>((ref) {
  ref.watch(_minuteTickProvider);
  final orders = ref.watch(orderProvider).value?.orders ?? const <Order>[];

  // Terminal states — anything else is still live.
  const done = {'delivered', 'completed', 'cancelled', 'rejected', 'refunded'};

  final now = DateTime.now();
  for (final o in orders) {
    if (done.contains(o.status.toLowerCase())) continue;

    // No timestamp at all: assume it's current rather than hide a live order.
    final quietFor = o.lastActivity == null
        ? Duration.zero
        : now.difference(o.lastActivity!);
    if (quietFor >= _abandonedAfter) continue;

    return (order: o, delayed: quietFor >= _delayedAfter);
  }
  return null;
});
