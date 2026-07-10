import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/models/order_model.dart';
import 'package:tnt_lh/services/auth_service.dart';

class OrderService {
  // Helper to get headers
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get Settings (Tax, Delivery Charge)
  static Future<Map<String, dynamic>> getSettings({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/settings', brand: brand);
    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

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
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

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
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

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
  }) async {
    // If specific items are provided, use the general orders endpoint.
    // This allows brand-specific checkout without clearing the entire cart.
    final path = (items != null && items.isNotEmpty)
        ? '/customer/orders'
        : '/customer/cart/checkout';

    final url = AppConfig.buildUrl(path, brand: brand);
    try {
      final headers = await _getHeaders();

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
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

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
    final headers = await _getHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({'reason': reason, if (notes != null) 'notes': notes}),
    );
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
    final headers = await _getHeaders();
    final hasCoords = latitude != null && longitude != null;
    final response = await http.patch(
      url,
      headers: headers,
      body: jsonEncode({
        'address': address,
        if (hasCoords)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Could not update the address');
  }
}
