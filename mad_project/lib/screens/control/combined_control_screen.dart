// combined_control_screen.dart
// Merged GPS map + robot control buttons
// Styled like geojson_map_view.dart from surveillance app
// Sends commands to Firestore → surveillance app reads them

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/robot_control_service.dart';
import '../../models/alert_model.dart';
import '../../services/alert_service.dart';

class CombinedControlScreen extends StatefulWidget {
  const CombinedControlScreen({super.key});

  @override
  State<CombinedControlScreen> createState() => _CombinedControlScreenState();
}

class _CombinedControlScreenState extends State<CombinedControlScreen> {
  DateTime _lastUserAppCommandAt = DateTime.fromMillisecondsSinceEpoch(0);
  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Polygon> _polygons = {};

  // ── Robot control ─────────────────────────────────────────────────────────
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Navigation state ──────────────────────────────────────────────────────
  bool _patrolActive = false;
  bool _isTurning = false;
  String _statusMessage = 'Connect surveillance app to start';
  String _carStatus = 'CLEAR'; // BLOCKED or CLEAR from Arduino via Firestore
  bool _robotOnline = false;

  // ── GPS tracking ──────────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;
  LatLng? _carPosition;
  static const LatLng _defaultCenter = LatLng(31.4620, 73.1483);

  // ── Alert location markers ────────────────────────────────────────────────
  final AlertService _alertService = AlertService();
  StreamSubscription? _alertSub;
  bool _showAlertMarkers = true;

  // ── Path (loaded from GeoJSON same as surveillance app) ───────────────────
  List<LatLng> _pathCoordinates = [];

  // ── Firestore listener for car status ─────────────────────────────────────
  StreamSubscription? _carStatusSub;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPath();
    _listenCarStatus();
    _listenAlertLocations();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _alertSub?.cancel();
    _carStatusSub?.cancel();
    _robotService.dispose();
    super.dispose();
  }

  // ── Load path from GeoJSON asset ──────────────────────────────────────────
  Future<void> _loadPath() async {
    try {
      final pathJson = await rootBundle.loadString('assets/path/path.geojson');
      final data = jsonDecode(pathJson) as Map<String, dynamic>;

      for (final f in (data['features'] as List)) {
        final geo = f['geometry'] as Map<String, dynamic>;
        if (geo['type'] == 'LineString') {
          for (final c in (geo['coordinates'] as List)) {
            _pathCoordinates.add(
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            );
          }
        }
      }

      // Draw path on map
      if (_pathCoordinates.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('path'),
            points: _pathCoordinates,
            color: Colors.blue,
            width: 4,
          ),
        );

        // Waypoint markers
        for (int i = 0; i < _pathCoordinates.length; i++) {
          _markers.add(
            Marker(
              markerId: MarkerId('wp_$i'),
              position: _pathCoordinates[i],
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
            ),
          );
        }
      }

      // Load boundary
      try {
        final boundJson = await rootBundle.loadString(
          'assets/path/boundaries.geojson',
        );
        final boundData = jsonDecode(boundJson) as Map<String, dynamic>;
        for (final f in (boundData['features'] as List)) {
          final geo = f['geometry'] as Map<String, dynamic>;
          if (geo['type'] == 'Polygon') {
            for (final ring in (geo['coordinates'] as List)) {
              final poly = <LatLng>[];
              for (final c in ring) {
                poly.add(
                  LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
                );
              }
              if (poly.isNotEmpty) {
                _polygons.add(
                  Polygon(
                    polygonId: PolygonId('b${_polygons.length}'),
                    points: poly,
                    fillColor: Colors.green.withOpacity(0.15),
                    strokeColor: Colors.green,
                    strokeWidth: 2,
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'GeoJSON load error: $e';
      });
    }
  }

  // ── Listen to car status updates from surveillance app via Firestore ───────
  // Surveillance app writes its BLE/Arduino status here
  void _listenCarStatus() {
    _carStatusSub = _db
        .collection('car_status')
        .doc('current')
        .snapshots()
        .listen((snap) {
          if (!snap.exists) return;
          final data = snap.data()!;

          setState(() {
            _robotOnline = data['online'] == true;
            _carStatus = data['obstacle_status'] ?? 'CLEAR';

            final lat = (data['latitude'] as num?)?.toDouble();
            final lng = (data['longitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _carPosition = LatLng(lat, lng);
              _updateCarMarker(_carPosition!);
            }

            if (_carStatus == 'BLOCKED') {
  _statusMessage = '⚠️ Obstacle detected — car paused';
} else if (_carStatus == 'CLEAR' && _patrolActive && !_isTurning && !_emergencyLatched) {
  _statusMessage = '🚗 Moving forward';
  final msSinceUserCmd = DateTime.now()
      .difference(_lastUserAppCommandAt).inMilliseconds;
  if (msSinceUserCmd > 3000) {
    _sendCommand('F');
  }
}
          });
        });
  }

  // ── Listen to alert locations ─────────────────────────────────────────────
  void _listenAlertLocations() {
    _alertSub = _alertService.streamAlerts(limit: 50).listen((alerts) {
      if (!mounted) return;
      // Remove old alert markers
      _markers.removeWhere((m) => m.markerId.value.startsWith('alert_'));

      if (_showAlertMarkers) {
        for (final alert in alerts) {
          if (!alert.hasLocation) continue;
          final isUnknown = alert.type == AlertType.unknownFace;
          _markers.add(
            Marker(
              markerId: MarkerId('alert_${alert.id}'),
              position: LatLng(alert.latitude!, alert.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                isUnknown
                    ? BitmapDescriptor.hueViolet
                    : BitmapDescriptor.hueCyan,
              ),
              infoWindow: InfoWindow(
                title: alert.type.displayName,
                snippet: alert.note.isEmpty ? alert.lens : alert.note,
              ),
            ),
          );
        }
      }
      if (mounted) setState(() {});
    });
  }

  void _updateCarMarker(LatLng pos) {
    _markers.removeWhere((m) => m.markerId.value == 'car');
    _markers.add(
      Marker(
        markerId: const MarkerId('car'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: '🚗 Car',
          snippet:
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _requestLocationPermission() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
    } catch (_) {}
  }

  // ── Send command to Firestore (surveillance app reads this) ───────────────
  Future<void> _sendCommand(String cmd) async {
    _lastUserAppCommandAt = DateTime.now();
    try {
      // Write to Firestore — surveillance app polls this
      await _db.collection('ble_commands').add({
        'command': cmd,
        'sent_at': FieldValue.serverTimestamp(),
        'sent_at_client': Timestamp.fromDate(DateTime.now()),
        'executed': false,
        'source': 'user_app',
      });

      debugPrint('[CMD] Sent: $cmd');
    } catch (e) {
      debugPrint('[CMD] Error: $e');
    }
  }

  // ── Patrol control ────────────────────────────────────────────────────────

  Future<void> _startPatrol() async {
    _emergencyLatched = false;
    setState(() {
      _patrolActive = true;
      _statusMessage = '🚗 Moving forward...';
    });
    await _sendCommand('F');
  }

  Future<void> _stopPatrol() async {
    _isTurning = false;
    setState(() {
      _patrolActive = false;
      _statusMessage = '⏹️ Stopped';
    });
    await _sendCommand('S');
  }

  bool _emergencyLatched = false;
  Future<void> _emergencyStop() async {
    _isTurning = false;
    _emergencyLatched = true;
    setState(() {
      _patrolActive = false;
      _statusMessage = '🚨 EMERGENCY STOP';
    });
    await _sendCommand('E');
    await _db.collection('car_status').doc('current').set(
      {'emergency_latched': true},
      SetOptions(merge: true),
    );
    HapticFeedback.heavyImpact();
  }

  Future<void> _manualTurn(String dir) async {
    if (!_patrolActive || _isTurning) return;
    _isTurning = true;

    setState(() {
      _statusMessage = 'Manual ${dir == "L" ? "Left ←" : "Right →"}';
    });

    await _sendCommand(dir);
    await Future.delayed(const Duration(milliseconds: 700));
    await _sendCommand('F');

    _isTurning = false;
    setState(() => _statusMessage = '🚗 Resumed forward');
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Car Control',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        actions: [
          // Toggle alert markers
          IconButton(
            icon: Icon(
              _showAlertMarkers
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: const Color(0xFF8B5CF6),
            ),
            tooltip: 'Toggle alert pins',
            onPressed: () {
              setState(() {
                _showAlertMarkers = !_showAlertMarkers;
                _markers.removeWhere(
                  (m) => m.markerId.value.startsWith('alert_'),
                );
              });
              _listenAlertLocations();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ───────────────────────────────────────────────────────────
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            GoogleMap(
              onMapCreated: (c) => _mapController = c,
              initialCameraPosition: CameraPosition(
                target: _pathCoordinates.isNotEmpty
                    ? _pathCoordinates.first
                    : _defaultCenter,
                zoom: 16,
              ),
              polylines: _polylines,
              polygons: _polygons,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
            ),

          // ── Status bar ────────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Chip(
                        label: _robotOnline ? '🟢 CAR ONLINE' : '⚫ CAR OFFLINE',
                        color: _robotOnline ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: _patrolActive ? '🟢 RUNNING' : '⏸ IDLE',
                        color: _patrolActive ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: _carStatus == 'BLOCKED'
                            ? '🚫 BLOCKED'
                            : '✅ CLEAR',
                        color: _carStatus == 'BLOCKED'
                            ? Colors.red
                            : Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Control panel ─────────────────────────────────────────────────
          Positioned(
            top: 16,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // START
                _RoundButton(
                  icon: Icons.play_arrow,
                  color: Colors.green,
                  tooltip: 'Start',
                  onPressed: !_patrolActive ? _startPatrol : null,
                ),
                const SizedBox(height: 8),

                // STOP
                _RoundButton(
                  icon: Icons.stop,
                  color: Colors.orange,
                  tooltip: 'Stop',
                  onPressed: _patrolActive ? _stopPatrol : null,
                ),
                const SizedBox(height: 8),

                // EMERGENCY STOP
                _RoundButton(
                  icon: Icons.dangerous,
                  color: Colors.red.shade900,
                  tooltip: 'Emergency Stop',
                  onPressed: _emergencyStop,
                  iconColor: Colors.yellow,
                ),
                const SizedBox(height: 16),

                // Manual LEFT
                _RoundButton(
                  icon: Icons.turn_left,
                  color: Colors.teal,
                  tooltip: 'Turn Left',
                  onPressed: _patrolActive ? () => _manualTurn('L') : null,
                  small: true,
                ),
                const SizedBox(height: 8),

                // Manual RIGHT
                _RoundButton(
                  icon: Icons.turn_right,
                  color: Colors.teal,
                  tooltip: 'Turn Right',
                  onPressed: _patrolActive ? () => _manualTurn('R') : null,
                  small: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets (same as geojson_map_view.dart) ──────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool small;
  final Color? iconColor;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.small = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (small) {
      return FloatingActionButton.small(
        heroTag: tooltip,
        onPressed: onPressed,
        backgroundColor: onPressed == null ? Colors.grey.shade800 : color,
        tooltip: tooltip,
        child: Icon(
          icon,
          color: iconColor ?? (onPressed == null ? Colors.grey : Colors.white),
        ),
      );
    }
    return FloatingActionButton(
      heroTag: tooltip,
      onPressed: onPressed,
      backgroundColor: onPressed == null ? Colors.grey.shade800 : color,
      tooltip: tooltip,
      child: Icon(
        icon,
        color: iconColor ?? (onPressed == null ? Colors.grey : Colors.white),
      ),
    );
  }
}
