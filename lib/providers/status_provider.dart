import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/services/status_service.dart';

/// Per-customer personalisation (offers they can use, a rating they still owe).
/// Refetched when the brand or auth state changes.
final customerStatusProvider = FutureProvider<CustomerStatus>((ref) async {
  final signedIn = ref.watch(authProvider.select((s) => s.isAuthenticated));
  final brand = ref.watch(brandProvider);
  if (!signedIn) return const CustomerStatus();
  return StatusService.fetch(brand: brand);
});
