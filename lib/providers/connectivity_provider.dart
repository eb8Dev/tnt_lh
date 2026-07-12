import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone has a usable network connection.
///
/// The rider app got this in its hardening pass; the customer app never had it.
/// A dropped connection was completely silent here: adding to the cart, applying
/// a coupon, or placing an order simply failed with a generic error, and the
/// customer had no way to tell that the phone — not the app, and not their card
/// — was the problem. They'd usually just try again, which for checkout is the
/// worst possible response.
class ConnectivityNotifier extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final Connectivity _connectivity = Connectivity();

  @override
  bool build() {
    _listen();
    ref.onDispose(() => _sub?.cancel());
    return true; // assume online until told otherwise
  }

  Future<void> _listen() async {
    try {
      _apply(await _connectivity.checkConnectivity());
    } catch (_) {
      // If we can't tell, assume online rather than blocking the customer out
      // of an app that might be working perfectly well.
      state = true;
    }
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    // `none` is the only result that reliably means "no network". Anything else
    // (wifi, mobile, ethernet, vpn) we treat as online — connectivity_plus only
    // reports the *interface*, not whether it actually reaches the internet, so
    // being stricter here would produce false "you're offline" banners on
    // captive portals we can't detect anyway.
    final offline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (state == !offline) return;
    state = !offline;
  }
}

/// True when the phone has a network connection.
final connectivityProvider = NotifierProvider<ConnectivityNotifier, bool>(
  ConnectivityNotifier.new,
);
