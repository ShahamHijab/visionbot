import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initAndSyncToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null) return;

    await _db.collection('users').doc(user.uid).set({
      'fcm_token': token,
      'fcm_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _messaging.onTokenRefresh.listen((newToken) async {
      await _db.collection('users').doc(user.uid).set({
        'fcm_token': newToken,
        'fcm_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> subscribeTopicsFromSettings({
    required bool enabled,
    required bool fire,
    required bool smoke,
    required bool motion,
  }) async {
    if (!enabled) {
      await _messaging.unsubscribeFromTopic('alerts_all');
      await _messaging.unsubscribeFromTopic('alerts_fire');
      await _messaging.unsubscribeFromTopic('alerts_smoke');
      await _messaging.unsubscribeFromTopic('alerts_motion');
      return;
    }

    await _messaging.subscribeToTopic('alerts_all');

    if (fire) {
      await _messaging.subscribeToTopic('alerts_fire');
    } else {
      await _messaging.unsubscribeFromTopic('alerts_fire');
    }

    if (smoke) {
      await _messaging.subscribeToTopic('alerts_smoke');
    } else {
      await _messaging.unsubscribeFromTopic('alerts_smoke');
    }

    if (motion) {
      await _messaging.subscribeToTopic('alerts_motion');
    } else {
      await _messaging.unsubscribeFromTopic('alerts_motion');
    }
  }
}
