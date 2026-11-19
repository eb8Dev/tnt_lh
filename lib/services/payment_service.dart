import 'dart:convert';

import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';

/// The server side of online payment (backend: services/paymentService.js).
/// The amount is always the server's: the app never says what to charge.
class PaymentService {
  PaymentService._();

  /// Whether this customer can pay this store online right now. Any failure
  /// means "no": checkout then simply offers cash.
  static Future<bool> onlineAvailable(String brand) async {
    try {
      final res = await ApiClient.get(
        AppConfig.buildUrl('/customer/payments/options', brand: brand),
      );
      if (res.statusCode != 200) return false;
      return jsonDecode(res.body)['data']?['online'] == true;
    } catch (_) {
      return false;
    }
  }

  /// What Razorpay's checkout needs for these unpaid orders.
  static Future<Map<String, dynamic>> start(
    List<String> orderIds,
    String brand,
  ) => _post('/customer/payments/create-order', brand, {'orderIds': orderIds});

  /// Razorpay's success callback, checked and settled by the server.
  static Future<void> verify({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String signature,
    required String brand,
  }) => _post('/customer/payments/verify-payment', brand, {
    'razorpay_order_id': razorpayOrderId,
    'razorpay_payment_id': razorpayPaymentId,
    'razorpay_signature': signature,
  });

  /// An unpaid online order becomes cash on delivery.
  static Future<void> payCash(List<String> orderIds, String brand) =>
      _post('/customer/payments/pay-cash', brand, {'orderIds': orderIds});

  static Future<Map<String, dynamic>> _post(
    String path,
    String brand,
    Map<String, dynamic> body,
  ) async {
    final res = await ApiClient.post(
      AppConfig.buildUrl(path, brand: brand),
      body: body,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['success'] == true) {
      return (data['data'] as Map?)?.cast<String, dynamic>() ?? {};
    }
    throw Exception(data['message'] ?? 'Something went wrong with the payment');
  }
}
