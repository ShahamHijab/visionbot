// user app alert service

import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'alerts';

  static final String laptopServerUrl =
      dotenv.env['LAPTOP_SERVER_URL'] ?? '';

  Stream<List<AlertModel>> streamAlerts({
    int limit = 50,
    String? collection,
    String? orderField,
  }) {
    debugPrint('📡 Setting up hybrid alerts stream (limit: $limit)...');

    final controller = StreamController<List<AlertModel>>();

    StreamSubscription? firebaseSub;
    Timer? laptopTimer;

    Future<void> fetchLaptopAlerts() async {
      try {
        final alerts = await _fetchLaptopServerAlerts(limit);
        if (!controller.isClosed) {
          controller.add(alerts);
        }
      } catch (e) {
        debugPrint('⚠️ Laptop server fetch failed: $e');
        if (!controller.isClosed) {
          controller.add(<AlertModel>[]);
        }
      }
    }

    void startLaptopPolling() {
      laptopTimer?.cancel();

      fetchLaptopAlerts();

      laptopTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        fetchLaptopAlerts();
      });
    }

    try {
      firebaseSub = _firestore
          .collection(collection ?? _collection)
          .orderBy(orderField ?? 'created_at', descending: true)
          .limit(limit)
          .snapshots()
          .listen(
        (snapshot) {
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

            debugPrint('✅ Firebase stream received ${alerts.length} alerts');

            if (!controller.isClosed) {
              controller.add(alerts);
            }

            if (alerts.isEmpty) {
              debugPrint('⚠️ Firebase empty, checking laptop server...');
              fetchLaptopAlerts();
            }
          } catch (e) {
            debugPrint('❌ Stream conversion error: $e');
            startLaptopPolling();
          }
        },
        onError: (error) {
          debugPrint('⚠️ Firebase stream error: $error');
          debugPrint('📡 Switching to laptop server polling...');
          startLaptopPolling();
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase stream setup failed: $e');
      startLaptopPolling();
    }

    controller.onCancel = () async {
      await firebaseSub?.cancel();
      laptopTimer?.cancel();
    };

    return controller.stream;
  }

  Future<List<AlertModel>> _fetchLaptopServerAlerts(int limit) async {
    final response = await http
        .get(Uri.parse('$laptopServerUrl/api/phone/alerts'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Laptop server error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    // 🔧 FIX 1: safe list extraction
    final List rawAlerts = (decoded is Map && decoded['alerts'] is List)
        ? decoded['alerts']
        : [];

    final models = rawAlerts.map<AlertModel>((item) {
      final alert = Map<String, dynamic>.from(item as Map);

      final id = alert['alert_id']?.toString() ??
          alert['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final createdAtLocal = alert['created_at_local']?.toString();

      final json = {
        ...alert,
        'id': id,
        'title': _makeTitle(alert),
        'description': _makeDescription(alert),
        'timestamp':
            createdAtLocal ?? DateTime.now().toIso8601String(),
        'created_at_local': createdAtLocal,

        // 🔧 FIX 2: support Supabase + backend image keys (NO logic change)
        'imageUrl': alert['image_url']?.toString() ??
            alert['image_path']?.toString() ??
            alert['imageUrl']?.toString() ??
            '',

        'location': alert['location_name']?.toString() ??
            alert['location']?.toString() ??
            '',
        'locationName': alert['location_name']?.toString(),
        'robotId': alert['robot_id']?.toString() ?? '',
        'isRead': alert['isRead'] ?? false,
        'isResolved': alert['isResolved'] ?? false,
      };

      return AlertModel.fromJson(json);
    }).toList();

    models.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return models.take(limit).toList();
  }

  String _makeTitle(Map<String, dynamic> alert) {
    final type = alert['type']?.toString() ?? '';

    switch (type) {
      case 'unknown_face':
        return 'Unknown person';
      case 'known_face':
        return 'Known person';
      case 'group_detected':
        return 'Group detected';
      case 'smoke':
      case 'smoking_detected':
        return 'Smoke detected';
      default:
        return 'Alert';
    }
  }

  String _makeDescription(Map<String, dynamic> alert) {
    final note = alert['note']?.toString();
    if (note != null && note.trim().isNotEmpty) {
      return note;
    }

    final type = alert['type']?.toString() ?? '';

    if (type == 'group_detected') {
      final count = alert['person_count']?.toString() ?? '';
      return count.isNotEmpty
          ? 'Group of $count people detected'
          : 'Group detected';
    }

    if (type == 'unknown_face') {
      return 'Unknown face detected by robot camera';
    }

    if (type == 'smoke' || type == 'smoking_detected') {
      return 'Smoke detected by robot camera';
    }

    return 'New alert received from robot';
  }

  Future<AlertModel?> getAlert(String alertId) async {
    try {
      final doc =
          await _firestore.collection(_collection).doc(alertId).get();

      if (!doc.exists) {
        final laptopAlerts = await _fetchLaptopServerAlerts(500);

        try {
          return laptopAlerts.firstWhere((a) => a.id == alertId);
        } catch (_) {
          return null;
        }
      }

      return AlertModel.fromFirestore(doc);
    } catch (e) {
      final laptopAlerts = await _fetchLaptopServerAlerts(500);

      try {
        return laptopAlerts.firstWhere((a) => a.id == alertId);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> markAsRead(String alertId) async {
    try {
      await _firestore.collection(_collection).doc(alertId).update({
        'isRead': true,
        'read_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Mark read error: $e');
    }
  }

  Future<void> deleteAlert(String alertId) async {
    try {
      await _firestore.collection(_collection).doc(alertId).delete();
    } catch (e) {
      debugPrint('❌ Delete error: $e');
    }
  }

  Stream<int> streamUnreadCount() {
    final controller = StreamController<int>();

    StreamSubscription? firebaseSub;
    Timer? laptopTimer;

    Future<void> fetchLaptopUnread() async {
      try {
        final alerts = await _fetchLaptopServerAlerts(500);
        final unread = alerts.where((a) => !a.isRead).length;

        if (!controller.isClosed) {
          controller.add(unread);
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(0);
        }
      }
    }

    void startLaptopPolling() {
      laptopTimer?.cancel();

      fetchLaptopUnread();

      laptopTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        fetchLaptopUnread();
      });
    }

    try {
      firebaseSub = _firestore
          .collection(_collection)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .listen(
        (snapshot) {
          if (!controller.isClosed) {
            controller.add(snapshot.size);
          }
        },
        onError: (error) {
          startLaptopPolling();
        },
      );
    } catch (e) {
      startLaptopPolling();
    }

    controller.onCancel = () async {
      await firebaseSub?.cancel();
      laptopTimer?.cancel();
    };

    return controller.stream;
  }
}