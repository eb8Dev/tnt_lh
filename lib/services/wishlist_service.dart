import 'dart:convert';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';

class WishlistService {

  static Future<List<dynamic>> getWishlist({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/wishlist', brand: brand);
    try {
      final response = await ApiClient.get(url);

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
      final response = await ApiClient.post(url, body: {"productId": productId});

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
      final response = await ApiClient.delete(url);

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw data['message'] ?? 'Failed to remove from wishlist';
      }
    } catch (e) {
      rethrow;
    }
  }
}
