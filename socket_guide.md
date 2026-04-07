# Real-time Socket System Guide for Flutter

This guide explains how the backend socket system works and how to implement the client-side listener in your Flutter application.

## 1. Backend Architecture

The backend uses `socket.io` to handle real-time communications.

### Connection & Authentication
*   **Protocol:** Socket.IO (v4)
*   **Endpoint:** `http://localhost:5000` (or your deployed URL)
*   **Authentication:** The server middleware (`socketAuth.js`) expects a JWT token in the handshake auth object.
    ```javascript
    // Handshake structure
    {
      auth: {
        token: "your_jwt_access_token"
      }
    }
    ```
*   **Identification:** Once connected, the server identifies the user from the token (`userId`, `role`) and automatically joins them to specific "rooms".

### Rooms & Channels
The server manages "rooms" to broadcast messages to specific groups. You don't need to manually join most of these; the server handles it on connection.

1.  **User Room:** `user:<your_user_id>`
    *   *Purpose:* Private messages for you (e.g., your order was created, your profile was updated).
    *   *Auto-joined:* Yes, upon connection.
2.  **Role Room:** `role:customer`
    *   *Purpose:* Broadcasts to all customers (rarely used, but available).
    *   *Auto-joined:* Yes, upon connection.
3.  **Order Room:** `order:<order_id>`
    *   *Purpose:* Updates specific to an active order (e.g., rider location, status changes).
    *   *Auto-joined:* **No.** You must explicitly emit `order:join` with the `orderId` to track a specific live order.

### Key Events to Listen For

| Event Name | Payload | Description |
| :--- | :--- | :--- |
| `order:created` | `{ orderId, orderNumber, total }` | Confirms your order was placed. |
| `order:status-updated` | `{ orderId, status }` | Status changes (e.g., 'preparing', 'out_for_delivery'). |
| `delivery:status-updated` | `{ deliveryId, status }` | Rider specific updates (e.g., 'picked_up'). |
| `rider:location-update` | `{ riderId, orderId, location: { lat, lng } }` | Live GPS coordinates of the rider. |

---

## 2. Flutter Implementation

To connect your Flutter app to this system, use the `socket_io_client` package.

### Step 1: Add Dependency
Add this to your `pubspec.yaml`:
```yaml
dependencies:
  socket_io_client: ^2.0.0
```

### Step 2: Create a Socket Service
Create a file `lib/services/socket_service.dart`.

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  final String baseUrl = 'http://10.0.2.2:5000'; // Android Emulator localhost
  // Use 'http://localhost:5000' for iOS Simulator or actual IP for device

  // Initialize and Connect
  void connect(String token) {
    socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // Use websocket transport
      .disableAutoConnect() // Disable auto-connect to set auth first
      .setAuth({'token': token}) // Send JWT token here
      .build()
    );

    socket.connect();

    // Standard Events
    socket.onConnect((_) {
      print('✅ Connected to Socket Server');
    });

    socket.onDisconnect((_) => print('❌ Disconnected'));
    socket.onConnectError((err) => print('⚠️ Connection Error: $err'));
    
    // Listen for Global User Events
    _setupGlobalListeners();
  }

  void _setupGlobalListeners() {
    // 1. Order Created
    socket.on('order:created', (data) {
      print('🎉 Order Created: ${data['orderNumber']}');
      // Trigger local notification or UI update
    });

    // 2. Order Status Update
    socket.on('order:status-updated', (data) {
      print('🔄 Status Update: Order #${data['orderId']} is ${data['status']}');
      // Update order list or details page
    });
  }

  // Call this when entering the "Order Details" or "Track Order" screen
  void joinOrderRoom(String orderId) {
    print('Checking into Order Room: $orderId');
    socket.emit('order:join', orderId);

    // Listen for Rider Location (only relevant in this room)
    socket.on('rider:location-update', (data) {
      final loc = data['location'];
      print('📍 Rider Location: Lat ${loc['lat']}, Lng ${loc['lng']}');
      // Update map marker
    });
  }

  // Call this when leaving the screen
  void leaveOrderRoom(String orderId) {
    socket.emit('order:leave', orderId);
    socket.off('rider:location-update'); // Stop listening to this specific event
  }

  void disconnect() {
    socket.disconnect();
  }
}
```

### Step 3: Usage in Your App

1.  **Connect on Login:**
    When the user successfully logs in and you get the `token`, call `SocketService().connect(token)`.

2.  **Global Updates:**
    Since the service listens for `order:status-updated` globally, you can use a `StreamController` or `ChangeNotifier` inside the service to notify your UI (like an Order List page) whenever a status changes, without needing to refresh the API.

3.  **Live Tracking:**
    When the user navigates to the "Track Order" screen:
    ```dart
    @override
    void initState() {
      super.initState();
      socketService.joinOrderRoom(widget.orderId);
    }

    @override
    void dispose() {
      socketService.leaveOrderRoom(widget.orderId);
      super.dispose();
    }
    ```

### Important Notes
*   **Android Emulator:** Use `http://10.0.2.2:5000` to reach localhost.
*   **Real Device:** Use your PC's local IP address (e.g., `http://192.168.1.5:5000`).
*   **Token Expiry:** If the token expires, the socket will disconnect. You should handle the `onDisconnect` event to attempt a token refresh and reconnect.
