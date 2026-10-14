import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/core/config.dart';

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
        debugPrint('🖱️ Local Notification Clicked: ${details.payload}');
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📩 Customer App: Foreground Message Received: ${message.notification?.title}',
      );
      _showLocalNotification(message);
    });

    // Handle background notification clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🖱️ Customer App: Notification Clicked: ${message.data}');
    });
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
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      if (!_listening) {
        _listening = true;
        messaging.onTokenRefresh.listen(_registerCurrentUser);
      }

      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        debugPrint('Customer FCM: no APNs token yet; will register on refresh');
        return;
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
    const androidDetails = AndroidNotificationDetails(
      'customer_high_importance_channel',
      'Customer High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(
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
        body: json.encode({'fcmToken': fcmToken}),
      );
      debugPrint('✅ Customer FCM Token registered');
    } catch (e) {
      debugPrint('❌ Customer FCM Token registration error: $e');
    }
  }
}
