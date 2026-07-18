import 'dart:convert';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';
import 'package:tnt_lh/models/order_model.dart';

/// A page of orders, plus whether the server has more.
class OrdersPage {
  final List<Order> orders;
  final bool hasMore;
  const OrdersPage({required this.orders, required this.hasMore});
}

class OrderService {
  // Helper to get headers

  /// Get Settings (Tax, Delivery Charge)
  static Future<Map<String, dynamic>> getSettings({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/settings', brand: brand);
    try {
      final response = await ApiClient.get(url);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['data'] ?? {};
      } else {
        // Fallback defaults if endpoint fails/not ready
        return {'deliveryCharge': 50, 'gstRate': 5};
      }
    } catch (e) {
      // Fallback
      return {'deliveryCharge': 50, 'gstRate': 5};
    }
  }

  /// One page of the customer's orders.
  ///
  /// The caller needs to know whether there is more to come, not just what came
  /// back — otherwise a list can't tell "that's everything" from "still loading",
  /// which is exactly why the orders screen had no end-of-list marker.
  static Future<OrdersPage> getMyOrders({
    int page = 1,
    int limit = 20,
    String? brand,
    /// Return every brand's orders in ONE correctly sorted, correctly paginated
    /// list. The app used to fetch each brand separately and merge them on the
    /// phone, which cannot be paginated: page 2 of a brand with three orders is
    /// empty while the other brand still has fifty.
    bool allBrands = false,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (allBrands) 'ignoreBrand': 'true',
    };
    final url = AppConfig.buildUrl(
      '/customer/orders/my-orders',
      brand: brand,
      queryParameters: queryParams,
    );
    try {
      final response = await ApiClient.get(url);

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Failed to fetch orders');
      }

      final payload = data['data'];
      final List<dynamic> ordersJson =
          (payload is Map ? payload['orders'] : payload) ?? [];
      final orders = ordersJson.map((json) => Order.fromJson(json)).toList();

      // Prefer the server's own pagination block. Fall back to "a full page came
      // back, so there is probably another" if it isn't there.
      final pagination = payload is Map ? payload['pagination'] : null;
      final bool hasMore;
      if (pagination is Map && pagination['totalPages'] != null) {
        hasMore = page < (pagination['totalPages'] as num).toInt();
      } else {
        hasMore = orders.length >= limit;
      }

      return OrdersPage(orders: orders, hasMore: hasMore);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  /// Get Order Details
  static Future<Order> getOrderById(String id, {String? brand}) async {
    final url = AppConfig.buildUrl('/customer/orders/$id', brand: brand);
    try {
      final response = await ApiClient.get(url);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return Order.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch order details');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Create Order (Checkout)
  static Future<Map<String, dynamic>> createOrder({
    required String deliveryAddress,
    String? deliveryInstructions,
    String paymentMethod = "COD",
    double? latitude,
    double? longitude,
    String? brand,
    List<Map<String, dynamic>>? items,
    String? couponCode,
    /// Stable across retries of the SAME checkout. Lets the server recognise a
    /// replay and hand back the order it already made, instead of making
    /// another one. See CheckoutScreen, which holds the key until success.
    String? idempotencyKey,
    String? alternatePhone,
  }) async {
    // If specific items are provided, use the general orders endpoint.
    // This allows brand-specific checkout without clearing the entire cart.
    final path = (items != null && items.isNotEmpty)
        ? '/customer/orders'
        : '/customer/cart/checkout';

    final url = AppConfig.buildUrl(path, brand: brand);
    try {

      final bool hasCoords = latitude != null && longitude != null;
      // The two endpoints disagree on where the point lives: /cart/checkout
      // reads deliveryAddress.location, /orders reads the top-level location.
      // Send both so the rider gets coordinates either way. GeoJSON is [lng,lat].
      final Map<String, dynamic>? point = hasCoords
          ? {
              "type": "Point",
              "coordinates": [longitude, latitude],
            }
          : null;

      final body = {
        "deliveryAddress": hasCoords
            ? {"address": deliveryAddress, "location": point}
            : deliveryAddress,
        "paymentMethod": paymentMethod,
        if (deliveryInstructions != null)
          "deliveryInstructions": deliveryInstructions,
        if (point != null) "location": point,
        if (items != null) "items": items,
        if (couponCode != null && couponCode.isNotEmpty)
          "couponCode": couponCode,
        if (alternatePhone != null && alternatePhone.isNotEmpty)
          "alternatePhone": alternatePhone,
      };

      final response = await ApiClient.post(
        url,
        body: body,
        headers: idempotencyKey == null
            ? null
            : {'X-Idempotency-Key': idempotencyKey},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      }

      // The same checkout is still being processed on the server. Retrying is
      // exactly the wrong move — that's what used to duplicate the order.
      if (response.statusCode == 409 && data['inProgress'] == true) {
        throw Exception(
          data['message'] ??
              "We're still placing that order. Check your orders in a moment.",
        );
      }

      throw Exception(data['message'] ?? 'Failed to create order');
    } catch (e) {
      // ApiClient already throws readable messages for timeouts and dead
      // connections; wrapping them in "Network error: Exception: ..." just
      // buried them.
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  /// Re-place a past order (same items + address, COD). The backend creates a
  /// brand-new order and returns it.
  static Future<Map<String, dynamic>> reorder({
    required String orderId,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/orders/$orderId/reorder',
      brand: brand,
    );
    final response = await ApiClient.post(url);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Could not re-place this order');
  }

  /// Fetch the invoice PDF bytes (endpoint is auth-protected, so we can't just
  /// open the URL in a browser).
  static Future<List<int>> fetchInvoice({
    required String orderId,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/orders/$orderId/invoice',
      brand: brand,
    );
    final response = await ApiClient.get(url);
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Could not download the invoice');
  }

  /// Raise an issue against an order after a rider is assigned.
  static Future<Map<String, dynamic>> raiseComplaint({
    required String orderId,
    required String reason,
    String? notes,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/orders/$orderId/complaint',
      brand: brand,
    );
    final response = await ApiClient.post(url, body: {'reason': reason, if (notes != null) 'notes': notes});
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Could not submit your issue');
  }

  /// Edit the delivery address. The backend rejects this once the rider has
  /// picked up the order (409).
  static Future<Map<String, dynamic>> updateAddress({
    required String orderId,
    required String address,
    double? latitude,
    double? longitude,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/orders/$orderId/address',
      brand: brand,
    );
    final hasCoords = latitude != null && longitude != null;
    final response = await ApiClient.patch(url, body: {
        'address': address,
        if (hasCoords)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      });
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Could not update the address');
  }
}
