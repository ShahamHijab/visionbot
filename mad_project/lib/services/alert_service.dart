import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/alert_model.dart';
import '../models/gallery_image_item.dart';

class AlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // lib/services/alert_service.dart (USER APP)

Stream<List<AlertModel>> streamAlerts({
  int limit = 100,
  String collection = 'alerts',
  String orderField = 'created_at',
}) {
  return FirebaseFirestore.instance
      .collection(collection)
      .orderBy(orderField, descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AlertModel.fromFirestore(doc))
          .toList());
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

  Future<void> markAllRead({String collection = 'alerts'}) async {
    final unread = await _db
        .collection(collection)
        .where('isRead', isEqualTo: false)
        .get();

    if (unread.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Stream<List<GalleryImageItem>> streamImagesFromStorage() {
    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      final ref = FirebaseStorage.instance.ref('images/');
      final list = await ref.listAll();
      final items = <GalleryImageItem>[];

      for (final item in list.items) {
        final url = await item.getDownloadURL();
        final metadata = await item.getMetadata();
        final name = item.name;

        // Parse name, e.g. "fire_123.jpg" -> type = fire
        final parts = name.split('_');
        final typeStr = parts.isNotEmpty ? parts[0] : 'other';
        AlertType alertType;
        String label;
        switch (typeStr) {
          case 'fire':
            alertType = AlertType.fire;
            label = 'Fire';
            break;
          case 'smoke':
            alertType = AlertType.smoke;
            label = 'Smoke';
            break;
          case 'human':
            alertType = AlertType.human;
            label = 'Person';
            break;
          case 'motion':
            alertType = AlertType.motion;
            label = 'Motion';
            break;
          case 'restricted':
            alertType = AlertType.restricted;
            label = 'Restricted';
            break;
          case 'unknownFace':
            alertType = AlertType.unknownFace;
            label = 'Unknown Person';
            break;
          case 'knownFace':
            alertType = AlertType.knownFace;
            label = 'Known Person';
            break;
          case 'intruder':
            alertType = AlertType.intruder;
            label = 'Intruder';
            break;
          default:
            alertType = AlertType.other;
            label = 'Alert';
        }

        final timestamp = metadata.timeCreated ?? DateTime.now();
        items.add(
          GalleryImageItem(
            imageUrl: url,
            label: label,
            alertId: name, // use name as id
            timestamp: timestamp,
            alertType: alertType,
            lens: '', // no lens info
            note: '', // no note info
            isFaceCrop: name.contains('face'),
          ),
        );
      }

      items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return items;
    });
  }
}
