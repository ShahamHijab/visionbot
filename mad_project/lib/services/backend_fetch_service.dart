import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../models/alert_model.dart';
import 'database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendFetchService {
  
  static final String LAPTOP_URL = dotenv.env['LAPTOP_SERVER_URL'] ?? '';

  static const String _collection = 'alerts';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late DatabaseService _localDb;
  
  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isInitialized = false;

  /// ✅ Initialize service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ Backend already initialized');
      return;
    }

    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════');
      debugPrint('🔧 Backend Fetch Service Initializing');
      debugPrint('═══════════════════════════════════');

      // ✅ Validate LAPTOP_URL
      if (LAPTOP_URL.isEmpty) {
        debugPrint('⚠️ WARNING: LAPTOP_SERVER_URL not set in .env');
        debugPrint('   Set it to: http://192.168.1.50:3000');
      } else {
        debugPrint('💻 Laptop Server: $LAPTOP_URL');
      }

      _localDb = DatabaseService();
      await _localDb.database;
      debugPrint('✅ Local DB initialized');

      // Test Firebase connection
      try {
        await _firestore
            .collection(_collection)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 5));

        debugPrint('✅ Firebase connection OK');
      } catch (e) {
        debugPrint('⚠️ Firebase offline: $e');
      }

      // Test Laptop connection
      if (LAPTOP_URL.isNotEmpty) {
        try {
          final response = await http
              .get(Uri.parse('$LAPTOP_URL/health'))
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            debugPrint('✅ Laptop server reachable: $LAPTOP_URL');
          } else {
            debugPrint('⚠️ Laptop responded but status: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('⚠️ Laptop server offline: $e');
          debugPrint('   Make sure: node server.js is running on laptop');
        }
      }

      // Start background sync from laptop
      _startBackgroundSync();

      _isInitialized = true;

      debugPrint('═══════════════════════════════════');
      debugPrint('');
    } catch (e, st) {
      debugPrint('❌ Backend init error: $e');
      debugPrint('   Stack: $st');
    }
  }

  /// ✅ Start background sync from laptop server
  void _startBackgroundSync() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await _syncFromLaptop();
    });

    debugPrint('📡 Background sync started (every 20s from laptop)');
  }

  /// ✅ Sync alerts from laptop to local cache
  Future<void> _syncFromLaptop() async {
    if (_isSyncing) return;
    if (LAPTOP_URL.isEmpty) return;

    _isSyncing = true;

    try {
      final response = await http
          .get(Uri.parse('$LAPTOP_URL/api/phone/alerts'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final alertsList = (data['alerts'] as List?) ?? [];

        if (alertsList.isNotEmpty) {
          debugPrint('');
          debugPrint('🔄 BACKGROUND SYNC: Got ${alertsList.length} alerts from laptop');

          // ✅ FIX: Use cacheAlertLocally instead
          int cached = 0;
          for (final alertData in alertsList) {
            try {
              final alert =
                  AlertModel.fromJson(Map<String, dynamic>.from(alertData));

              // Check if already cached
              final existing = await _localDb.getCachedAlerts(limit: 999);
              final isNew = !existing.any((a) => a['alert_id'] == alert.id);

              if (isNew) {
                // ✅ FIX: Use cacheAlertLocally
                await _localDb.cacheAlertLocally({
                  'alert_id': alert.id,
                  'type': alert.type.toString(),
                  'created_at_local': alert.timestamp.toIso8601String(),
                  'severity': alert.severity.toString(),
                  'title': alert.title,
                  'description': alert.description,
                  'image_url': alert.imageUrl,
                  'face_image_urls': alert.faceImageUrls,
                  'latitude': alert.latitude,
                  'longitude': alert.longitude,
                  'location_name': alert.locationName,
                  'lens': '',
                  'threshold': alert.threshold,
                  'timestamp': alert.timestamp.toIso8601String(),
                });
                cached++;
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing alert: $e');
            }
          }

          if (cached > 0) {
            debugPrint('   ✅ Cached $cached NEW alerts locally');
          }

          debugPrint('');
        }
      }
    } catch (e) {
      // Silent fail - normal when offline
      debugPrint('   ⚠️ Laptop sync failed (probably offline): $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// ✅ Check if internet available
  Future<bool> _hasInternet() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// ✅ Get alerts HYBRID: Firebase → Laptop → Local Cache
  Future<List<AlertModel>> getAlerts({int limit = 100}) async {
    try {
      debugPrint('');
      debugPrint('📡 HYBRID FETCH: Trying sources...');

      final hasInternet = await _hasInternet();
      debugPrint('   🌐 Internet: ${hasInternet ? "✅ YES" : "❌ NO"}');

      // ✅ PRIMARY: Firebase (if online)
      if (hasInternet) {
        try {
          debugPrint('   🌐 Trying Firebase...');
          final snapshot = await _firestore
              .collection(_collection)
              .orderBy('created_at', descending: true)
              .limit(limit)
              .get()
              .timeout(const Duration(seconds: 10));

          if (snapshot.docs.isNotEmpty) {
            final alerts = snapshot.docs
                .map((doc) => AlertModel.fromFirestore(doc))
                .toList();

            debugPrint('   ✅ Got ${alerts.length} alerts from Firebase');

            // ✅ Cache them locally
            await _cacheAlertsLocally(alerts);

            return alerts;
          }

          debugPrint('   ⚠️ Firebase returned 0 alerts');
        } catch (e) {
          debugPrint('   ❌ Firebase failed: $e');
        }

        // ✅ BACKUP: Laptop Server (if Firebase fails and online)
        if (LAPTOP_URL.isNotEmpty) {
          try {
            debugPrint('   💻 Trying Laptop Server...');
            final response = await http
                .get(Uri.parse('$LAPTOP_URL/api/phone/alerts'))
                .timeout(const Duration(seconds: 10));

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final alertsList = (data['alerts'] as List?) ?? [];

              if (alertsList.isNotEmpty) {
                final alerts = alertsList
                    .take(limit)
                    .map((e) =>
                        AlertModel.fromJson(Map<String, dynamic>.from(e)))
                    .toList();

                debugPrint('   ✅ Got ${alerts.length} alerts from Laptop');

                // ✅ Cache them locally
                await _cacheAlertsLocally(alerts);

                return alerts;
              }

              debugPrint('   ⚠️ Laptop returned 0 alerts');
            }
          } catch (e) {
            debugPrint('   ❌ Laptop failed: $e');
          }
        }
      }

      // ✅ FALLBACK: Local Cache (offline or all online sources failed)
      debugPrint('   💾 Trying Local Cache...');
      final cachedAlerts = await _getLocalAlerts();

      if (cachedAlerts.isNotEmpty) {
        debugPrint('   ✅ Got ${cachedAlerts.length} alerts from Local Cache');
        return cachedAlerts;
      }

      debugPrint('   ❌ No alerts from any source');
      return [];
    } catch (e, st) {
      debugPrint('❌ Hybrid fetch error: $e');
      debugPrint('   Stack: $st');
      return [];
    }
  }

  /// ✅ Cache alerts locally
  Future<void> _cacheAlertsLocally(List<AlertModel> alerts) async {
    try {
      // ✅ FIX: Use batchCacheAlerts instead
      await _localDb.batchCacheAlerts(
        alerts
            .map((alert) => {
                  'alert_id': alert.id,
                  'type': alert.type.toString(),
                  'created_at_local': alert.timestamp.toIso8601String(),
                  'severity': alert.severity.toString(),
                  'title': alert.title,
                  'description': alert.description,
                  'image_url': alert.imageUrl,
                  'face_image_urls': alert.faceImageUrls,
                  'latitude': alert.latitude,
                  'longitude': alert.longitude,
                  'location_name': alert.locationName,
                  'lens': '',
                  'threshold': alert.threshold,
                  'timestamp': alert.timestamp.toIso8601String(),
                })
            .toList(),
      );
      debugPrint('   ✅ Cached ${alerts.length} alerts locally');
    } catch (e) {
      debugPrint('   ⚠️ Caching error: $e');
    }
  }

  /// ✅ Get alerts from local cache
  Future<List<AlertModel>> _getLocalAlerts() async {
    try {
      // ✅ FIX: Use getCachedAlerts instead
      final localAlerts = await _localDb.getCachedAlerts(limit: 100);

      return localAlerts
          .map((data) {
            try {
              return AlertModel(
                id: data['alert_id'] ?? '',
                type: _parseAlertType(data['type'] ?? ''),
                severity: _parseAlertSeverity(data['severity'] ?? ''),
                title: data['title'] ?? '',
                description: data['description'] ?? '',
                imageUrl: data['image_url'] ?? '',
                faceImageUrls: _parseFaceImageUrls(data['face_image_urls']),
                timestamp: DateTime.tryParse(data['timestamp'] ?? '') ??
                    DateTime.now(),
                location: data['location'] ?? '',
                latitude: (data['latitude'] as num?)?.toDouble(),
                longitude: (data['longitude'] as num?)?.toDouble(),
                locationName: data['location_name'],
                robotId: data['robot_id'] ?? '',
                isRead: (data['is_read'] as int?) == 1,
                isResolved: (data['is_resolved'] as int?) == 1,
                lens: data['lens'] ?? '',
                note: data['note'] ?? '',
                threshold: (data['threshold'] as num?)?.toDouble(),
                createdAtLocal: DateTime.tryParse(data['created_at_local'] ?? ''),
              );
            } catch (e) {
              debugPrint('⚠️ Error parsing local alert: $e');
              return null;
            }
          })
          .whereType<AlertModel>()
          .toList();
    } catch (e) {
      debugPrint('❌ Local fetch error: $e');
      return [];
    }
  }

  /// ✅ NEW: Helper to parse face image URLs
  List<String> _parseFaceImageUrls(dynamic value) {
    if (value is String) {
      return value.split('|').where((s) => s.isNotEmpty).toList();
    }
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// ✅ Helper: Parse alert type
  AlertType _parseAlertType(String type) {
    final t = type.toLowerCase();
    if (t.contains('unknown')) return AlertType.unknownFace;
    if (t.contains('known')) return AlertType.knownFace;
    if (t.contains('group')) return AlertType.group;
    if (t.contains('smoke')) return AlertType.smoke;
    if (t.contains('fire')) return AlertType.fire;
    if (t.contains('intruder')) return AlertType.intruder;
    return AlertType.other;
  }

  /// ✅ Helper: Parse alert severity
  AlertSeverity _parseAlertSeverity(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('critical')) return AlertSeverity.critical;
    if (s.contains('warning')) return AlertSeverity.warning;
    return AlertSeverity.info;
  }

  /// ✅ Stream alerts from Firebase (with fallback to cache)
  Stream<List<AlertModel>> streamAlerts({int limit = 100}) {
    debugPrint('📡 Setting up stream (Firebase → Cache)...');

    return _firestore
        .collection(_collection)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map<Future<List<AlertModel>>>((snapshot) async {
          try {
            final alerts = snapshot.docs
                .map((doc) {
                  try {
                    return AlertModel.fromFirestore(doc);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<AlertModel>()
                .toList();

            // ✅ Cache them
            if (alerts.isNotEmpty) {
              await _cacheAlertsLocally(alerts);
            }

            return alerts;
          } catch (e) {
            debugPrint('⚠️ Stream error: $e, using cache');
            return await _getLocalAlerts();
          }
        })
        .asyncExpand((future) => future.asStream())
        .handleError((error) async {
          debugPrint('⚠️ Firebase stream error: $error, using cache');
          return await _getLocalAlerts();
        });
  }

  /// ✅ Dispose - stop background sync
  void dispose() {
    _syncTimer?.cancel();
    debugPrint('🧹 Backend Fetch Service disposed');
  }
}