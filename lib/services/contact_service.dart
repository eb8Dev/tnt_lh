import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';

class ContactService {
  static Future<void> submitContactForm({
    required String firstName,
    String? lastName,
    required String email,
    required String subject,
    required String message,
    String? brand,
  }) async {
    final url = AppConfig.buildUrl('/v1/contact', brand: brand);
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
          'email': email,
          'subject': subject,
          'message': message,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw data['message'] ?? 'Failed to send message';
      }
    } catch (e) {
      rethrow;
    }
  }
}
