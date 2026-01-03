import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AlertModel>> streamAlerts({
    int limit = 20,
    String collection = 'alerts',
    String orderField = 'created_at',
  }) {
    return _db
        .collection(collection)
        .orderBy(orderField, descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => AlertModel.fromFirestore(d)).toList(),
        );
  }

  Stream<AlertModel?> streamAlertById(
    String id, {
    String collection = 'alerts',
  }) {
    return _db.collection(collection).doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AlertModel.fromFirestore(doc);
    });
  }

  Future<AlertModel?> getAlertById(
    String id, {
    String collection = 'alerts',
  }) async {
    final doc = await _db.collection(collection).doc(id).get();
    if (!doc.exists) return null;
    return AlertModel.fromFirestore(doc);
  }

  Future<void> markRead(String id, {String collection = 'alerts'}) async {
    await _db.collection(collection).doc(id).update({'isRead': true});
  }
}
