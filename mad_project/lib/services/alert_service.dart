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

  // CHANGE THIS TO YOUR LAPTOP SERVER IP
  // Example: http://192.168.1.12:3000
static final String laptopServerUrl =     dotenv.env['LAPTOP_SERVER_URL'] ?? '';
  /// Stream alerts:
  /// Firebase first.
  /// If Firebase fails, laptop server polling starts.
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

            // If Firebase is reachable but empty, also check laptop server once.
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
    final List alerts = decoded['alerts'] ?? [];

    final models = alerts.map<AlertModel>((item) {
      final alert = Map<String, dynamic>.from(item);

      final id = alert['alert_id']?.toString() ??
          alert['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final createdAtLocal = alert['created_at_local']?.toString();

      final json = {
        ...alert,
        'id': id,
        'title': _makeTitle(alert),
        'description': _makeDescription(alert),
        'timestamp': createdAtLocal ?? DateTime.now().toIso8601String(),
        'created_at_local': createdAtLocal,
        'imageUrl': alert['image_path']?.toString() ?? '',
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

  /// Get single alert by ID
  Future<AlertModel?> getAlert(String alertId) async {
    try {
      debugPrint('📡 Fetching alert from Firebase: $alertId');

      final doc = await _firestore.collection(_collection).doc(alertId).get();

      if (!doc.exists) {
        debugPrint('❌ Firebase alert not found, trying laptop server');

        final laptopAlerts = await _fetchLaptopServerAlerts(500);

        try {
          return laptopAlerts.firstWhere((a) => a.id == alertId);
        } catch (_) {
          return null;
        }
      }

      return AlertModel.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('❌ Error fetching Firebase alert: $e\n$st');

      try {
        final laptopAlerts = await _fetchLaptopServerAlerts(500);

        try {
          return laptopAlerts.firstWhere((a) => a.id == alertId);
        } catch (_) {
          return null;
        }
      } catch (_) {
        return null;
      }
    }
  }

  /// Mark alert as read.
  /// Works for Firebase alerts only.
  /// Laptop server currently has no mark-read endpoint.
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

  /// Delete alert.
  /// Works for Firebase alerts only.
  /// Laptop server currently has no delete endpoint.
  Future<void> deleteAlert(String alertId) async {
    try {
      debugPrint('🗑️ Deleting alert $alertId');

      await _firestore.collection(_collection).doc(alertId).delete();

      debugPrint('✅ Alert deleted');
    } catch (e, st) {
      debugPrint('❌ Delete error: $e\n$st');
    }
  }

  /// Firebase unread stream.
  /// If Firebase fails, returns laptop-server unread count by polling.
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
        debugPrint('⚠️ Laptop unread count failed: $e');

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
          debugPrint('⚠️ Firebase unread stream error: $error');
          startLaptopPolling();
        },
      );
    } catch (e) {
      debugPrint('❌ Firebase unread stream setup failed: $e');
      startLaptopPolling();
    }

    controller.onCancel = () async {
      await firebaseSub?.cancel();
      laptopTimer?.cancel();
    };

    return controller.stream;
  }
}