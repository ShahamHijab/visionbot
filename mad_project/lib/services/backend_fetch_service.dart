// user app -- backend fetch service

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendFetchService {
  static const String _collection = 'alerts';

  // CHANGE THIS TO YOUR LAPTOP SERVER IP
  // Example: http://192.168.1.12:3000
static final String laptopServerUrl =  dotenv.env['LAPTOP_SERVER_URL'] ?? '';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('🔧 Backend Fetch Service Initializing');
      debugPrint('═══════════════════════════════════');

      await _testLaptopServer();

      final testCollection =
          await _firestore.collection(_collection).limit(1).get();

      debugPrint('✅ Firebase connection OK');
      debugPrint('   Collection: $_collection');
      debugPrint('   Docs found: ${testCollection.docs.length}');
      debugPrint('═══════════════════════════════════');
      debugPrint('');
    } catch (e, st) {
      debugPrint('❌ Backend initialization warning: $e');
      debugPrint('   Stack: $st');
    }
  }

  Future<void> _testLaptopServer() async {
    try {
      final response = await http
          .get(Uri.parse('$laptopServerUrl/health'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        debugPrint('✅ Laptop server connection OK');
      } else {
        debugPrint('⚠️ Laptop server responded: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ Laptop server not reachable: $e');
    }
  }

  /// Hybrid order:
  /// 1. Firebase
  /// 2. Laptop server
  /// 3. Empty list
  Future<List<Map<String, dynamic>>> getAlerts({
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    debugPrint('');
    debugPrint('📡 HYBRID FETCH: Alerts');
    debugPrint('   Limit: $limit');
    debugPrint('   Force Refresh: $forceRefresh');

    try {
      debugPrint('   🌐 PRIMARY SOURCE: Firebase');
      final firebaseAlerts = await _fetchFromFirebase(limit);

      if (firebaseAlerts.isNotEmpty) {
        debugPrint('   ✅ Got ${firebaseAlerts.length} alerts from Firebase');
        return firebaseAlerts;
      }

      debugPrint('   ⚠️ Firebase empty, trying laptop server...');
    } catch (e, st) {
      debugPrint('   ❌ Firebase fetch failed: $e');
      debugPrint('   Stack: $st');
      debugPrint('   📡 Trying laptop server...');
    }

    try {
      final serverAlerts = await _fetchFromLaptopServer(limit);

      if (serverAlerts.isNotEmpty) {
        debugPrint('   ✅ Got ${serverAlerts.length} alerts from laptop server');
        return serverAlerts;
      }

      debugPrint('   ⚠️ Laptop server returned empty');
    } catch (e, st) {
      debugPrint('   ❌ Laptop server fetch failed: $e');
      debugPrint('   Stack: $st');
    }

    debugPrint('   ❌ No alerts found');
    return [];
  }

  Future<List<Map<String, dynamic>>> _fetchFromFirebase(int limit) async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    debugPrint('   📍 Firebase returned ${snapshot.docs.length} documents');

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        ...data,
        'id': doc.id,
        'source': 'firebase',
        'created_at': data['created_at'],
        'timestamp_received': DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchFromLaptopServer(int limit) async {
    final response = await http
        .get(Uri.parse('$laptopServerUrl/api/phone/alerts'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Laptop server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    final List alerts = decoded['alerts'] ?? [];

    final mappedAlerts = alerts.map<Map<String, dynamic>>((item) {
      final alert = Map<String, dynamic>.from(item);

      return {
        ...alert,
        'id': alert['alert_id']?.toString() ??
            alert['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'source': 'laptop_server',
        'created_at_local': alert['created_at_local'],
        'timestamp': alert['created_at_local'],
        'timestamp_received': DateTime.now().toIso8601String(),
        'isRead': alert['isRead'] ?? false,
        'isResolved': alert['isResolved'] ?? false,
      };
    }).toList();

    mappedAlerts.sort((a, b) {
      final ad = a['created_at_local']?.toString() ?? '';
      final bd = b['created_at_local']?.toString() ?? '';
      return bd.compareTo(ad);
    });

    return mappedAlerts.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getAlertsByType(
    String type, {
    int limit = 50,
  }) async {
    final allAlerts = await getAlerts(limit: limit);

    return allAlerts.where((alert) {
      return alert['type']?.toString() == type;
    }).toList();
  }

  Future<int> getAlertsCount() async {
    try {
      final snapshot = await _firestore.collection(_collection).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Firebase count failed, trying laptop server: $e');

      try {
        final alerts = await _fetchFromLaptopServer(1000);
        return alerts.length;
      } catch (_) {
        return 0;
      }
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Firebase unread count failed, trying laptop server: $e');

      try {
        final alerts = await _fetchFromLaptopServer(1000);
        return alerts.where((a) => a['isRead'] != true).length;
      } catch (_) {
        return 0;
      }
    }
  }

  Stream<List<Map<String, dynamic>>> streamAlerts({int limit = 100}) async* {
    try {
      yield* _firestore
          .collection(_collection)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();

          return {
            ...data,
            'id': doc.id,
            'source': 'firebase',
            'timestamp_received': DateTime.now().toIso8601String(),
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('⚠️ Firebase stream failed, using laptop polling: $e');

      yield* Stream.periodic(const Duration(seconds: 5))
          .asyncMap((_) => _fetchFromLaptopServer(limit));
    }
  }

  void dispose() {
    debugPrint('🧹 Backend Fetch Service disposed');
  }
}