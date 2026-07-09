import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tnt_lh/services/auth_service.dart';
import 'package:tnt_lh/core/config.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings();
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

    // Request FCM permissions
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

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

    // Register token if user is already logged in
    final token = await AuthService.getToken();
    if (token != null) {
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        _registerTokenWithBackend(token, fcmToken);
      }
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'customer_high_importance_channel',
      'Customer High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

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
