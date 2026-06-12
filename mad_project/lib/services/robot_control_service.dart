// mad_project/lib/services/robot_control_service.dart
// ✅ Publishes robot movement commands to Firestore
// The detectapp listens to 'robot_commands' collection and acts on them

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum RobotDirection { forward, backward, left, right, stop }

enum RobotCamera { front, back }

class RobotCommand {
  final String id;
  final RobotDirection direction;
  final int speed; // 0–100
  final String sentBy;
  final DateTime sentAt;
  final bool isExecuted;

  const RobotCommand({
    required this.id,
    required this.direction,
    required this.speed,
    required this.sentBy,
    required this.sentAt,
    this.isExecuted = false,
  });

  Map<String, dynamic> toMap() => {
        'direction': direction.name,
        'speed': speed,
        'sent_by': sentBy,
        'sent_at': FieldValue.serverTimestamp(),
        'sent_at_local': sentAt.toIso8601String(),
        'is_executed': false,
        'status': 'pending',
      };
}

class RobotStatus {
  final bool isOnline;
  final String mode; // 'auto' | 'manual'
  final int batteryLevel;
  final String currentCamera;
  final DateTime lastSeen;
  final String? currentTask;

  const RobotStatus({
    required this.isOnline,
    required this.mode,
    required this.batteryLevel,
    required this.currentCamera,
    required this.lastSeen,
    this.currentTask,
  });

  factory RobotStatus.offline() => RobotStatus(
        isOnline: false,
        mode: 'unknown',
        batteryLevel: 0,
        currentCamera: 'front',
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      );

  factory RobotStatus.fromMap(Map<String, dynamic> data) {
    DateTime lastSeen;
    final raw = data['last_seen'];
    if (raw is Timestamp) {
      lastSeen = raw.toDate();
    } else {
      lastSeen = DateTime.tryParse(raw?.toString() ?? '') ?? DateTime.now();
    }

    return RobotStatus(
      isOnline: (data['is_online'] ?? false) == true,
      mode: (data['mode'] ?? 'auto').toString(),
      batteryLevel: (data['battery_level'] ?? 0) as int,
      currentCamera: (data['current_camera'] ?? 'front').toString(),
      lastSeen: lastSeen,
      currentTask: data['current_task']?.toString(),
    );
  }
}

class RobotControlService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _commandsCollection = 'robot_commands';
  static const String _statusCollection = 'robot_status';
  static const String _robotId = 'visionbot_robot_1';

  StreamSubscription? _statusSub;

  // ── Send a direction command ─────────────────────────────────────────────
  Future<void> sendCommand(RobotDirection direction, {int speed = 60}) async {
    try {
      final user = _auth.currentUser;
      final sentBy = user?.displayName ?? user?.email ?? 'unknown';

      final cmd = RobotCommand(
        id: '',
        direction: direction,
        speed: speed,
        sentBy: sentBy,
        sentAt: DateTime.now(),
      );

      await _db.collection(_commandsCollection).add(cmd.toMap());

      debugPrint('🎮 Command sent: ${direction.name} at speed $speed');
    } catch (e, st) {
      debugPrint('❌ Send command error: $e\n$st');
    }
  }

  // ── Switch camera lens ───────────────────────────────────────────────────
  Future<void> switchCamera(RobotCamera camera) async {
    try {
      await _db.collection(_commandsCollection).add({
        'action': 'switch_camera',
        'camera': camera.name,
        'sent_at': FieldValue.serverTimestamp(),
        'sent_at_local': DateTime.now().toIso8601String(),
        'is_executed': false,
        'status': 'pending',
      });
      debugPrint('📷 Camera switch: ${camera.name}');
    } catch (e) {
      debugPrint('❌ Switch camera error: $e');
    }
  }

  // ── Switch robot mode (auto / manual) ───────────────────────────────────
  Future<void> setMode(String mode) async {
    try {
      await _db.collection(_statusCollection).doc(_robotId).set(
        {'mode': mode, 'mode_updated_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await _db.collection(_commandsCollection).add({
        'action': 'set_mode',
        'mode': mode,
        'sent_at': FieldValue.serverTimestamp(),
        'sent_at_local': DateTime.now().toIso8601String(),
        'is_executed': false,
        'status': 'pending',
      });
      debugPrint('⚙️ Mode set: $mode');
    } catch (e) {
      debugPrint('❌ Set mode error: $e');
    }
  }

  // ── Emergency stop ───────────────────────────────────────────────────────
  Future<void> emergencyStop() async {
    try {
      // Send multiple stops for reliability
      final batch = _db.batch();
      for (int i = 0; i < 3; i++) {
        final ref = _db.collection(_commandsCollection).doc();
        batch.set(ref, {
          'direction': 'stop',
          'speed': 0,
          'priority': 'emergency',
          'sent_at': FieldValue.serverTimestamp(),
          'sent_at_local': DateTime.now().toIso8601String(),
          'is_executed': false,
          'status': 'pending',
        });
      }
      await batch.commit();
      debugPrint('🛑 EMERGENCY STOP sent');
    } catch (e) {
      debugPrint('❌ Emergency stop error: $e');
    }
  }

  // ── Stream robot status ──────────────────────────────────────────────────
  Stream<RobotStatus> streamRobotStatus() {
    return _db
        .collection(_statusCollection)
        .doc(_robotId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return RobotStatus.offline();
      }
      return RobotStatus.fromMap(snap.data()!);
    }).handleError((_) => RobotStatus.offline());
  }

  // ── Recent commands stream ───────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> streamRecentCommands({int limit = 10}) {
    return _db
        .collection(_commandsCollection)
        .orderBy('sent_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .handleError((_) => <Map<String, dynamic>>[]);
  }

  void dispose() {
    _statusSub?.cancel();
  }
}