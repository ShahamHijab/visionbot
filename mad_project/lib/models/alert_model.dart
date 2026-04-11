import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
  final String? locationName;
  final String robotId;
  final bool isRead;
  final bool isResolved;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String lens;
  final String note;
  final double? threshold;
  final DateTime? createdAtLocal;

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
    this.locationName,
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

  DateTime get createdAt => timestamp;

  bool get hasLocation => latitude != null && longitude != null;

  // ── fromFirestore ──────────────────────────────────────────────────────────
  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    // Debug: print all keys so you can see what your detection app sends
    if (kDebugMode) {
      debugPrint('=== Alert Doc [${doc.id}] keys: ${data.keys.toList()}');
      // Print any key that might contain an image URL
      for (final key in data.keys) {
        final val = data[key]?.toString() ?? '';
        if (val.startsWith('http') || key.toLowerCase().contains('image') || key.toLowerCase().contains('photo') || key.toLowerCase().contains('face') || key.toLowerCase().contains('url')) {
          debugPrint('  KEY: $key => $val');
        }
      }
    }

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
        data['title'] != null &&
                (data['title'].toString().trim().isNotEmpty)
            ? data['title'].toString()
            : parsedType.displayName;

    final description =
        data['description'] != null &&
                (data['description'].toString().trim().isNotEmpty)
            ? data['description'].toString()
            : note;

    // ── Image URL: try every possible field name ─────────────────────────────
    // Extended list covering common detection app naming conventions
    final imageUrl = _firstNonEmpty([
      // Direct image fields
      data['imageUrl'],
      data['image_url'],
      data['image'],
      data['photo_url'],
      data['photoUrl'],
      // Face-specific fields (detection apps often use these)
      data['face_image'],
      data['face_image_url'],
      data['face_img'],
      data['face_img_url'],
      data['face_photo'],
      data['face_photo_url'],
      data['faceImageUrl'],
      data['faceImage'],
      // Detection result fields
      data['detected_image'],
      data['detected_face'],
      data['detected_face_url'],
      data['detectedImageUrl'],
      // Snapshot / capture fields
      data['capture_url'],
      data['snapshot_url'],
      data['snapshot'],
      data['capture'],
      data['frame_url'],
      data['frameUrl'],
      // Download URL (Firebase Storage)
      data['downloadUrl'],
      data['download_url'],
      data['storageUrl'],
      data['storage_url'],
      // Firebase Storage direct
      data['gsUrl'],
      data['gs_url'],
      // Also check nested maps
      if (data['detection'] is Map)
        (data['detection'] as Map)['image_url'],
      if (data['detection'] is Map)
        (data['detection'] as Map)['imageUrl'],
      if (data['detection'] is Map)
        (data['detection'] as Map)['face_image'],
      if (data['detection'] is Map)
        (data['detection'] as Map)['face_url'],
      if (data['face'] is Map)
        (data['face'] as Map)['image_url'],
      if (data['face'] is Map)
        (data['face'] as Map)['imageUrl'],
      if (data['face'] is Map)
        (data['face'] as Map)['url'],
      if (data['result'] is Map)
        (data['result'] as Map)['image_url'],
      if (data['result'] is Map)
        (data['result'] as Map)['imageUrl'],
    ]);

    if (kDebugMode && imageUrl.isNotEmpty) {
      debugPrint('  => Found imageUrl for ${doc.id}: $imageUrl');
    }
    if (kDebugMode && imageUrl.isEmpty && (parsedType == AlertType.unknownFace || parsedType == AlertType.knownFace)) {
      debugPrint('  => WARNING: No imageUrl found for face alert ${doc.id}. Available data: $data');
    }

    // ── Location ──────────────────────────────────────────────────────────────
    double? lat;
    double? lng;
    String? locationName;

    final locField = data['location'];
    if (locField is Map) {
      lat = _toDoubleOrNull(locField['latitude']);
      lng = _toDoubleOrNull(locField['longitude']);
      locationName =
          (locField['location_name'] ?? '').toString();
      if (locationName!.isEmpty) locationName = null;
    } else {
      lat = _toDoubleOrNull(data['latitude']);
      lng = _toDoubleOrNull(data['longitude']);
    }

    final locationStr =
        locationName ??
        (data['location'] is String &&
                (data['location'] as String).trim().isNotEmpty
            ? (data['location'] as String).trim()
            : (lens.isEmpty ? '' : 'Lens: $lens'));

    final robotId =
        (data['robotId'] ?? data['robot_id'] ?? '').toString();

    return AlertModel(
      id: doc.id,
      type: parsedType,
      severity: severity,
      title: title,
      description: description,
      imageUrl: imageUrl,
      timestamp: createdAt,
      location: locationStr,
      latitude: lat,
      longitude: lng,
      locationName: locationName,
      robotId: robotId,
      isRead:
          (data['isRead'] ?? data['is_read'] ?? false) == true,
      isResolved:
          (data['isResolved'] ?? data['is_resolved'] ?? false) ==
              true,
      resolvedBy:
          data['resolvedBy']?.toString() ??
          data['resolved_by']?.toString(),
      resolvedAt:
          _parseFirestoreDateTime(data['resolvedAt']) ??
          _parseFirestoreDateTime(data['resolved_at']),
      lens: lens,
      note: note,
      threshold: thresholdVal,
      createdAtLocal:
          _parseIsoDateTime(data['created_at_local']),
    );
  }

  // ── fromJson ───────────────────────────────────────────────────────────────
  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: (json['id'] ?? '').toString(),
      type: AlertTypeX.fromString(
          (json['type'] ?? '').toString()),
      severity: AlertSeverityX.fromString(
          (json['severity'] ?? '').toString()),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      imageUrl: _firstNonEmpty([
        json['imageUrl'],
        json['image_url'],
        json['image'],
        json['photo_url'],
        json['face_image_url'],
        json['face_image'],
      ]),
      timestamp:
          _parseIsoDateTime(json['timestamp']) ?? DateTime.now(),
      location: (json['location'] ?? '').toString(),
      latitude: _toDoubleOrNull(json['latitude']),
      longitude: _toDoubleOrNull(json['longitude']),
      locationName: json['locationName']?.toString(),
      robotId: (json['robotId'] ?? '').toString(),
      isRead: json['isRead'] == true,
      isResolved: json['isResolved'] == true,
      resolvedBy: json['resolvedBy']?.toString(),
      resolvedAt: _parseIsoDateTime(json['resolvedAt']),
      lens: (json['lens'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      threshold: _toDoubleOrNull(json['threshold']),
      createdAtLocal:
          _parseIsoDateTime(json['created_at_local']),
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
      'locationName': locationName,
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
    String? locationName,
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
      locationName: locationName ?? this.locationName,
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

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Returns the first non-null, non-empty string from the list.
  static String _firstNonEmpty(List<dynamic?> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      final s = c.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return '';
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

// ── Enums ──────────────────────────────────────────────────────────────────

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
      case AlertType.fire:        return 'Fire detected';
      case AlertType.smoke:       return 'Smoke detected';
      case AlertType.human:       return 'Person detected';
      case AlertType.motion:      return 'Motion detected';
      case AlertType.restricted:  return 'Restricted area entry';
      case AlertType.unknownFace: return 'Unknown person';
      case AlertType.knownFace:   return 'Known person';
      case AlertType.intruder:    return 'Intruder detected';
      case AlertType.other:       return 'Alert';
    }
  }

  String get icon {
    switch (this) {
      case AlertType.fire:        return '🔥';
      case AlertType.smoke:       return '💨';
      case AlertType.human:       return '👤';
      case AlertType.motion:      return '🏃';
      case AlertType.restricted:  return '🚫';
      case AlertType.unknownFace: return '❓';
      case AlertType.knownFace:   return '✅';
      case AlertType.intruder:    return '🛡️';
      case AlertType.other:       return '⚠️';
    }
  }
}

extension AlertSeverityExtension on AlertSeverity {
  String get displayName {
    switch (this) {
      case AlertSeverity.critical: return 'Critical';
      case AlertSeverity.warning:  return 'Warning';
      case AlertSeverity.info:     return 'Info';
    }
  }
}

class AlertTypeX {
  static AlertType fromString(String raw) {
    final t = raw.toLowerCase().trim();
    if (t == 'fire')          return AlertType.fire;
    if (t == 'smoke')         return AlertType.smoke;
    if (t == 'human')         return AlertType.human;
    if (t == 'motion')        return AlertType.motion;
    if (t == 'restricted')    return AlertType.restricted;
    if (t == 'unknown_face' || t == 'unknownface' || t == 'unknown')
                              return AlertType.unknownFace;
    if (t == 'known_face' || t == 'knownface' || t == 'known')
                              return AlertType.knownFace;
    if (t == 'intruder')      return AlertType.intruder;
    if (t == 'other')         return AlertType.other;
    return AlertType.other;
  }
}

class AlertSeverityX {
  static AlertSeverity fromString(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'critical') return AlertSeverity.critical;
    if (s == 'warning')  return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  static AlertSeverity infer({
    required AlertType type,
    double? threshold,
  }) {
    if (type == AlertType.fire || type == AlertType.intruder) {
      return AlertSeverity.critical;
    }
    if (type == AlertType.smoke ||
        type == AlertType.unknownFace) {
      return AlertSeverity.warning;
    }
    return AlertSeverity.info;
  }
}