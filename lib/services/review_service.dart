import 'dart:convert';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';

class ReviewService {
  /// Rate a delivered order: food + rider stars, plus an optional written
  /// review. The backend only accepts this for delivered/completed orders.
  static Future<Map<String, dynamic>> submitOrderReview({
    required String orderId,
    required int foodRating,
    required int riderRating,
    String? review,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl('/customer/reviews', brand: brand);
    final response = await ApiClient.post(
      url,
      body: {
        'orderId': orderId,
        'foodRating': foodRating,
        'riderRating': riderRating,
        if (review != null && review.isNotEmpty) 'review': review,
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Could not submit your rating');
  }
}
