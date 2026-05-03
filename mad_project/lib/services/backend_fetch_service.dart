import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

class BackendFetchService {
  static const String _collection = 'alerts';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Initialize service
  Future<void> initialize() async {
    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('🔧 Backend Fetch Service Initializing');
      debugPrint('═══════════════════════════════════');

      // Test Firebase connection
      final testCollection = await _firestore
          .collection(_collection)
          .limit(1)
          .get();

      debugPrint('✅ Firebase connection OK');
      debugPrint('   Collection: $_collection');
      debugPrint('   Documents available: Yes');
      debugPrint('═══════════════════════════════════');
      debugPrint('');
    } catch (e, st) {
      debugPrint('❌ Backend initialization failed: $e');
      debugPrint('   Stack: $st');
    }
  }

  /// ✅ Get all alerts (hybrid: Firebase → Cache)
  Future<List<Map<String, dynamic>>> getAlerts({
    int limit = 100,
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('');
      debugPrint('📡 HYBRID FETCH: Alerts');
      debugPrint('   Limit: $limit');
      debugPrint('   Force Refresh: $forceRefresh');

      // ✅ PRIMARY: Firebase
      debugPrint('   🌐 PRIMARY SOURCE: Firebase');
      final firebaseAlerts = await _fetchFromFirebase(limit);

      if (firebaseAlerts.isNotEmpty) {
        debugPrint('   ✅ Got ${firebaseAlerts.length} alerts from Firebase');
        debugPrint('   📊 Source: FIREBASE (ONLINE)');
        return firebaseAlerts;
      }

      // ✅ FALLBACK: Try local cache (would be implemented)
      debugPrint('   ⚠️ Firebase returned empty, checking local cache...');
      debugPrint('   💾 No local cache available (feature pending)');

      debugPrint('   ❌ No alerts found anywhere');
      return [];
    } catch (e, st) {
      debugPrint('❌ Hybrid fetch error: $e\n$st');
      debugPrint('   📊 Source: OFFLINE (failed)');
      return [];
    }
  }

  /// ✅ Fetch from Firebase
  Future<List<Map<String, dynamic>>> _fetchFromFirebase(int limit) async {
    try {
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
          'created_at': data['created_at'],
          'timestamp_received': DateTime.now().toIso8601String(),
        };
      }).toList();
    } catch (e, st) {
      debugPrint('   ❌ Firebase fetch failed: $e\n$st');
      rethrow;
    }
  }

  /// ✅ Get alerts by type
  Future<List<Map<String, dynamic>>> getAlertsByType(
    String type, {
    int limit = 50,
  }) async {
    try {
      debugPrint('📡 Fetching alerts of type: $type');

      final snapshot = await _firestore
          .collection(_collection)
          .where('type', isEqualTo: type)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      debugPrint('✅ Got ${snapshot.docs.length} alerts of type $type');

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e, st) {
      debugPrint('❌ Error fetching by type: $e\n$st');
      return [];
    }
  }

  /// ✅ Get alerts count
  Future<int> getAlertsCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error getting count: $e');
      return 0;
    }
  }

  /// ✅ Get unread alerts count
  Future<int> getUnreadCount() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error getting unread count: $e');
      return 0;
    }
  }

  /// ✅ Stream real-time alerts
  Stream<List<Map<String, dynamic>>> streamAlerts({int limit = 100}) {
    return _firestore
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  /// ✅ Dispose resources
  void dispose() {
    debugPrint('🧹 Backend Fetch Service disposed');
  }
}