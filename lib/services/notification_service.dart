import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/core/config.dart';
import 'package:tnt_lh/core/navigation.dart';
import 'package:tnt_lh/screens/order_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tnt_lh/models/product_model.dart';
import 'package:tnt_lh/providers/brand_provider.dart';
import 'package:tnt_lh/screens/bag_screen.dart';
import 'package:tnt_lh/screens/cafe/cafe_item_details_screen.dart';
import 'package:tnt_lh/services/api_client.dart';

const _channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Order updates',
  description: 'Your order being accepted, picked up and delivered',
  importance: Importance.max,
);

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _listening = false;

  /// Wires up notification handling. Runs before the first frame, so it must
  /// not prompt and must not wait on the network: the permission prompt used to
  /// be shown from here, which on iOS left a blank screen behind a system
  /// dialog on the very first launch. Asking is [enableForSignedInUser]'s job.
  static Future<void> initialize() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    // Left to their defaults these would raise the iOS permission prompt here.
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        _openFromPayload(details.payload);
      },
    );

    // The server sends every push to this channel. It was never created, so
    // Android filed them under a default channel: no pop-up, often no sound.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // With the app open the push still shows as a banner: there is no
    // in-app pop-up any more (the screens just update), so without it a
    // customer looking at another screen would miss "Order accepted".
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    // Tapping a notification used to just open the app wherever it was. An
    // order notification now opens that order.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _openFromData(message.data);
    });
  }

  static void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = json.decode(payload);
      if (data is Map) _openFromData(data);
    } catch (_) {}
  }

  /// Opens what a tapped push is about: the order, the bag, an item, or the
  /// store's menu (bag reminders, offers, "it's been a while").
  static Future<void> _openFromData(Map<dynamic, dynamic> data) async {
    final id = data['notificationId']?.toString();
    if (id != null && id.isNotEmpty) _reportOpened(id);

    // Signed out since the notification was sent: nothing to show them.
    if (!await AuthService.hasSession()) return;
    final nav = rootNavigatorKey.currentState;
    final context = rootNavigatorKey.currentContext;
    if (nav == null || context == null || !context.mounted) return;

    final orderId = data['orderId']?.toString() ?? '';
    final type = data['type']?.toString() ?? (orderId.isNotEmpty ? 'order' : 'menu');
    final brand = data['brand']?.toString() ?? '';

    if (type == 'order') {
      if (orderId.isEmpty) return;
      nav.push(
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
      );
      return;
    }

    // Everything else is about a store: show that one.
    if (brand.isNotEmpty) {
      await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(brandProvider.notifier).setBrand(brand);
    }
    nav.popUntil((route) => route.isFirst);

    switch (type) {
      case 'cart':
        nav.push(
          MaterialPageRoute(
            builder: (_) => BagScreen(store: brand.isEmpty ? null : brand),
          ),
        );
      case 'product':
        final product = await _product(data['id']?.toString(), brand);
        if (product != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(product: product),
            ),
          );
        }
      default:
        // 'menu' and 'offer': the store's menu, which is where we now are.
        break;
    }
  }

  static Future<Product?> _product(String? id, String brand) async {
    if (id == null || id.isEmpty) return null;
    try {
      final res = await ApiClient.get(
        AppConfig.buildUrl(
          '/customer/products/$id',
          brand: brand.isEmpty ? null : brand,
        ),
      );
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body);
      final p = body is Map ? (body['data'] ?? body) : null;
      return p is Map<String, dynamic> ? Product.fromJson(p) : null;
    } catch (_) {
      return null;
    }
  }

  /// Tells the server a push was tapped (opens, and orders that follow, are
  /// counted in the admin panel). Best effort.
  static void _reportOpened(String id) {
    ApiClient.post(
      AppConfig.buildUrl('/customer/notifications/$id/opened'),
    ).catchError((_) => http.Response('', 0));
  }

  static bool _launchTapHandled = false;

  /// The app was started by tapping a notification. Handled from the signed-in
  /// home screen, once there is somewhere to navigate from.
  static Future<void> _openLaunchNotification() async {
    if (_launchTapHandled) return;
    _launchTapHandled = true;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        await _openFromData(initial.data);
        return;
      }
      final local = await _localNotifications.getNotificationAppLaunchDetails();
      if (local?.didNotificationLaunchApp == true) {
        _openFromPayload(local!.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('Opening launch notification failed: $e');
    }
  }

  /// Asks for notification permission and registers this device for pushes.
  /// Called once the customer is signed in and looking at the home screen, so
  /// the prompt appears in context. Registration used to happen only at app
  /// start for an already-signed-in user, so someone who had just logged in got
  /// no order pushes until they next cold-started the app.
  ///
  /// Never throws: on iOS the FCM token isn't available until APNs has issued
  /// its own (never, on a simulator), and that must not break the app.
  static Future<void> enableForSignedInUser() async {
    // Store screenshots (integration_test/screenshots_test.dart) are taken
    // with this set, so the system prompt isn't over every one of them.
    if (const bool.fromEnvironment('SCREENSHOT_MODE')) return;
    _openLaunchNotification();
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen(_registerCurrentUser);
      }

      // On iOS the FCM token needs Apple's push token first, which can take
      // a few seconds after the permission prompt. Giving up at once meant
      // a phone could go a whole session without order pushes.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        for (var i = 0; i < 6 && await messaging.getAPNSToken() == null; i++) {
          await Future<void>.delayed(const Duration(seconds: 3));
        }
        if (await messaging.getAPNSToken() == null) {
          debugPrint('Customer FCM: no APNs token; will register on refresh');
          return;
        }
      }

      final fcmToken = await messaging.getToken();
      if (fcmToken != null) await _registerCurrentUser(fcmToken);
    } catch (e) {
      debugPrint('❌ Customer FCM setup error: $e');
    }
  }

  static Future<void> _registerCurrentUser(String fcmToken) async {
    final token = await AuthService.getToken();
    if (token != null) await _registerTokenWithBackend(token, fcmToken);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: notificationDetails,
      payload: json.encode(message.data),
    );
  }

  static Future<void> _registerTokenWithBackend(
    String authToken,
    String fcmToken,
  ) async {
    final url = AppConfig.buildUrl('/customer/profile/fcm-token');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        // With the platform: an account can be signed in on several phones.
        body: json.encode({
          'fcmToken': fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );
      debugPrint('✅ Customer FCM Token registered');
    } catch (e) {
      debugPrint('❌ Customer FCM Token registration error: $e');
    }
  }
}
