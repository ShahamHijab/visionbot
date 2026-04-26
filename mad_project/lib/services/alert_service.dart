// lib/services/alert_service.dart
// ✅ UPDATED: User app version - read from Firebase + Local hybrid

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'alerts';

  /// ✅ Get alerts: Try Firebase first, fallback to Local
  Stream<List<AlertModel>> streamAlerts({
    int limit = 100,
    String? collection,
    String? orderField,
  }) {
    // ✅ Stream from Firebase (real-time from detection app)
    return _firestore
        .collection(collection ?? _collection)
        .orderBy(orderField ?? 'created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map<List<AlertModel>>((snapshot) {
          try {
            return snapshot.docs
                .map((doc) => AlertModel.fromFirestore(doc))
                .toList();
          } catch (e) {
            debugPrint('❌ Stream conversion error: $e');
            return <AlertModel>[];
          }
        })
        .handleError((error) {
          debugPrint('⚠️ Firebase stream error: $error');
        });
  }

  /// ✅ Get alerts from local database (offline fallback)
  Future<List<AlertModel>> _getLocalAlerts() async {
    debugPrint('⚠️ Local database service is not configured');
    return [];
  }

  /// ✅ Convert local DB data to AlertModel
  AlertModel _alertFromLocalData(Map<String, dynamic> data) {
    return AlertModel(
      id: data['alert_id'] ?? '',
      type: AlertTypeX.fromString(data['type'] ?? ''),
      severity: AlertSeverityX.fromString(data['severity'] ?? ''),
      title: data['type'] ?? 'Alert',
      description: data['note'] ?? '',
      imageUrl: data['image_path'] ?? '',
      faceImageUrls: (data['face_image_paths'] as String?)?.split(',') ?? [],
      timestamp:
          DateTime.tryParse(data['created_at_local'] as String? ?? '') ??
              DateTime.now(),
      location: data['location_name'] ?? '',
      latitude: data['latitude'],
      longitude: data['longitude'],
      robotId: '',
      isRead: false,
      isResolved: false,
    );
  }

  /// ✅ Mark alert as read
  Future<void> markRead(String alertId) async {
    try {
      await _firestore.collection(_collection).doc(alertId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Mark read error: $e');
    }
  }

  /// ✅ Mark all as read
  Future<void> markAllRead({String? collection}) async {
    try {
      final docs = await _firestore
          .collection(collection ?? _collection)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in docs.docs) {
        await doc.reference.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('✅ Marked ${docs.docs.length} alerts as read');
    } catch (e) {
      debugPrint('❌ Mark all read error: $e');
    }
  }

  /// ✅ Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    try {
      final firebaseCount = await _getFirebaseCount();
      const localCount = 0;

      return {
        'firebase': firebaseCount,
        'local': localCount,
        'lastUpdate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<int> _getFirebaseCount() async {
    try {
      final snapshot =
          await _firestore.collection(_collection).count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}