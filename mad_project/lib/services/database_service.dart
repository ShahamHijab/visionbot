// lib/services/database_service.dart - USER APP
// ✅ RECEIVES ALERTS FROM FIREBASE (detection app publishes)
// SYNCHRONIZES WITH LOCAL CACHE FOR OFFLINE ACCESS

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  // ✅ GET: Database instance (lazy initialization)
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ✅ INIT: Initialize local SQLite database
  Future<Database> _initDatabase() async {
    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('🗄️ INITIALIZING LOCAL CACHE DB');
      debugPrint('═══════════════════════════════════');

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'visionbot_user_cache.db');

      debugPrint('📍 Database Location: $path');
      debugPrint('');

      final db = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
      );

      debugPrint('✅ LOCAL DATABASE: Successfully initialized!');
      debugPrint('═══════════════════════════════════');
      debugPrint('');

      return db;
    } catch (e, st) {
      debugPrint('❌ DATABASE INIT ERROR: $e');
      debugPrint('   Stack: $st');
      rethrow;
    }
  }

  // ✅ CREATE TABLES: Schema for receiving alerts
  Future<void> _createTables(Database db, int version) async {
    try {
      debugPrint('📝 CREATING CACHE TABLES...');
      debugPrint('');

      // ✅ Alerts table - cached from Firestore
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alerts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          alert_id TEXT UNIQUE NOT NULL,
          type TEXT NOT NULL,
          severity TEXT,
          title TEXT,
          description TEXT,
          image_url TEXT,
          face_image_urls TEXT,
          timestamp TEXT NOT NULL,
          location TEXT,
          latitude REAL,
          longitude REAL,
          location_name TEXT,
          robot_id TEXT,
          is_read INTEGER DEFAULT 0,
          is_resolved INTEGER DEFAULT 0,
          resolved_by TEXT,
          resolved_at TEXT,
          lens TEXT,
          note TEXT,
          threshold REAL,
          created_at_local TEXT,
          synced_from_firebase INTEGER DEFAULT 1,
          cached_at TEXT NOT NULL
        )
      ''');

      // ✅ Unread count cache
      await db.execute('''
        CREATE TABLE IF NOT EXISTS alert_stats (
          id INTEGER PRIMARY KEY,
          total_alerts INTEGER DEFAULT 0,
          unread_count INTEGER DEFAULT 0,
          critical_count INTEGER DEFAULT 0,
          last_updated TEXT NOT NULL
        )
      ''');

      debugPrint('✅ TABLES CREATED:');
      debugPrint('   ✓ alerts - ${await db.rawQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='alerts'")}');
      debugPrint('   ✓ alert_stats');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ TABLE CREATION ERROR: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ RECEIVE FROM FIREBASE & CACHE LOCALLY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream alerts from Firebase (real-time updates)
  Stream<List<Map<String, dynamic>>> streamAlertsFromFirebase() {
    try {
      return FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('created_at', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        final alerts = <Map<String, dynamic>>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          alerts.add({
            'alert_id': doc.id,
            ...data,
          });
        }
        return alerts;
      });
    } catch (e) {
      debugPrint('❌ Stream alerts error: $e');
      return Stream.value([]);
    }
  }

  /// Cache alert locally when received from Firebase
  Future<void> cacheAlertLocally(Map<String, dynamic> alert) async {
    try {
      final db = await database;
      
      final faceUrlsJson = alert['face_image_urls'] is List
          ? (alert['face_image_urls'] as List).join('|')
          : alert['face_image_urls'] ?? '';

      await db.insert(
        'alerts',
        {
          'alert_id': alert['alert_id'] ?? alert['id'],
          'type': alert['type'] ?? 'other',
          'severity': alert['severity'] ?? 'info',
          'title': alert['title'] ?? '',
          'description': alert['description'] ?? '',
          'image_url': alert['image_url'] ?? alert['image_path'] ?? '',
          'face_image_urls': faceUrlsJson,
          'timestamp': alert['timestamp'] ?? DateTime.now().toIso8601String(),
          'location': alert['location'] ?? '',
          'latitude': alert['latitude'],
          'longitude': alert['longitude'],
          'location_name': alert['location_name'],
          'robot_id': alert['robot_id'] ?? '',
          'is_read': alert['is_read'] == true ? 1 : 0,
          'is_resolved': alert['is_resolved'] == true ? 1 : 0,
          'resolved_by': alert['resolved_by'],
          'resolved_at': alert['resolved_at'],
          'lens': alert['lens'] ?? '',
          'note': alert['note'] ?? '',
          'threshold': alert['threshold'],
          'created_at_local': alert['created_at_local'],
          'synced_from_firebase': 1,
          'cached_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('✅ LOCAL CACHE: Alert saved - ${alert['alert_id']}');
      await _updateAlertStats();
    } catch (e) {
      debugPrint('❌ CACHE ALERT ERROR: $e');
    }
  }

  /// Batch cache multiple alerts
  Future<void> batchCacheAlerts(List<Map<String, dynamic>> alerts) async {
    try {
      debugPrint('📦 BATCH CACHING ${alerts.length} alerts...');
      final db = await database;

      for (final alert in alerts) {
        try {
          final faceUrlsJson = alert['face_image_urls'] is List
              ? (alert['face_image_urls'] as List).join('|')
              : alert['face_image_urls'] ?? '';

          await db.insert(
            'alerts',
            {
              'alert_id': alert['alert_id'] ?? alert['id'],
              'type': alert['type'] ?? 'other',
              'severity': alert['severity'] ?? 'info',
              'title': alert['title'] ?? '',
              'description': alert['description'] ?? '',
              'image_url': alert['image_url'] ?? alert['image_path'] ?? '',
              'face_image_urls': faceUrlsJson,
              'timestamp': alert['timestamp'] ?? DateTime.now().toIso8601String(),
              'location': alert['location'] ?? '',
              'latitude': alert['latitude'],
              'longitude': alert['longitude'],
              'location_name': alert['location_name'],
              'robot_id': alert['robot_id'] ?? '',
              'is_read': alert['is_read'] == true ? 1 : 0,
              'is_resolved': alert['is_resolved'] == true ? 1 : 0,
              'resolved_by': alert['resolved_by'],
              'resolved_at': alert['resolved_at'],
              'lens': alert['lens'] ?? '',
              'note': alert['note'] ?? '',
              'threshold': alert['threshold'],
              'created_at_local': alert['created_at_local'],
              'synced_from_firebase': 1,
              'cached_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          debugPrint('   ⚠️ Failed to cache one alert: $e');
          continue;
        }
      }

      debugPrint('✅ BATCH CACHE: ${alerts.length} alerts cached');
      await _updateAlertStats();
    } catch (e) {
      debugPrint('❌ BATCH CACHE ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ QUERY CACHED ALERTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all cached alerts (offline mode)
  Future<List<Map<String, dynamic>>> getCachedAlerts({
    int limit = 100,
    bool onlyUnread = false,
  }) async {
    try {
      final db = await database;
      
      String? where;
      List<dynamic>? whereArgs;

      if (onlyUnread) {
        where = 'is_read = ?';
        whereArgs = [0];
      }

      final alerts = await db.query(
        'alerts',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      debugPrint('📊 LOCAL CACHE: Retrieved ${alerts.length} alerts');
      return alerts;
    } catch (e) {
      debugPrint('❌ GET CACHED ALERTS ERROR: $e');
      return [];
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM alerts WHERE is_read = 0',
      );
      final count = Sqflite.firstIntValue(result) ?? 0;
      return count;
    } catch (e) {
      debugPrint('❌ UNREAD COUNT ERROR: $e');
      return 0;
    }
  }

  /// Get alert by ID
  Future<Map<String, dynamic>?> getAlertById(String alertId) async {
    try {
      final db = await database;
      final result = await db.query(
        'alerts',
        where: 'alert_id = ?',
        whereArgs: [alertId],
        limit: 1,
      );

      if (result.isEmpty) return null;
      return result.first;
    } catch (e) {
      debugPrint('❌ GET ALERT BY ID ERROR: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ UPDATE ALERT STATUS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mark alert as read locally AND in Firebase
  Future<void> markAlertAsRead(String alertId) async {
    try {
      // ✅ Update local cache
      final db = await database;
      await db.update(
        'alerts',
        {'is_read': 1},
        where: 'alert_id = ?',
        whereArgs: [alertId],
      );

      // ✅ Update Firebase
      try {
        await _firestore.collection('alerts').doc(alertId).update({
          'isRead': true,
          'is_read': true,
        });
        debugPrint('✅ Alert marked as read: $alertId');
      } catch (e) {
        debugPrint('⚠️ Firebase update failed (offline): $e');
      }

      await _updateAlertStats();
    } catch (e) {
      debugPrint('❌ MARK AS READ ERROR: $e');
    }
  }

  /// Mark all alerts as read
  Future<void> markAllAlertsAsRead() async {
    try {
      final db = await database;
      
      // ✅ Update local
      await db.update(
        'alerts',
        {'is_read': 1},
        where: 'is_read = ?',
        whereArgs: [0],
      );

      // ✅ Update Firebase
      try {
        final unreadAlerts = await _firestore
            .collection('alerts')
            .where('isRead', isEqualTo: false)
            .get();

        for (final doc in unreadAlerts.docs) {
          await doc.reference.update({'isRead': true});
        }
        debugPrint('✅ All alerts marked as read');
      } catch (e) {
        debugPrint('⚠️ Firebase batch update failed: $e');
      }

      await _updateAlertStats();
    } catch (e) {
      debugPrint('❌ MARK ALL AS READ ERROR: $e');
    }
  }

  /// Resolve alert (mark as resolved)
  Future<void> resolveAlert(String alertId, String resolvedBy) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      // ✅ Update local
      await db.update(
        'alerts',
        {
          'is_resolved': 1,
          'resolved_by': resolvedBy,
          'resolved_at': now,
        },
        where: 'alert_id = ?',
        whereArgs: [alertId],
      );

      // ✅ Update Firebase
      try {
        await _firestore.collection('alerts').doc(alertId).update({
          'isResolved': true,
          'resolvedBy': resolvedBy,
          'resolvedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Alert resolved: $alertId');
      } catch (e) {
        debugPrint('⚠️ Firebase update failed: $e');
      }

      await _updateAlertStats();
    } catch (e) {
      debugPrint('❌ RESOLVE ALERT ERROR: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ STATISTICS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update alert statistics
  Future<void> _updateAlertStats() async {
    try {
      final db = await database;

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM alerts',
      );
      final totalCount = Sqflite.firstIntValue(totalResult) ?? 0;

      final unreadResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM alerts WHERE is_read = 0',
      );
      final unreadCount = Sqflite.firstIntValue(unreadResult) ?? 0;

      final criticalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM alerts WHERE severity = "critical"',
      );
      final criticalCount = Sqflite.firstIntValue(criticalResult) ?? 0;

      // Update or insert stats
      await db.rawInsert('''
        INSERT OR REPLACE INTO alert_stats (id, total_alerts, unread_count, critical_count, last_updated)
        VALUES (1, ?, ?, ?, ?)
      ''', [totalCount, unreadCount, criticalCount, DateTime.now().toIso8601String()]);

      debugPrint('📊 STATS UPDATED:');
      debugPrint('   Total: $totalCount');
      debugPrint('   Unread: $unreadCount');
      debugPrint('   Critical: $criticalCount');
    } catch (e) {
      debugPrint('❌ UPDATE STATS ERROR: $e');
    }
  }

  /// Get statistics
  Future<Map<String, int>> getStats() async {
    try {
      final db = await database;
      final result = await db.query('alert_stats', limit: 1);

      if (result.isEmpty) {
        return {
          'total': 0,
          'unread': 0,
          'critical': 0,
        };
      }

      final stat = result.first;
      return {
        'total': (stat['total_alerts'] as int?) ?? 0,
        'unread': (stat['unread_count'] as int?) ?? 0,
        'critical': (stat['critical_count'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('❌ GET STATS ERROR: $e');
      return {
        'total': 0,
        'unread': 0,
        'critical': 0,
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ MAINTENANCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Delete old cached alerts (older than X days)
  Future<int> deleteOldAlerts(int days) async {
    try {
      final db = await database;
      final cutoff = DateTime.now().subtract(Duration(days: days));

      final count = await db.delete(
        'alerts',
        where: 'timestamp < ?',
        whereArgs: [cutoff.toIso8601String()],
      );

      if (count > 0) {
        debugPrint('🗑️ LOCAL CACHE: Deleted $count old alerts (>$days days)');
        await _updateAlertStats();
      }

      return count;
    } catch (e) {
      debugPrint('❌ DELETE OLD ALERTS ERROR: $e');
      return 0;
    }
  }

  /// Clear all cached alerts
  Future<void> clearAllAlerts() async {
    try {
      final db = await database;
      await db.delete('alerts');
      await db.delete('alert_stats');
      debugPrint('🧹 LOCAL CACHE: All alerts cleared');
    } catch (e) {
      debugPrint('❌ CLEAR ALL ERROR: $e');
    }
  }

  /// Print cache statistics
  Future<void> printStats() async {
    try {
      final stats = await getStats();
      final unread = stats['unread'] ?? 0;
      final total = stats['total'] ?? 0;
      final critical = stats['critical'] ?? 0;

      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('📊 LOCAL CACHE STATISTICS');
      debugPrint('═══════════════════════════════════');
      debugPrint('Total Cached: $total');
      debugPrint('📖 Unread: $unread');
      debugPrint('🔴 Critical: $critical');
      debugPrint('═══════════════════════════════════');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ STATS ERROR: $e');
    }
  }

  /// Close database connection
  Future<void> close() async {
    try {
      final db = _database;
      if (db != null) {
        await db.close();
        _database = null;
        debugPrint('✅ LOCAL CACHE: Closed successfully');
      }
    } catch (e) {
      debugPrint('❌ CLOSE ERROR: $e');
    }
  }
}