import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/auth_service.dart';

class WishlistService {
  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.getToken();
    if (token == null) throw 'Not authenticated';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<dynamic>> getWishlist({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/wishlist', brand: brand);
    try {
      final headers = await _getHeaders();
      final response = await http.get(url, headers: headers);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['data'] ?? [];
      } else {
        throw data['message'] ?? 'Failed to fetch wishlist';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> addToWishlist(String productId, {String? brand}) async {
    final url = AppConfig.buildUrl('/customer/wishlist', brand: brand);
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"productId": productId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw data['message'] ?? 'Failed to add to wishlist';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> removeFromWishlist(
    String productId, {
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/wishlist/$productId',
      brand: brand,
    );
    try {
      final headers = await _getHeaders();
      final response = await http.delete(url, headers: headers);

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw data['message'] ?? 'Failed to remove from wishlist';
      }
    } catch (e) {
      rethrow;
    }
  }
}
