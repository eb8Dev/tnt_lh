import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/auth_service.dart';

class UploadService {
  /// Upload a single image and get back its hosted URL.
  static Future<String> uploadImage(File file, {String? folder, String? brand}) async {
    final url = AppConfig.buildUrl(
      '/customer/upload/image',
      brand: brand,
      queryParameters: folder != null ? {'folder': folder} : null,
    );
    final token = await AuthService.getToken();

    final request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('image', file.path));
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final uploaded = data['data']?['url'];
      if (uploaded is String && uploaded.isNotEmpty) return uploaded;
    }
    throw Exception(data['message'] ?? 'Could not upload the image');
  }
}
