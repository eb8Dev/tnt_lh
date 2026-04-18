import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tnt_lh/core/config.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static Future<Map<String, dynamic>> firebaseLogin(
    String idToken, {
    String? mobile,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/auth/firebase-login',
      brand: brand,
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          if (mobile != null) 'mobile': mobile,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _saveTokens(data['data']['token'], data['data']['refreshToken']);
        return data['data'];
      } else {
        throw data['message'] ?? 'Login failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> googleLogin({
    required String idToken,
    required String email,
    String? name,
    String? photoURL,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl('/customer/auth/google-login', brand: brand);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'email': email,
          if (name != null) 'name': name,
          if (photoURL != null) 'photoURL': photoURL,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _saveTokens(data['data']['token'], data['data']['refreshToken']);
        return data['data'];
      } else {
        throw data['message'] ?? 'Google Login failed';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<String?> refreshToken({String? brand}) async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) return null;

    final url = AppConfig.buildUrl(
      '/customer/auth/refresh-token',
      brand: brand,
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await _saveTokens(data['data']['token'], data['data']['refreshToken']);
        return data['data']['token'];
      } else {
        await logout(brand: brand);
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  static Future<void> _saveTokens(
    String accessToken,
    String refreshToken,
  ) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    String? token = await getToken();
    if (token == null) {
      throw 'Not authenticated';
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> getProfile({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/profile', brand: brand);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(url, headers: headers);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 401) {
        final newToken = await refreshToken(brand: brand);
        if (newToken != null) {
          final newHeaders = {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $newToken',
          };
          final retryResponse = await http.get(url, headers: newHeaders);
          final retryData = jsonDecode(retryResponse.body);
          if (retryResponse.statusCode == 200) {
            return retryData;
          }
        }
        throw 'Session expired, please login again';
      } else {
        throw data['message'] ?? 'Failed to fetch profile';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? email,
    String? address,
    String? brand,
    Map<String, bool>? notificationPreferences,
  }) async {
    final url = AppConfig.buildUrl('/customer/profile', brand: brand);
    try {
      final headers = await _getAuthHeaders();
      final body = {
        if (name != null) "name": name,
        if (email != null) "email": email,
        if (address != null) "address": address,
        if (notificationPreferences != null) "notificationPreferences": notificationPreferences,
      };

      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw data['message'] ?? 'Failed to update profile';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> completeProfile({
    required String name,
    required String email,
    required String address,
    String? mobile,
    Map<String, dynamic>? location,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl(
      '/customer/auth/complete-profile',
      brand: brand,
    );
    try {
      final headers = await _getAuthHeaders();

      final body = {
        "name": name,
        "email": email,
        "address": address,
        if (mobile != null) "mobile": mobile,
        if (location != null) "location": location,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['data'] != null && data['data']['token'] != null) {
          await _saveTokens(
            data['data']['token'],
            data['data']['refreshToken'],
          );
        }
        return data;
      } else {
        throw data['message'] ?? 'Failed to complete profile';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> getCategories({String? brand}) async {
    final url = AppConfig.buildUrl('/customer/categories', brand: brand);
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['data'] ?? [];
      } else {
        throw data['message'] ?? 'Failed to fetch categories';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<dynamic>> getProducts({
    String? categoryId,
    String? search,
    String? tags,
    String? brand,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['category'] = categoryId;
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (tags != null && tags.isNotEmpty) queryParams['tags'] = tags;

    final url = AppConfig.buildUrl(
      '/customer/products',
      brand: brand,
      queryParameters: queryParams,
    );

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['data'] is List) {
          return data['data'];
        }
        if (data['data'] is Map && data['data']['products'] != null) {
          return data['data']['products'];
        }
        return [];
      } else {
        throw data['message'] ?? 'Failed to fetch products';
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> logout({String? brand}) async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken != null) {
      final url = AppConfig.buildUrl('/customer/auth/logout', brand: brand);
      try {
        final token = await getToken();
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (e) {
        // Ignore errors during remote logout/revocation
      }
    }

    await firebase_auth.FirebaseAuth.instance.signOut();

    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
