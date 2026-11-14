import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/models/promotion_model.dart';
import 'package:tnt_lh/providers/socket_provider.dart';

/// The store's live promotions. Refetched the moment an admin publishes,
/// edits or switches one off (the server announces it over the live
/// connection), and after a reconnect or coming back to the app.
final promotionsProvider = FutureProvider.family<List<Promotion>, String>((
  ref,
  brand,
) async {
  ref.listen<SocketEvent?>(socketEventsProvider, (_, e) {
    if (e?.name == 'promotions:updated') ref.invalidateSelf();
  });
  ref.listen<int>(liveRefreshProvider, (_, _) => ref.invalidateSelf());

  final res = await http
      .get(AppConfig.buildUrl('/customer/promotions', brand: brand))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) return const [];
  final data = jsonDecode(res.body)['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(Promotion.fromJson)
      .toList();
});

/// Count a view or a tap; fire and forget.
void trackPromotion(String brand, String id, String event) {
  http
      .post(AppConfig.buildUrl('/customer/promotions/$id/$event', brand: brand))
      .timeout(const Duration(seconds: 10))
      .then((_) {}, onError: (_) {});
}
