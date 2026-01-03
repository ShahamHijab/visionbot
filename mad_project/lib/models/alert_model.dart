import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;

  final String type;
  final String severity;

  final String title;
  final String description;

  final String imageUrl;

  final DateTime timestamp;

  final String location;
  final double? latitude;
  final double? longitude;

  final String robotId;

  final bool isRead;
  final bool isResolved;

  final String? resolvedBy;
  final DateTime? resolvedAt;

  AlertModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timestamp,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.robotId,
    required this.isRead,
    required this.isResolved,
    required this.resolvedBy,
    required this.resolvedAt,
  });

  factory AlertModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      if (v is String) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }

    bool parseBool(dynamic v, bool fallback) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is String) {
        final s = v.toLowerCase().trim();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
      if (v is int) return v != 0;
      return fallback;
    }

    return AlertModel(
      id: doc.id,
      type: (data['type'] ?? 'other').toString(),
      severity: (data['severity'] ?? 'info').toString(),
      title: (data['title'] ?? 'Alert').toString(),
      description: (data['description'] ?? '').toString(),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      timestamp: parseDate(data['timestamp']),
      location: (data['location'] ?? '').toString(),
      latitude: parseDouble(data['latitude']),
      longitude: parseDouble(data['longitude']),
      robotId: (data['robotId'] ?? '').toString(),
      isRead: parseBool(data['isRead'], false),
      isResolved: parseBool(data['isResolved'], false),
      resolvedBy: data['resolvedBy']?.toString(),
      resolvedAt: parseNullableDate(data['resolvedAt']),
    );
  }
}
