import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'alerts';

  /// ✅ Stream alerts - OPTIMIZED for performance
  Stream<List<AlertModel>> streamAlerts({
    int limit = 50,
    String? collection,
    String? orderField,
  }) {
    debugPrint('📡 Setting up alerts stream (limit: $limit)...');

    return _firestore
        .collection(collection ?? _collection)
        .orderBy(orderField ?? 'created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map<List<AlertModel>>((snapshot) {
          try {
            final alerts = snapshot.docs
                .map((doc) {
                  try {
                    return AlertModel.fromFirestore(doc);
                  } catch (e) {
                    debugPrint('⚠️ Error converting doc ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<AlertModel>()
                .toList();

            debugPrint('✅ Stream received ${alerts.length} alerts');
            return alerts;
          } catch (e) {
            debugPrint('❌ Stream conversion error: $e');
            return <AlertModel>[];
          }
        })
        .handleError((error) {
          debugPrint('⚠️ Firebase stream error: $error');
        });
  }

  /// ✅ Get single alert by ID
  Future<AlertModel?> getAlert(String alertId) async {
    try {
      debugPrint('📡 Fetching alert: $alertId');

      final doc = await _firestore
          .collection(_collection)
          .doc(alertId)
          .get();

      if (!doc.exists) {
        debugPrint('❌ Alert not found');
        return null;
      }

      return AlertModel.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('❌ Error fetching alert: $e\n$st');
      return null;
    }
  }

  /// ✅ Mark alert as read
  Future<void> markAsRead(String alertId) async {
    try {
      debugPrint('📌 Marking alert $alertId as read');

      await _firestore.collection(_collection).doc(alertId).update({
        'isRead': true,
        'read_at': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Alert marked as read');
    } catch (e, st) {
      debugPrint('❌ Mark read error: $e\n$st');
    }
  }

  /// ✅ Delete alert
  Future<void> deleteAlert(String alertId) async {
    try {
      debugPrint('🗑️  Deleting alert $alertId');

      await _firestore.collection(_collection).doc(alertId).delete();

      debugPrint('✅ Alert deleted');
    } catch (e, st) {
      debugPrint('❌ Delete error: $e\n$st');
    }
  }

  /// ✅ Get unread count
  Stream<int> streamUnreadCount() {
    return _firestore
        .collection(_collection)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }
}