import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // Don't initialize push notifications on web
    if (kIsWeb) {
      debugPrint('Push notifications disabled on web');
      return;
    }

    await _messaging.setAutoInitEnabled(true);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notification permission denied');
      return;
    }

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    await _messaging.subscribeToTopic('alerts_all');
    debugPrint('SUBSCRIBED alerts_all');

    await _messaging.unsubscribeFromTopic('alerts_all');
    await _messaging.subscribeToTopic('alerts_all');
    debugPrint('REFRESHED SUBSCRIPTION alerts_all');

    final token = await _messaging.getToken();
    debugPrint('FCM TOKEN: $token');
  }
}