import 'dart:convert';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';

/// Result of validating a coupon at checkout.
class CouponResult {
  final String code;
  final double discountAmount;
  final String? description;

  CouponResult({
    required this.code,
    required this.discountAmount,
    this.description,
  });
}

class CouponService {
  /// Validate a coupon code against the current order value. Throws with the
  /// backend's reason (expired / min order / wrong brand / …) on failure.
  static Future<CouponResult> validate({
    required String code,
    required double orderValue,
    required String brand,
  }) async {
    final url = AppConfig.buildUrl('/customer/coupons/validate', brand: brand);
    final response = await ApiClient.post(
      url,
      body: {
        'couponCode': code.trim(),
        'orderValue': orderValue,
        'brand': brand,
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final d = data['data'] ?? {};
      return CouponResult(
        code: d['couponCode'] ?? code.trim().toUpperCase(),
        discountAmount: (d['discountAmount'] ?? 0).toDouble(),
        description: d['description'],
      );
    }
    throw Exception(data['message'] ?? 'Invalid coupon code');
  }
}
