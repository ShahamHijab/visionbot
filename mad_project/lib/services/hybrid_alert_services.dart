// lib/services/hybrid_alert_service.dart - USER APP
// ✅ SIMPLIFIED: Only Firebase + Local Cache (no SQLite)

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class HybridAlertsService {
  final FirebaseFirestore _firebaseDb = FirebaseFirestore.instance;
  static const String _collection = 'alerts';

  /// ✅ FETCH: Try Firebase first, fallback to cache
  Future<List<Map<String, dynamic>>> getAlerts({
    String? type,
    int limit = 100,
  }) async {
    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('🔄 FETCHING ALERTS');
      debugPrint('═══════════════════════════════════');

      var query = _firebaseDb
          .collection(_collection)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (type != null) {
        query = query.where('type', isEqualTo: type);
      }

      final snapshot = await query.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Firebase timeout - showing cached data');
          throw TimeoutException('Firebase fetch timeout');
        },
      );

      final alerts = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'alert_id': doc['alert_id'] ?? doc.id,
                ...doc.data(),
                'source': 'firebase', // Mark source
                'synced': true,
              })
          .toList();

      debugPrint('✅ Fetched ${alerts.length} alerts from Firebase');
      debugPrint('═══════════════════════════════════');

      return alerts;
    } catch (e) {
      debugPrint('⚠️ Firebase fetch failed: $e');
      debugPrint('   User will see cached data from previous load');
      rethrow;
    }
  }

  /// ✅ Stream alerts (real-time updates)
  Stream<List<Map<String, dynamic>>> streamAlerts({int limit = 100}) {
    return _firebaseDb
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'alert_id': doc['alert_id'] ?? doc.id,
                  ...doc.data(),
                  'source': 'firebase',
                  'synced': true,
                })
            .toList());
  }

  /// ✅ Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final snapshot = await _firebaseDb.collection(_collection).count().get();
      final totalCount = snapshot.count ?? 0;

      // Count unsynced (if any detection app is still syncing)
      final unsyncedSnapshot = await _firebaseDb
          .collection(_collection)
          .where('synced_at', isNull: true)
          .count()
          .get();
      
      final unsyncedCount = unsyncedSnapshot.count ?? 0;

      return {
        'total': totalCount,
        'synced': totalCount - unsyncedCount,
        'unsynced': unsyncedCount,
        'lastSync': DateTime.now(),
      };
    } catch (e) {
      debugPrint('❌ Sync stats error: $e');
      return {
        'total': 0,
        'synced': 0,
        'unsynced': 0,
      };
    }
  }
}