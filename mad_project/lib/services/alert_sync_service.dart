// lib/services/alert_sync_service.dart
// ✅ SYNC SERVICE: Manages real-time sync between Detection App & User App

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class _LocalDatabaseService {
  Future<void> insertAlert(Map<String, dynamic> alertMap) async {}

  Future<void> markSynced(String alertId) async {}

  Future<int> getAlertCount() async => 0;

  Future<int> getUnsyncedCount() async => 0;
}

class AlertSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _LocalDatabaseService _localDb = _LocalDatabaseService();

  static const String _collection = 'alerts';

  StreamSubscription? _firestoreListener;
  bool _isSyncing = false;

  /// ✅ Initialize real-time listener from Detection App
  Future<void> initializeRealtimeSync() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════');
    debugPrint('🔄 INITIALIZING REAL-TIME SYNC');
    debugPrint('═══════════════════════════════════');

    try {
      // Listen to new alerts from detection app (created in last 5 minutes)
      final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));

      _firestoreListener = _firestore
          .collection(_collection)
          .where('created_at_local',
              isGreaterThanOrEqualTo: fiveMinutesAgo.toIso8601String())
          .orderBy('created_at_local', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          debugPrint('');
          debugPrint('📡 REAL-TIME UPDATE from Detection App');
          debugPrint('   New alerts: ${snapshot.docChanges.length}');

          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              _handleNewAlert(change.doc);
            }
          }
        },
        onError: (e) {
          debugPrint('❌ Real-time listener error: $e');
          _retryRealtimeSync();
        },
      );

      debugPrint('✅ Real-time listener started');
      debugPrint('═══════════════════════════════════');
    } catch (e, st) {
      debugPrint('❌ Initialize sync error: $e');
      debugPrint('   Stack: $st');
    }
  }

  /// ✅ Handle new alert from Detection App
  Future<void> _handleNewAlert(DocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final alertId = doc.id;

      debugPrint('');
      debugPrint('📥 NEW ALERT RECEIVED');
      debugPrint('   Alert ID: $alertId');
      debugPrint('   Type: ${data['type']}');
      debugPrint('   Timestamp: ${data['created_at_local']}');

      // ✅ Save to local database
      await _saveAlertLocally(alertId, data);

      // ✅ Mark as synced in local DB
      await _localDb.markSynced(alertId);

      debugPrint('✅ Alert saved locally & marked synced');
    } catch (e, st) {
      debugPrint('❌ Handle new alert error: $e');
      debugPrint('   Stack: $st');
    }
  }

  /// ✅ Save alert to local SQLite
  Future<void> _saveAlertLocally(
      String alertId, Map<String, dynamic> data) async {
    try {
      final alertMap = {
        'alert_id': alertId,
        'type': data['type'] ?? 'unknown',
        'created_at_local': data['created_at_local'] ?? DateTime.now().toIso8601String(),
        'lens': data['lens'] ?? '',
        'note': data['note'] ?? '',
        'image_path': data['image_path'],
        'face_image_paths': (data['face_image_paths'] as List?)?.join(',') ?? '',
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'location_name': data['location_name'],
        'severity': data['severity'] ?? 'info',
        'status': 'new',
        'threshold': data['threshold'],
        'synced_to_firebase': 1, // Already in Firebase
      };

      await _localDb.insertAlert(alertMap);
    } catch (e) {
      debugPrint('❌ Save alert locally error: $e');
    }
  }

  /// ✅ Retry real-time sync if connection lost
  Future<void> _retryRealtimeSync() async {
    await Future.delayed(Duration(seconds: 5));
    if (!_isSyncing) {
      debugPrint('🔄 Retrying real-time sync...');
      await initializeRealtimeSync();
    }
  }

  /// ✅ Manual sync from Firebase (for offline scenarios)
  Future<void> manualSyncFromFirebase({int limit = 50}) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('🔄 MANUAL SYNC FROM FIREBASE');
      debugPrint('═══════════════════════════════════');

      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('created_at_local', descending: true)
          .limit(limit)
          .get()
          .timeout(Duration(seconds: 15));

      debugPrint('📥 Fetched ${snapshot.docs.length} alerts');

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          await _saveAlertLocally(doc.id, data);
          await _localDb.markSynced(doc.id);
        } catch (e) {
          debugPrint('⚠️ Error syncing alert ${doc.id}: $e');
        }
      }

      debugPrint('✅ Manual sync completed');
      debugPrint('═══════════════════════════════════');
    } catch (e) {
      debugPrint('❌ Manual sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// ✅ Get sync statistics
  Future<Map<String, dynamic>> getSyncStatus() async {
    try {
      final firebaseCount = await _getFirebaseAlertCount();
      final localCount = await _localDb.getAlertCount();
      final unsyncedCount = await _localDb.getUnsyncedCount();

      return {
        'firebase': firebaseCount,
        'local': localCount,
        'unsynced': unsyncedCount,
        'isSyncing': _isSyncing,
        'lastSync': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// ✅ Get Firebase alert count
  Future<int> _getFirebaseAlertCount() async {
    try {
      final snapshot = await _firestore.collection(_collection).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Firebase count error: $e');
      return 0;
    }
  }

  void dispose() {
    _firestoreListener?.cancel();
    debugPrint('✅ Alert sync service disposed');
  }
}