import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/auth_service.dart';

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
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  /// Validate a coupon code against the current order value. Throws with the
  /// backend's reason (expired / min order / wrong brand / …) on failure.
  static Future<CouponResult> validate({
    required String code,
    required double orderValue,
    required String brand,
  }) async {
    final url = AppConfig.buildUrl('/customer/coupons/validate', brand: brand);
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'couponCode': code.trim(),
        'orderValue': orderValue,
        'brand': brand,
      }),
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
