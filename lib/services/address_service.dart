import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/models/address_model.dart';
import 'package:tnt_lh/services/auth_service.dart';

class AddressService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) throw Exception('Not authenticated');
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
  }

  static Future<List<SavedAddress>> getAddresses({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/address', brand: brand);
    final response = await http.get(url, headers: await _headers());
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    final list = data['data'] ?? data['addresses'] ?? [];
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SavedAddress.fromJson)
        .toList();
  }

  static Future<SavedAddress?> addAddress({
    required String label,
    required String addressLine,
    double? latitude,
    double? longitude,
    bool isDefault = false,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl('/customer/address', brand: brand);
    final hasCoords = latitude != null && longitude != null;
    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'label': label,
        'addressLine': addressLine,
        'isDefault': isDefault,
        if (hasCoords)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final addr = data['data'] ?? data['address'];
      return addr is Map<String, dynamic> ? SavedAddress.fromJson(addr) : null;
    }
    throw Exception(data['message'] ?? 'Could not save the address');
  }

  static Future<void> setDefault(String addressId, {String? brand}) async {
    final url = AppConfig.buildUrl(
      '/customer/address/$addressId/default',
      brand: brand,
    );
    await http.put(url, headers: await _headers());
  }

  static Future<void> deleteAddress(String addressId, {String? brand}) async {
    final url = AppConfig.buildUrl(
      '/customer/address/$addressId',
      brand: brand,
    );
    await http.delete(url, headers: await _headers());
  }
}
