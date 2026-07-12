import 'dart:convert';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';
import 'package:tnt_lh/models/order_model.dart';

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

  /// Get My Orders
  static Future<List<Order>> getMyOrders({
    int page = 1,
    int limit = 20,
    String? brand,
  }) async {
    final queryParams = {'page': page.toString(), 'limit': limit.toString()};
    final url = AppConfig.buildUrl(
      '/customer/orders/my-orders',
      brand: brand,
      queryParameters: queryParams,
    );
    try {
      final response = await ApiClient.get(url);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> ordersJson =
            data['data']['orders'] ?? data['data'] ?? [];
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch orders');
      }
    } catch (e) {
      throw Exception('Network error: $e');
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
      };

      final response = await ApiClient.post(url, body: body);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      throw Exception('Network error: $e');
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
