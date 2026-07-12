import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/auth_service.dart';

/// Personalisation the backend already computes for us: which offers apply to
/// this customer, whether they still owe a rating, and whether they're new.
class CustomerStatus {
  final bool showWelcomeBanner;
  final String? suggestedBrand;
  final List<String> activeOffers;
  final String? orderAwaitingRating;

  const CustomerStatus({
    this.showWelcomeBanner = false,
    this.suggestedBrand,
    this.activeOffers = const [],
    this.orderAwaitingRating,
  });

  factory CustomerStatus.fromJson(Map<String, dynamic> json) {
    final offers = json['activeOffers'];
    final pending = json['lastOrderRatingPending'];
    return CustomerStatus(
      showWelcomeBanner: json['showWelcomeBanner'] ?? false,
      suggestedBrand: json['suggestedBrand'],
      activeOffers: offers is List
          ? offers.map((e) => e.toString()).toList()
          : const [],
      orderAwaitingRating: (pending == null || pending.toString().isEmpty)
          ? null
          : pending.toString(),
    );
  }
}

class StatusService {
  static Future<CustomerStatus> fetch({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/status', brand: brand);
    final token = await AuthService.getToken();
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) return const CustomerStatus();
    final data = jsonDecode(response.body);
    if (data['success'] != true || data['data'] == null) {
      return const CustomerStatus();
    }
    return CustomerStatus.fromJson(data['data']);
  }
}
