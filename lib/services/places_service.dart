import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';

/// One search suggestion: "Manuen Infotech" / "Brodipet, Guntur".
class PlaceSuggestion {
  final String placeId;
  final String title;
  final String subtitle;
  const PlaceSuggestion(this.placeId, this.title, this.subtitle);
}

class PlaceDetails {
  final double lat;
  final double lng;
  final String name;
  final String address;
  const PlaceDetails(this.lat, this.lng, this.name, this.address);
}

/// Google Places (New) search for the address picker.
///
/// The picker used to search with the phone's built-in geocoder, which only
/// understands street addresses: "Manuen Infotech", a shop, a hospital or an
/// apartment's name found nothing. Places knows them, and suggests as you type.
///
/// A session token ties the typing and the final pick into one billed session,
/// which is how Google prices autocomplete.
class PlacesService {
  PlacesService._();

  static const _base = 'https://places.googleapis.com/v1';

  static String newSessionToken() {
    final r = Random.secure();
    return List.generate(
      16,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  static Map<String, String> _headers({String? fieldMask}) => {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
    // Lets the key be restricted to this app in the Cloud console.
    if (defaultTargetPlatform == TargetPlatform.iOS)
      'X-Ios-Bundle-Identifier': 'com.manuen.tntLh',
    if (defaultTargetPlatform == TargetPlatform.android)
      'X-Android-Package': 'com.manuen.tnt_lh',
    'X-Goog-FieldMask': ?fieldMask,
  };

  /// Suggestions for what has been typed so far, nearest first around
  /// [nearLat]/[nearLng]. Throws if Places can't be used (not enabled for the
  /// key, offline), so the caller can fall back.
  static Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    required String sessionToken,
    double? nearLat,
    double? nearLng,
  }) async {
    final body = {
      'input': input,
      'sessionToken': sessionToken,
      'includedRegionCodes': ['in'],
      if (nearLat != null && nearLng != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': nearLat, 'longitude': nearLng},
            'radius': 30000.0,
          },
        },
      if (nearLat != null && nearLng != null)
        'origin': {'latitude': nearLat, 'longitude': nearLng},
    };
    final res = await http
        .post(
          Uri.parse('$_base/places:autocomplete'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Places search unavailable (${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final out = <PlaceSuggestion>[];
    for (final s in (data['suggestions'] as List? ?? const [])) {
      final p = s['placePrediction'];
      if (p == null) continue;
      final f = p['structuredFormat'];
      out.add(
        PlaceSuggestion(
          p['placeId'] as String,
          (f?['mainText']?['text'] ?? p['text']?['text'] ?? '') as String,
          (f?['secondaryText']?['text'] ?? '') as String,
        ),
      );
    }
    return out;
  }

  static Future<PlaceDetails> details(
    String placeId, {
    required String sessionToken,
  }) async {
    final res = await http
        .get(
          Uri.parse('$_base/places/$placeId?sessionToken=$sessionToken'),
          headers: _headers(fieldMask: 'location,formattedAddress,displayName'),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Place lookup failed (${res.statusCode})');
    }
    final d = jsonDecode(res.body) as Map<String, dynamic>;
    return PlaceDetails(
      (d['location']['latitude'] as num).toDouble(),
      (d['location']['longitude'] as num).toDouble(),
      (d['displayName']?['text'] ?? '') as String,
      (d['formattedAddress'] ?? '') as String,
    );
  }
}
