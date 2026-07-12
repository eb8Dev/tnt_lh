import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/providers/auth_provider.dart';
import 'package:tnt_lh/core/config.dart';

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

  SocketManager(this.ref) {
    // Watch auth to connect/disconnect
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        connect();
      } else {
        disconnect();
      }
    });
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

    _socket!.onConnect((_) => debugPrint('✅ Socket: Connected'));
    _socket!.onDisconnect((_) => debugPrint('❌ Socket: Disconnected'));

    // An expired token is refused at the handshake. Fetch the current one and
    // rebuild — ApiClient refreshes on 401, so by now there usually IS a fresh
    // token sitting in storage; we were simply still holding the old one.
    _socket!.onConnectError((err) async {
      debugPrint('⚠️ Socket: connect error: $err');
      final latest = await AuthService.getToken();
      if (latest != null && latest != _token) {
        _teardown();
        connect();
      }
    });

    // Listeners
    _socket!.on('order:status-updated', (data) {
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('order:status-updated', data));
    });

    _socket!.on('order:created', (data) {
      ref
          .read(socketEventsProvider.notifier)
          .emitEvent(SocketEvent('order:created', data));
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
