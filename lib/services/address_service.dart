import 'dart:convert';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';
import 'package:tnt_lh/models/address_model.dart';

class AddressService {
  static Future<List<SavedAddress>> getAddresses({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/address', brand: brand);
    final response = await ApiClient.get(url);
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
    final response = await ApiClient.post(
      url,
      body: {
        'label': label,
        'addressLine': addressLine,
        'isDefault': isDefault,
        if (hasCoords)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final addr = data['data'] ?? data['address'];
      return addr is Map<String, dynamic> ? SavedAddress.fromJson(addr) : null;
    }
    throw Exception(data['message'] ?? 'Could not save the address');
  }

  /// Edit a saved address. The backend already had `PUT /:addressId`; the app
  /// just never called it, so the profile could add and delete addresses but
  /// not correct one — you had to delete and re-add.
  static Future<SavedAddress?> updateAddress({
    required String addressId,
    required String label,
    required String addressLine,
    double? latitude,
    double? longitude,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/address/$addressId',
      brand: brand,
    );
    final hasCoords = latitude != null && longitude != null;
    final response = await ApiClient.put(
      url,
      body: {
        'label': label,
        'addressLine': addressLine,
        if (hasCoords)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final addr = data['data'] ?? data['address'];
      return addr is Map<String, dynamic> ? SavedAddress.fromJson(addr) : null;
    }
    throw Exception(data['message'] ?? 'Could not update the address');
  }

  static Future<void> setDefault(String addressId, {String? brand}) async {
    final url = AppConfig.buildUrl(
      '/customer/address/$addressId/default',
      brand: brand,
    );
    await ApiClient.put(url);
  }

  static Future<void> deleteAddress(String addressId, {String? brand}) async {
    final url = AppConfig.buildUrl(
      '/customer/address/$addressId',
      brand: brand,
    );
    await ApiClient.delete(url);
  }
}
