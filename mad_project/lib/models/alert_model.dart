import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;

  // Existing UI fields (used by alert_card, alert_detail, etc)
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

  // New fields that match your Firestore alerts document
  final String lens; // "back"
  final String note; // "Unknown face detected"
  final double? threshold; // 0.45
  final DateTime? createdAtLocal; // from created_at_local (string)

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
    this.lens = '',
    this.note = '',
    this.threshold,
    this.createdAtLocal,
  });

  // Backward compatible alias
  DateTime get createdAt => timestamp;

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    final rawType = (data['type'] ?? '').toString();
    final parsedType = AlertTypeX.fromString(rawType);

    final thresholdVal = _toDoubleOrNull(data['threshold']);

    final createdAt =
        _parseFirestoreDateTime(data['created_at']) ??
        _parseIsoDateTime(data['created_at_local']) ??
        _parseFirestoreDateTime(data['timestamp']) ??
        DateTime.now();

    final lens = (data['lens'] ?? '').toString();
    final note = (data['note'] ?? '').toString();

    final severity = AlertSeverityX.infer(
      type: parsedType,
      threshold: thresholdVal,
    );

    final title =
        data['title'] != null && (data['title'].toString().trim().isNotEmpty)
        ? data['title'].toString()
        : parsedType.displayName; // unknown_face -> Unknown person

    final description =
        data['description'] != null &&
            (data['description'].toString().trim().isNotEmpty)
        ? data['description'].toString()
        : note;

    final imageUrl = (data['imageUrl'] ?? data['image_url'] ?? '').toString();

    final location =
        data['location'] != null &&
            (data['location'].toString().trim().isNotEmpty)
        ? data['location'].toString()
        : (lens.isEmpty ? '' : 'Lens: $lens');

    final robotId = (data['robotId'] ?? data['robot_id'] ?? '').toString();

    return AlertModel(
      id: doc.id,
      type: parsedType,
      severity: severity,
      title: title,
      description: description,
      imageUrl: imageUrl,
      timestamp: createdAt,
      location: location,
      latitude: _toDoubleOrNull(data['latitude']),
      longitude: _toDoubleOrNull(data['longitude']),
      robotId: robotId,
      isRead: (data['isRead'] ?? data['is_read'] ?? false) == true,
      isResolved: (data['isResolved'] ?? data['is_resolved'] ?? false) == true,
      resolvedBy:
          data['resolvedBy']?.toString() ?? data['resolved_by']?.toString(),
      resolvedAt:
          _parseFirestoreDateTime(data['resolvedAt']) ??
          _parseFirestoreDateTime(data['resolved_at']),
      lens: lens,
      note: note,
      threshold: thresholdVal,
      createdAtLocal: _parseIsoDateTime(data['created_at_local']),
    );
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] ?? '').toString(),
      type: AlertTypeX.fromString((json['type'] ?? '').toString()),
      severity: AlertSeverityX.fromString((json['severity'] ?? '').toString()),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      timestamp: _parseIsoDateTime(json['timestamp']) ?? DateTime.now(),
      location: (json['location'] ?? '').toString(),
      latitude: _toDoubleOrNull(json['latitude']),
      longitude: _toDoubleOrNull(json['longitude']),
      robotId: (json['robotId'] ?? '').toString(),
      isRead: json['isRead'] == true,
      isResolved: json['isResolved'] == true,
      resolvedBy: json['resolvedBy']?.toString(),
      resolvedAt: _parseIsoDateTime(json['resolvedAt']),
      lens: (json['lens'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      threshold: _toDoubleOrNull(json['threshold']),
      createdAtLocal: _parseIsoDateTime(json['created_at_local']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name,
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
      'lens': lens,
      'note': note,
      'threshold': threshold,
      'created_at_local': createdAtLocal?.toIso8601String(),
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
    String? lens,
    String? note,
    double? threshold,
    DateTime? createdAtLocal,
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
      lens: lens ?? this.lens,
      note: note ?? this.note,
      threshold: threshold ?? this.threshold,
      createdAtLocal: createdAtLocal ?? this.createdAtLocal,
    );
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _parseIsoDateTime(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static DateTime? _parseFirestoreDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return _parseIsoDateTime(v);
  }
}

enum AlertType {
  fire,
  smoke,
  human,
  motion,
  restricted,
  other,

  unknownFace,
  knownFace,
  intruder,
}

enum AlertSeverity { critical, warning, info }

extension AlertTypeExtension on AlertType {
  String get displayName {
    switch (this) {
      case AlertType.fire:
        return 'Fire detected';
      case AlertType.smoke:
        return 'Smoke detected';
      case AlertType.human:
        return 'Person detected';
      case AlertType.motion:
        return 'Motion detected';
      case AlertType.restricted:
        return 'Restricted area entry';
      case AlertType.unknownFace:
        return 'Unknown person';
      case AlertType.knownFace:
        return 'Known person';
      case AlertType.intruder:
        return 'Intruder detected';
      case AlertType.other:
        return 'Alert';
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
      case AlertType.unknownFace:
        return '❓';
      case AlertType.knownFace:
        return '✅';
      case AlertType.intruder:
        return '🛡️';
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

class AlertTypeX {
  static AlertType fromString(String raw) {
    final t = raw.toLowerCase().trim();

    if (t == 'fire') return AlertType.fire;
    if (t == 'smoke') return AlertType.smoke;
    if (t == 'human') return AlertType.human;
    if (t == 'motion') return AlertType.motion;
    if (t == 'restricted') return AlertType.restricted;

    if (t == 'unknown_face') return AlertType.unknownFace;
    if (t == 'known_face') return AlertType.knownFace;
    if (t == 'intruder') return AlertType.intruder;

    if (t == 'other') return AlertType.other;

    return AlertType.other;
  }
}

class AlertSeverityX {
  static AlertSeverity fromString(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'critical') return AlertSeverity.critical;
    if (s == 'warning') return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  static AlertSeverity infer({required AlertType type, double? threshold}) {
    if (type == AlertType.fire || type == AlertType.intruder) {
      return AlertSeverity.critical;
    }

    if (type == AlertType.smoke || type == AlertType.unknownFace) {
      return AlertSeverity.warning;
    }

    if (threshold != null &&
        threshold <= 0.5 &&
        type == AlertType.unknownFace) {
      return AlertSeverity.warning;
    }

    return AlertSeverity.info;
  }
}
