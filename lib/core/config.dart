import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  static String _baseUrl = "http://10.0.2.2:5000/api";
  static const String defaultBrand = "teasntrees";

  static String get baseUrl => _baseUrl;

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return "${uri.scheme}://${uri.host}:${uri.port}";
  }

  static Future<void> initializeRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Settings for fetch timeout and minimum fetch interval
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: kDebugMode
              ? const Duration(minutes: 1)
              : const Duration(minutes: 1),
        ),
      );

      // Default values
      await remoteConfig.setDefaults({"base_url": "http://10.0.2.2:5000/api"});

      // Fetch and activate
      await remoteConfig.fetchAndActivate();

      String remoteBaseUrl = remoteConfig.getString("base_url");
      if (remoteBaseUrl.isNotEmpty) {
        // Robustly ensure the base URL includes the /api suffix if expected
        if (!remoteBaseUrl.endsWith('/api') &&
            !remoteBaseUrl.contains('/api/')) {
          if (remoteBaseUrl.endsWith('/')) {
            remoteBaseUrl = '${remoteBaseUrl}api';
          } else {
            remoteBaseUrl = '$remoteBaseUrl/api';
          }
        }
        _baseUrl = remoteBaseUrl;
      }
      debugPrint("Remote Config: Base URL set to $_baseUrl");
    } catch (e) {
      debugPrint("Remote Config: Error initializing: $e");
      // Keep using default _baseUrl if fetch fails
    }
  }

  static Uri buildUrl(
    String path, {
    String? brand,
    Map<String, dynamic>? queryParameters,
    bool includeBrandSegment = true,
  }) {
    final formattedPath = path.startsWith('/') ? path : '/$path';

    // Normalize baseUrl - remove trailing slash if present
    String normalizedBase = baseUrl;
    if (normalizedBase.endsWith('/')) {
      normalizedBase = normalizedBase.substring(0, normalizedBase.length - 1);
    }

    if (path.startsWith('/rider')) {
      return Uri.parse('$normalizedBase$formattedPath').replace(
        queryParameters: queryParameters?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );
    }

    if (!includeBrandSegment) {
      return Uri.parse('$normalizedBase$formattedPath').replace(
        queryParameters: queryParameters?.map(
          (k, v) => MapEntry(k, v.toString()),
        ),
      );
    }

    final brandSegment = brand ?? defaultBrand;
    return Uri.parse('$normalizedBase/$brandSegment$formattedPath').replace(
      queryParameters: queryParameters?.map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );
  }
}
