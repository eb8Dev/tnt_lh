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
    Map<String, dynamic>? location,
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
      final body = {
        "deliveryAddress": deliveryAddress,
        "paymentMethod": paymentMethod,
        if (deliveryInstructions != null)
          "deliveryInstructions": deliveryInstructions,
        if (location != null) "location": location,
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
}
