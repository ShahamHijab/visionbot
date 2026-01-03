import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
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
    this.latitude,
    this.longitude,
    required this.robotId,
    this.isRead = false,
    this.isResolved = false,
    this.resolvedBy,
    this.resolvedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.toString() == 'AlertType.${json['type']}',
        orElse: () => AlertType.other,
      ),
      severity: AlertSeverity.values.firstWhere(
        (e) => e.toString() == 'AlertSeverity.${json['severity']}',
        orElse: () => AlertSeverity.info,
      ),
      title: json['title'] ?? 'Alert',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      location: json['location'] ?? '',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      robotId: json['robotId'] ?? '',
      isRead: json['isRead'] ?? false,
      isResolved: json['isResolved'] ?? false,
      resolvedBy: json['resolvedBy'],
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'])
          : null,
    );
  }

  factory AlertModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    AlertType parseType(dynamic v) {
      final s = (v ?? 'other').toString().toLowerCase().trim();
      for (final t in AlertType.values) {
        if (t.name == s) return t;
      }
      return AlertType.other;
    }

    AlertSeverity parseSeverity(dynamic v) {
      final s = (v ?? 'info').toString().toLowerCase().trim();
      for (final sev in AlertSeverity.values) {
        if (sev.name == s) return sev;
      }
      return AlertSeverity.info;
    }

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
      if (v is int) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        if (s == 'true') return true;
        if (s == 'false') return false;
      }
      return fallback;
    }

    return AlertModel(
      id: doc.id,
      type: parseType(data['type']),
      severity: parseSeverity(data['severity']),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'robotId': robotId,
      'isRead': isRead,
      'isResolved': isResolved,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  AlertModel copyWith({
    String? id,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? description,
    String? imageUrl,
    DateTime? timestamp,
    String? location,
    double? latitude,
    double? longitude,
    String? robotId,
    bool? isRead,
    bool? isResolved,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return AlertModel(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      robotId: robotId ?? this.robotId,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

enum AlertType { fire, smoke, human, motion, restricted, other }

enum AlertSeverity { critical, warning, info }

extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.fire:
        return 'Fire Detected';
      case AlertType.smoke:
        return 'Smoke Detected';
      case AlertType.human:
        return 'Human Detected';
      case AlertType.motion:
        return 'Motion Detected';
      case AlertType.restricted:
        return 'Restricted Area Entry';
      case AlertType.other:
        return 'Other Alert';
    }
  }

  String get icon {
    switch (this) {
      case AlertType.fire:
        return '🔥';
      case AlertType.smoke:
        return '💨';
      case AlertType.human:
        return '👤';
      case AlertType.motion:
        return '🏃';
      case AlertType.restricted:
        return '🚫';
      case AlertType.other:
        return '⚠️';
    }
  }
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.info:
        return 'Info';
    }
  }
}
