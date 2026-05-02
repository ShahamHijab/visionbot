// 📱 PHONE: Fetch alerts from laptop server

import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'connectivity_helper.dart';

class BackendFetchService {
  // ⚠️ CHANGE THIS TO YOUR LAPTOP IP!
  // Example: http://192.168.1.50:3000
  // Find it from laptop server output
  static const String BACKEND_URL = 'http://192.168.1.50:3000';

  final DatabaseService _localDb = DatabaseService();
  final ConnectivityHelper _connectivity = ConnectivityHelper();

  Timer? _autoFetchTimer;
  bool _isFetching = false;

  /// ✅ Initialize service
  Future<void> initialize() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════');
    debugPrint('📱 Initializing Backend Fetch');
    debugPrint('═══════════════════════════════════');
    debugPrint('🖥️  Server: $BACKEND_URL');
    debugPrint('📍 Make sure laptop server is running!');

    // Initialize connectivity
    await _connectivity.initialize();

    // Start auto-fetch
    _startAutoFetch();

    debugPrint('✅ Backend Fetch Ready');
    debugPrint('═══════════════════════════════════');
    debugPrint('');
  }

  /// ✅ Get alerts (primary method)
  Future<List<Map<String, dynamic>>> getAlerts() async {
    if (_isFetching) return [];

    _isFetching = true;

    try {
      debugPrint('');
      debugPrint('🔄 Fetching alerts from server...');

      // ✅ Fetch from server
      final response = await http.get(
        Uri.parse('$BACKEND_URL/api/phone/alerts'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Server not responding');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final alerts = (data['alerts'] as List)
              .cast<Map<String, dynamic>>();

          debugPrint('✅ Got ${alerts.length} from server');

          // ✅ Cache each alert locally
          for (final alert in alerts) {
            try {
              await _localDb.cacheAlertLocally(alert);
            } catch (e) {
              debugPrint('   ⚠️ Cache error: $e');
            }
          }

          debugPrint('✅ Cached locally');
          _isFetching = false;
          return alerts;
        }
      }

      debugPrint('⚠️ Invalid response: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
    }

    _isFetching = false;

    // ✅ Fallback: Show cached data
    try {
      debugPrint('');
      debugPrint('💾 Showing cached alerts...');
      final cached = await _localDb.getCachedAlerts();
      debugPrint('✅ Got ${cached.length} from cache');
      return cached;
    } catch (e) {
      debugPrint('❌ Cache error: $e');
      return [];
    }
  }

  /// ✅ Auto-fetch every 10 seconds
  void _startAutoFetch() {
    _autoFetchTimer = Timer.periodic(Duration(seconds: 10), (_) async {
      if (_connectivity.isOnline && !_isFetching) {
        await getAlerts();
      }
    });

    debugPrint('📡 Auto-fetch started (every 10s)');
  }

  /// ✅ Manual fetch
  Future<List<Map<String, dynamic>>> fetchNow() async {
    return await getAlerts();
  }

  /// ✅ Cleanup
  void dispose() {
    _autoFetchTimer?.cancel();
    debugPrint('✅ Backend Fetch disposed');
  }
}