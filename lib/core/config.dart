import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // Debug builds hit the local emulator host; release builds fall back to
  // production HTTPS if Remote Config is unavailable. Remote Config `base_url`
  // overrides either at runtime.
  static const String _prodBaseUrl = "https://api.teasntrees.in/api";
  static const String _devBaseUrl = "http://10.0.2.2:5000/api";
  // Testers (and debug runs) hit production — we don't run a local backend
  // anymore. Flip _useLocalBackend to true only when actively developing the
  // API against a local emulator.
  static const bool _useLocalBackend = false;

  /// A developer's own API, for one run:
  ///   flutter run --dart-define=API_BASE=http://localhost:5000/api
  /// Wins over Remote Config. Ignored in release builds.
  static const String _apiOverride = String.fromEnvironment('API_BASE');
  static bool get _overridden => _apiOverride.isNotEmpty && !kReleaseMode;

  static String _baseUrl = _overridden
      ? _apiOverride
      : (_useLocalBackend && kDebugMode)
      ? _devBaseUrl
      : _prodBaseUrl;
  static const String defaultBrand = "teasntrees";

  // Google Maps / Directions API key (dev; rotate + restrict for prod).
  // Matches the key in AndroidManifest.xml and ios/Runner/AppDelegate.swift.
  static const String googleMapsApiKey =
      "AIzaSyDHqos-W9V4xEohQJUmViexhuZ1eSX_vls";

  static String get baseUrl => _baseUrl;

  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return "${uri.scheme}://${uri.host}:${uri.port}";
  }

  static Future<void> initializeRemoteConfig() async {
    if (_overridden) {
      debugPrint('API: using $_apiOverride (API_BASE)');
      return;
    }
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
      await remoteConfig.setDefaults({"base_url": _baseUrl});

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
