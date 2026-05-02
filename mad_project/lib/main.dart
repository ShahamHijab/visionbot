// 📱 USER APP: Main initialization
// ✅ Firebase PRIMARY + Laptop Backup + Local Cache FALLBACK

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'services/push_service.dart';
import 'services/alert_sync_service.dart';
import 'services/alert_notification_service.dart';
import 'services/database_service.dart';
import 'services/backend_fetch_service.dart'; // ✅ NEW: Laptop backup

// ✅ Global services
AlertSyncService? _syncService;
DatabaseService? _dbService;
BackendFetchService? _backendFetch; // ✅ NEW

final FlutterLocalNotificationsPlugin _local =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _alertsChannel = AndroidNotificationChannel(
  'alerts_channel',
  'Alerts',
  description: 'VisionBot alert notifications',
  importance: Importance.high,
);

/// ✅ Initialize local database
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

    debugPrint('✅ Local database ready');
    debugPrint('═══════════════════════════════════');
    debugPrint('');
  } catch (e, st) {
    debugPrint('❌ Database init failed: $e');
    debugPrint('   Stack: $st');
  }
}

/// ✅ Initialize local notifications
Future<void> _initLocalNotifications() async {
  if (kIsWeb) return;

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
  debugPrint('║  📱 VisionBot USER APP            ║');
  debugPrint('║  HYBRID: Firebase + Laptop + Cache║');
  debugPrint('╚═══════════════════════════════════╝');

  try {
    // ✅ Step 1: Initialize Firebase
    debugPrint('');
    debugPrint('1️⃣ Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('   ✅ Firebase ready (PRIMARY)');

    // ✅ Step 2: Initialize local database
    debugPrint('2️⃣ Initializing Local Database...');
    await _initializeLocalDatabase();
    debugPrint('   ✅ Local DB ready (CACHE)');

    // ✅ Step 3: Initialize backend fetch (BACKUP)
    debugPrint('3️⃣ Starting Laptop Backup...');
    _backendFetch = BackendFetchService();
    await _backendFetch!.initialize();
    debugPrint('   ✅ Laptop backup ready');

    // ✅ Step 4: Initialize Alert Services
    debugPrint('4️⃣ Setting up Alert Services...');
    await AlertNotificationService.initialize();
    debugPrint('   ✅ Alert notifications ready');

    // ✅ Step 5: Initialize real-time sync
    debugPrint('5️⃣ Starting Real-time Sync...');
    _syncService = AlertSyncService();
    await _syncService!.initializeRealtimeSync();
    debugPrint('   ✅ Real-time sync listening');

    debugPrint('');
    debugPrint('✅ USER APP READY');
    debugPrint('   🌐 Firebase (Primary)');
    debugPrint('   📡 Laptop Backup (if offline)');
    debugPrint('   💾 Local Cache (fallback)');
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