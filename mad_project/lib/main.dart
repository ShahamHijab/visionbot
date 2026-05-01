// ✅ FIXED USER APP main.dart - Hybrid Alert System

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'services/push_service.dart';
import 'services/alert_sync_service.dart';
import 'services/alert_notification_service.dart';
import 'services/database_service.dart';
import 'services/hybrid_alert_services.dart';

// ✅ GLOBAL SERVICES
AlertSyncService? _syncService;
DatabaseService? _dbService;
HybridAlertsService? _hybridService;

final FlutterLocalNotificationsPlugin _local =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'alerts_channel',
  'Alerts',
  description: 'VisionBot alert notifications',
  importance: Importance.high,
);

/// ✅ Initialize local database and check for unsynced alerts
Future<void> _initializeLocalDatabase() async {
  try {
    debugPrint('');
    debugPrint('═══════════════════════════════════');
    debugPrint('🗄️  INITIALIZING LOCAL DATABASE');
    debugPrint('═══════════════════════════════════');

    _dbService = DatabaseService();
    final db = await _dbService!.database;

    // ✅ Print statistics
    await _dbService!.printStats();

    // ✅ Check for unsynced alerts and try to sync them
    final unsynced = await _dbService!.getUnsyncedAlerts();
    if (unsynced.isNotEmpty) {
      debugPrint('');
      debugPrint('⏳ Found ${unsynced.length} unsynced alerts from offline mode');
      debugPrint('🔄 Will attempt to sync when Firebase is available...');
      
      // ✅ Start background sync
      _startUnSyncedAlertSync();
    }

    debugPrint('✅ Local database ready');
    debugPrint('═══════════════════════════════════');
    debugPrint('');
  } catch (e, st) {
    debugPrint('❌ Database init failed: $e');
    debugPrint('   Stack: $st');
  }
}

/// ✅ HYBRID: Sync unsynced local alerts to Firebase
Future<void> _startUnSyncedAlertSync() async {
  if (_syncService == null) return;

  try {
    final unsynced = await _dbService!.getUnsyncedAlerts();
    if (unsynced.isEmpty) return;

    debugPrint('');
    debugPrint('═══════════════════════════════════');
    debugPrint('🔄 SYNCING OFFLINE ALERTS TO FIREBASE');
    debugPrint('═══════════════════════════════════');

    int synced = 0;
    for (final alert in unsynced) {
      try {
        // ✅ Try to upload alert to Firebase
        final alertId = alert['alert_id'] as String;
        await _syncService!.uploadAlertToFirebase(alert);
        
        // ✅ Mark as synced in local database
        await _dbService!.markSynced(alertId);
        synced++;

        debugPrint('✅ Synced: $alertId');
      } catch (e) {
        debugPrint('⚠️ Failed to sync alert: $e');
      }
    }

    debugPrint('');
    debugPrint('✅ Sync complete: $synced/${unsynced.length} alerts synced');
    debugPrint('═══════════════════════════════════');
    debugPrint('');
  } catch (e) {
    debugPrint('❌ Unsynced alert sync failed: $e');
  }
}

/// ✅ Initialize local notifications
Future<void> _initLocalNotifications() async {
  if (kIsWeb) return; // Skip on web

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await _local.initialize(initSettings);

  final androidPlugin = _local
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(_alertsChannel);
  }

  debugPrint('✅ Local notifications initialized');
}

/// ✅ Show local notification from FCM message
Future<void> _showLocalFromRemote(RemoteMessage message) async {
  if (kIsWeb) return;

  final title = message.notification?.title ?? 'Alert';
  final body = message.notification?.body ?? '';

  if (title.isEmpty && body.isEmpty) return;

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'alerts_channel',
      'Alerts',
      channelDescription: 'VisionBot alert notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  await _local.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    details,
  );
}

/// ✅ Firebase background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('🔔 FCM Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('');
  debugPrint('╔═══════════════════════════════════╗');
  debugPrint('║  VisionBot USER APP - Initializing  ║');
  debugPrint('║      HYBRID MODE 🚀              ║');
  debugPrint('╚═══════════════════════════════════╝');

  try {
    // ✅ Step 1: Initialize Firebase
    debugPrint('');
    debugPrint('1️⃣ Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('   ✅ Firebase ready');

    // ✅ Step 2: Initialize local database (for offline support)
    debugPrint('');
    debugPrint('2️⃣ Initializing Local Database...');
    await _initializeLocalDatabase();

    // ✅ Step 3: Initialize Alert Services
    debugPrint('');
    debugPrint('3️⃣ Setting up Alert Services...');
    await AlertNotificationService.initialize();
    debugPrint('   ✅ Alert notifications ready');

    // ✅ Step 4: Initialize HYBRID alerts service
    debugPrint('');
    debugPrint('4️⃣ Starting HYBRID Alerts Service...');
    _hybridService = HybridAlertsService();
    final stats = await _hybridService!.getStatistics();
    debugPrint('   Firebase alerts: ${stats['firebase']}');
    debugPrint('   Local alerts: ${stats['local']}');
    debugPrint('   Unsynced: ${stats['unsynced']}');

    // ✅ Step 5: Initialize real-time sync
    debugPrint('');
    debugPrint('5️⃣ Starting Real-time Sync...');
    _syncService = AlertSyncService();
    await _syncService!.initializeRealtimeSync();
    debugPrint('   ✅ Real-time sync listening');

    // ✅ Step 6: Try to sync any offline alerts
    debugPrint('');
    debugPrint('6️⃣ Checking for offline alerts...');
    Future.delayed(
      const Duration(seconds: 2),
      _startUnSyncedAlertSync,
    );

    debugPrint('');
    debugPrint('✅ USER APP READY');
    debugPrint('   📱 Listening to Detection App');
    debugPrint('   💾 Local backup active');
    debugPrint('   🔄 Real-time sync enabled');
    debugPrint('═══════════════════════════════════');
    debugPrint('');
  } catch (e, st) {
    debugPrint('');
    debugPrint('❌ Initialization FAILED: $e');
    debugPrint('   Stack: $st');
    debugPrint('');
  }

  // ✅ Only initialize messaging on mobile
  if (!kIsWeb) {
    try {
      await _initLocalNotifications();

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      final fcm = FirebaseMessaging.instance;
      final token = await fcm.getToken();
      debugPrint('');
      debugPrint('🔐 FCM Token: ${token?.substring(0, 20)}...');
      debugPrint('');

      // ✅ Handle foreground messages
      FirebaseMessaging.onMessage.listen((message) async {
        debugPrint('🔔 FCM FOREGROUND: ${message.notification?.title}');
        await _showLocalFromRemote(message);
      });

      // ✅ Handle message tap
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('📱 Notification tapped: ${message.messageId}');
      });

      await PushService().init();
    } catch (e) {
      debugPrint('⚠️ FCM setup failed: $e');
    }
  }

  runApp(const VisionBotApp());
}

class VisionBotApp extends StatelessWidget {
  const VisionBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Bot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}