import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/services/api_client.dart';

// Events
class SocketEvent {
  final String name;
  final dynamic data;
  SocketEvent(this.name, this.data);
}

class SocketEventsNotifier extends Notifier<SocketEvent?> {
  @override
  SocketEvent? build() => null;

  void emitEvent(SocketEvent event) {
    state = event;
  }
}

final socketEventsProvider =
    NotifierProvider<SocketEventsNotifier, SocketEvent?>(() {
      return SocketEventsNotifier();
    });

/// Bumped whenever the app may have missed live updates: the socket came back
/// after a drop, or the app returned from the background.
///
/// Socket.io does not replay what was sent while a phone was asleep, in a lift
/// or between towers. Before this, an order that was accepted, prepared and
/// picked up while the screen was locked stayed on its old status until the
/// customer pulled to refresh. Anything that shows live server data listens to
/// this and refetches.
class LiveRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final liveRefreshProvider = NotifierProvider<LiveRefreshNotifier, int>(
  LiveRefreshNotifier.new,
);

class SocketManager {
  io.Socket? _socket;

  /// The token the live socket authenticated with.
  ///
  /// Socket.io authenticates ONCE, at handshake. The access token now rotates
  /// roughly hourly, and this socket kept whatever token it was built with — so
  /// the moment it tried to reconnect (a tunnel, a lift, the app resuming) it
  /// re-handshook with a token that had since expired and the server refused it.
  /// That is the `Socket authentication error: Error: Invalid token` sitting in
  /// the production log, and the customer's live order tracking silently died
  /// with it. Rebuild the socket whenever the token changes.
  String? _token;

  final Ref ref;

  /// Whether any socket has connected yet in this run of the app. The first
  /// connection needs no catch-up refresh: everything was just loaded.
  bool _connectedOnce = false;

  /// When the socket last asked for a token refresh, so a server that keeps
  /// refusing us can't turn into a refresh loop.
  DateTime? _lastRefreshAttempt;

  late final AppLifecycleListener _lifecycle;

  SocketManager(this.ref) {
    // Only signing in and out matter here. Watching the whole auth state used
    // to rebuild on every profile edit and loading flag.
    ref.listen<bool>(authProvider.select((s) => s.isAuthenticated), (
      previous,
      next,
    ) {
      if (next) {
        connect();
      } else {
        disconnect();
      }
    }, fireImmediately: true);

    // Coming back to the app: the socket was very likely dropped while the
    // phone slept, and whatever happened meanwhile was never delivered.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    ref.onDispose(() {
      _lifecycle.dispose();
      disconnect();
    });
  }

  void _onResume() {
    if (!ref.read(authProvider).isAuthenticated) return;
    connect();
    ref.read(liveRefreshProvider.notifier).bump();
  }

  Future<void> connect() async {
    final token = await AuthService.getToken();
    if (token == null) return;

    if (_socket != null) {
      if (_token != token) {
        // Stale credentials: tear the old socket down rather than leaving it to
        // fail its next handshake.
        debugPrint('🔁 Socket: token changed, rebuilding');
        _teardown();
      } else if (_socket!.connected) {
        return; // already up, on the right token
      } else {
        _socket!.connect(); // same token, just asleep
        return;
      }
    }

    final socketUrl = AppConfig.socketUrl;
    debugPrint("🔌 Socket: Connecting to $socketUrl...");

    _token = token;
    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('✅ Socket: Connected');
      // A reconnect means there was a gap. Ask the screens to catch up.
      if (_connectedOnce) ref.read(liveRefreshProvider.notifier).bump();
      _connectedOnce = true;
    });
    _socket!.onDisconnect((_) => debugPrint('❌ Socket: Disconnected'));

    // An expired token is refused at the handshake. Fetch the current one and
    // rebuild — ApiClient refreshes on 401, so by now there usually IS a fresh
    // token sitting in storage; we were simply still holding the old one.
    _socket!.onConnectError((err) async {
      debugPrint('⚠️ Socket: connect error: $err');
      var latest = await AuthService.getToken();

      // Nothing else has refreshed the token (no API call happened since it
      // expired, say the app sat on the order screen), so the socket would
      // retry with the dead one forever. Refresh it ourselves, at most twice a
      // minute so a server that is down doesn't become a refresh loop.
      final authProblem =
          err.toString().toLowerCase().contains('token') ||
          err.toString().toLowerCase().contains('auth');
      final now = DateTime.now();
      if (latest == _token &&
          authProblem &&
          (_lastRefreshAttempt == null ||
              now.difference(_lastRefreshAttempt!) >
                  const Duration(seconds: 30))) {
        _lastRefreshAttempt = now;
        latest = await ApiClient.refreshSession();
      }

      if (latest != null && latest != _token) {
        _teardown();
        connect();
      }
    });

    // Listeners
    // The order journey: one event with the whole current state.
    _socket!.on('order:update', (data) {
      debugPrint('[socket] order:update $data');
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('order:update', data));
    });

    _socket!.on('order:status-updated', (data) {
      debugPrint('[socket] order:status-updated $data');
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('order:status-updated', data));
    });

    _socket!.on('order:created', (data) {
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('order:created', data));
    });

    // THE LIVE MAP NEVER MOVED. The backend broadcasts the rider's GPS to the
    // customer as `rider:location-update` on every push, and GlobalListener is
    // already wired to feed that into riderTrackingProvider — but this socket
    // never subscribed to the event, so it was dropped on the floor and the
    // tracking map sat frozen while the rider was actually moving.
    // An admin published or changed a banner/offer.
    // A category or product changed (picture, price, availability).
    _socket!.on('catalog:updated', (data) {
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('catalog:updated', data));
    });

    _socket!.on('promotions:updated', (data) {
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('promotions:updated', data));
    });

    _socket!.on('rider:location-update', (data) {
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('rider:location-update', data));
    });
  }

  /// `disconnect()` alone leaves the socket and every listener attached to it
  /// alive; dropping the reference then leaks them. Each rebuild used to add a
  /// fresh set on top of the old, so one long session could stack several
  /// sockets all emitting the same events.
  void _teardown() {
    _socket?.clearListeners();
    _socket?.dispose();
    _socket = null;
    _token = null;
  }

  void disconnect() {
    _socket?.disconnect();
    _teardown();
  }
}

// Provider to manage connection lifecycle
final socketManagerProvider = Provider<SocketManager>((ref) {
  return SocketManager(ref);
});
