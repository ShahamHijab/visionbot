// lib/services/alert_notification_service.dart
// ✅ HANDLES NOTIFICATIONS FROM DETECTION APP IN REAL-TIME

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert_model.dart';

class AlertNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// ✅ Initialize notification system
  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('');
    debugPrint('═══════════════════════════════════');
    debugPrint('🔔 INITIALIZING NOTIFICATION SERVICE');
    debugPrint('═══════════════════════════════════');

    try {
      // ✅ Request notification permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
      );

      debugPrint('📋 Permission Status: ${settings.authorizationStatus}');

      // ✅ Setup local notifications
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(initSettings);

      // ✅ Subscribe to alert topics
      await _subscribeToTopics();

      // ✅ Handle foreground notifications
      FirebaseMessaging.onMessage.listen(_handleForegroundNotification);

      // ✅ Handle background tap
      _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _isInitialized = true;
      debugPrint('✅ Notification service ready');
      debugPrint('═══════════════════════════════════');
    } catch (e, st) {
      debugPrint('❌ Notification init error: $e');
      debugPrint('   Stack: $st');
    }
  }

  /// ✅ Subscribe to alert topics
  static Future<void> _subscribeToTopics() async {
    try {
      final topics = [
        'alerts_all',
        'alerts_critical',
        'alerts_fire',
        'alerts_unknown_face',
        'alerts_group',
      ];

      for (final topic in topics) {
        await _messaging.subscribeToTopic(topic);
      }

      debugPrint('✅ Subscribed to ${topics.length} topics');
    } catch (e) {
      debugPrint('❌ Subscribe to topics error: $e');
    }
  }

  /// ✅ Handle foreground notifications
  static Future<void> _handleForegroundNotification(
      RemoteMessage message) async {
    try {
      debugPrint('');
      debugPrint('📢 FOREGROUND NOTIFICATION');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');

      final data = message.data;
      final alertType = data['type'] ?? 'unknown';
      final alertId = data['alert_id'] ?? '';

      // ✅ Show local notification
      await _showLocalNotification(
        title: message.notification?.title ?? 'New Alert',
        body: message.notification?.body ?? 'New security alert detected',
        payload: alertId,
        alertType: alertType,
      );
    } catch (e) {
      debugPrint('❌ Handle notification error: $e');
    }
  }

  /// ✅ Show local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    required String alertType,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        'alert_channel',
        'Alert Notifications',
        channelDescription: 'Notifications from VisionBot detection app',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('alert_sound'),
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        sound: 'alert_sound.wav',
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        payload.hashCode,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Local notification shown');
    } catch (e) {
      debugPrint('❌ Show notification error: $e');
    }
  }

  /// ✅ Get FCM token
  static Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('📱 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      debugPrint('❌ Get FCM token error: $e');
      return null;
    }
  }

  void dispose() {
    debugPrint('✅ Notification service disposed');
  }
}