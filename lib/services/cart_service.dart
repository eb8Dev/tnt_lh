import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/auth_service.dart';

class CartService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) throw 'Not authenticated';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getCart({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/cart', brand: brand);
    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      final dynamic data = jsonDecode(response.body);

      if (data is String) {
        debugPrint(
          "API Error: getCart returned a String instead of Map: $data",
        );
        return {
          'success': false,
          'message': data,
          'data': {'items': [], 'subtotal': 0, 'itemCount': 0},
        };
      }

      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      } else {
        if (response.statusCode == 404) {
          return {
            'success': true,
            'data': {'items': [], 'subtotal': 0, 'itemCount': 0},
          };
        }
        throw data['message'] ?? 'Failed to fetch cart';
      }
    } catch (e) {
      debugPrint("CartService.getCart error: $e");
      rethrow;
    }
  }

  static Future<void> addToCart({
    required String productId,
    required int quantity,
    String? brand,
    String? customization,
  }) async {
    final url = AppConfig.buildUrl('/customer/cart/add', brand: brand);
    try {
      final headers = await _getHeaders();
      final body = {
        "productId": productId,
        "quantity": quantity,
        if (brand != null) "brand": brand,
        if (customization != null) "customization": customization,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      } else {
        throw data['message'] ?? 'Failed to add to cart';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateItemQuantity(
    String itemId,
    int quantity, {
    String? brand,
  }) async {
    final url = AppConfig.buildUrl('/customer/cart/item/$itemId', brand: brand);
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({"quantity": quantity}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return;
      } else {
        throw data['message'] ?? 'Failed to update item';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> removeItem(String itemId, {String? brand}) async {
    final url = AppConfig.buildUrl('/customer/cart/item/$itemId', brand: brand);
    try {
      final headers = await _getHeaders();
      final response = await http.delete(url, headers: headers);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return;
      } else {
        throw data['message'] ?? 'Failed to remove item';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> clearCart({String? brand}) async {
    // Backend requires a brand identifier in the URL even for global cart operations
    final targetBrand = brand ?? AppConfig.defaultBrand;
    final url = AppConfig.buildUrl('/customer/cart', brand: targetBrand);
    
    debugPrint("CartService.clearCart: calling DELETE $url");
    try {
      final headers = await _getHeaders();
      final response = await http.delete(url, headers: headers);

      debugPrint(
        "CartService.clearCart: response status: ${response.statusCode}",
      );
      debugPrint("CartService.clearCart: response body: ${response.body}");

      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404) {
        // Handle suspicious 'Catched' response or failure flags
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == false || data['message'] == 'Catched') {
            throw data['message'] ?? 'Failed to clear cart (Server error)';
          }
        }
        return;
      } else {
        final data = jsonDecode(response.body);
        throw data['message'] ?? 'Failed to clear cart';
      }
    } catch (e) {
      debugPrint("CartService.clearCart error: $e");
      rethrow;
    }
  }
}
