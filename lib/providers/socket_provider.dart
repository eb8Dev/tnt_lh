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

  void connect() async {
    if (_socket?.connected == true) return;

    final token = await AuthService.getToken();
    if (token == null) return;

    final socketUrl = AppConfig.socketUrl;

    debugPrint("🔌 Socket: Connecting to $socketUrl...");

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

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}

// Provider to manage connection lifecycle
final socketManagerProvider = Provider<SocketManager>((ref) {
  return SocketManager(ref);
});
