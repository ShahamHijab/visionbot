import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/alert_model.dart';
import '../../services/alert_service.dart';
import '../../widgets/protected_route.dart';
import '../../services/permission_service.dart';

class GPSTrackingScreen extends StatelessWidget {
  const GPSTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: _simpleAppBar('GPS Tracking'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _gradientCircleIcon(Icons.phone_android_rounded, 64),
              const SizedBox(height: 32),
              const Text(
                'GPS Tracking',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'GPS tracking is only available on mobile devices.\n'
                  'Please use the mobile app for this feature.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const ProtectedRoute(
      permissionKey: 'gps_tracking',
      accessDeniedMessage: 'Only administrators can access GPS tracking.',
      child: _GPSTrackingContent(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main tracking content
// ─────────────────────────────────────────────────────────────────────────────
class _GPSTrackingContent extends StatefulWidget {
  const _GPSTrackingContent();

  @override
  State<_GPSTrackingContent> createState() => _GPSTrackingContentState();
}

class _GPSTrackingContentState extends State<_GPSTrackingContent>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PermissionService _permissionService = PermissionService();
  final AlertService _alertService = AlertService();

  final Set<Marker> _markers = {};
  final Map<String, DeviceLocation> _devices = {};

  // Alert-location markers (unknown / known persons from VisionBot)
  final Map<String, AlertModel> _alertLocations = {};

  Timer? _locationSendTimer;
  StreamSubscription<QuerySnapshot>? _locationSubscription;
  StreamSubscription<List<AlertModel>>? _alertSubscription;

  bool _isSendingLocation = false;
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _canViewOtherLocations = false;
  String? _selectedDeviceId;
  String? _selectedAlertId;
  String? _errorMessage;
  String? _currentUserName;

  // Tab: 0 = shared users, 1 = alert locations
  int _bottomTab = 0;

  // Toggle alert markers on/off
  bool _showAlertMarkers = true;

  final LatLng _initialPosition = const LatLng(31.4504, 73.1350);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _locationSendTimer?.cancel();
    _locationSubscription?.cancel();
    _alertSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _checkPermissions();
      await _checkViewPermission();
      await _getCurrentUserName();

      if (_canViewOtherLocations) {
        _startListeningToLocations();
      }
      _startListeningToAlertLocations();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize GPS tracking: $e';
      });
    }
  }

  Future<void> _checkPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      setState(() => _hasPermission = true);
    } catch (e) {
      setState(() {
        _hasPermission = false;
        _errorMessage = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _checkViewPermission() async {
    try {
      final canView = await _permissionService.hasPermission('gps_tracking');
      setState(() => _canViewOtherLocations = canView);
    } catch (_) {
      setState(() => _canViewOtherLocations = false);
    }
  }

  Future<void> _getCurrentUserName() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        setState(() =>
            _currentUserName = user.displayName ?? user.email ?? 'Unknown User');
      }
    } catch (_) {}
  }

  // ── Shared user locations ─────────────────────────────────────────────────
  void _startListeningToLocations() {
    _locationSubscription =
        _db.collection('shared_locations').snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _devices.clear();
          _rebuildMarkers();

          final currentUserId = _auth.currentUser?.uid;

          for (var doc in snapshot.docs) {
            try {
              final data = doc.data();
              final userId    = data['user_id'] ?? doc.id;
              final deviceName = data['device_name'] ?? 'Unknown Device';
              final email     = data['email'] ?? 'unknown@email.com';
              final lat       = (data['latitude'] ?? 0).toDouble();
              final lng       = (data['longitude'] ?? 0).toDouble();
              final battery   = (data['battery'] ?? 0).toInt();
              final status    = data['status'] ?? 'inactive';

              if (lat == 0 && lng == 0) continue;
              if (userId == currentUserId) continue;

              final device = DeviceLocation(
                userId: userId,
                deviceName: deviceName,
                email: email,
                position: LatLng(lat, lng),
                status: _parseStatus(status),
                battery: battery,
              );
              _devices[userId] = device;
            } catch (_) {}
          }
          _rebuildMarkers();
        });
      },
      onError: (error) {
        if (mounted) setState(() => _errorMessage = 'Failed to load locations');
      },
    );
  }

  // ── Alert locations (VisionBot unknown/known persons) ─────────────────────
  void _startListeningToAlertLocations() {
    _alertSubscription = _alertService
        .streamAlerts(limit: 50, collection: 'alerts', orderField: 'created_at')
        .listen(
      (alerts) {
        if (!mounted) return;
        setState(() {
          _alertLocations.clear();
          for (final alert in alerts) {
            if (alert.hasLocation) {
              _alertLocations[alert.id] = alert;
            }
          }
          _rebuildMarkers();
        });
      },
    );
  }

  void _rebuildMarkers() {
    _markers.clear();

    // User device markers (green/yellow/red)
    for (final device in _devices.values) {
      Color statusColor;
      double hue;
      switch (device.status) {
        case DeviceStatus.active:
          hue = BitmapDescriptor.hueGreen;
          break;
        case DeviceStatus.charging:
          hue = BitmapDescriptor.hueYellow;
          break;
        case DeviceStatus.inactive:
          hue = BitmapDescriptor.hueRed;
          break;
      }

      _markers.add(
        Marker(
          markerId: MarkerId('device_${device.userId}'),
          position: device.position,
          infoWindow: InfoWindow(
            title: device.deviceName,
            snippet: '${device.status.name} · ${device.battery}% · ${device.email}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        ),
      );
    }

    // Alert location markers (violet = unknown, cyan = known)
    if (_showAlertMarkers) {
      for (final alert in _alertLocations.values) {
        final isUnknown = alert.type == AlertType.unknownFace;
        final hue = isUnknown
            ? BitmapDescriptor.hueViolet
            : BitmapDescriptor.hueCyan;

        final coordLabel =
            '${alert.latitude!.toStringAsFixed(4)}, ${alert.longitude!.toStringAsFixed(4)}';

        _markers.add(
          Marker(
            markerId: MarkerId('alert_${alert.id}'),
            position: LatLng(alert.latitude!, alert.longitude!),
            infoWindow: InfoWindow(
              title: alert.type.displayName,
              snippet: '${alert.note.isEmpty ? alert.lens : alert.note} · $coordLabel',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            onTap: () => setState(() => _selectedAlertId = alert.id),
          ),
        );
      }
    }
  }

  // ── Sending own location ──────────────────────────────────────────────────
  Future<void> _startSendingLocation() async {
    if (!_hasPermission) await _checkPermissions();
    setState(() => _isSendingLocation = true);

    _locationSendTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        final user = _auth.currentUser;
        if (user == null) return;

        await _db.collection('shared_locations').doc(user.uid).set({
          'user_id': user.uid,
          'device_name': _currentUserName ?? 'My Device',
          'email': user.email,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'battery': 85,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _showSuccess(
          'Location sent: ${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}',
        );
      } catch (e) {
        if (mounted) _showError('Failed to send location');
      }
    });
    _showSuccess('Started sending location every 5 seconds');
  }

  void _stopSendingLocation() {
    _locationSendTimer?.cancel();
    setState(() => _isSendingLocation = false);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _db.collection('shared_locations').doc(user.uid).delete();
      }
    } catch (_) {}
    _showSuccess('Stopped sending location');
  }

  DeviceStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':   return DeviceStatus.active;
      case 'charging': return DeviceStatus.charging;
      default:         return DeviceStatus.inactive;
    }
  }

  void _focusOnDevice(DeviceLocation device) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: device.position, zoom: 16),
      ),
    );
    setState(() {
      _selectedDeviceId = device.userId;
      _selectedAlertId  = null;
    });
  }

  void _focusOnAlert(AlertModel alert) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(alert.latitude!, alert.longitude!),
          zoom: 16,
        ),
      ),
    );
    setState(() {
      _selectedAlertId  = alert.id;
      _selectedDeviceId = null;
    });
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF06B6D4),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEC4899),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(20),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Initializing GPS...',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && !_hasPermission) {
      return Scaffold(
        appBar: _simpleAppBar('GPS Tracking'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off_rounded,
                    size: 80, color: Color(0xFFFF6B6B)),
                const SizedBox(height: 24),
                const Text('Location Access Required',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                Text(_errorMessage ?? 'Unable to access location',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Geolocator.openLocationSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final alertsWithLoc = _alertLocations.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: _backButton(),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text('GPS Tracking',
              style:
                  TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        actions: [
          // Toggle alert markers
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: _showAlertMarkers ? 'Hide alert pins' : 'Show alert pins',
              icon: Icon(
                _showAlertMarkers
                    ? Icons.location_on_rounded
                    : Icons.location_off_rounded,
                color: const Color(0xFF8B5CF6),
              ),
              onPressed: () {
                setState(() {
                  _showAlertMarkers = !_showAlertMarkers;
                  _rebuildMarkers();
                });
              },
            ),
          ),
          // Start / stop sharing
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isSendingLocation
                      ? const [Color(0xFFFF6B6B), Color(0xFFEC4899)]
                      : const [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  _isSendingLocation
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: _isSendingLocation
                    ? _stopSendingLocation
                    : _startSendingLocation,
                tooltip: _isSendingLocation ? 'Stop Sending' : 'Start Sending',
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────────
          GoogleMap(
            onMapCreated: (c) => _mapController = c,
            initialCameraPosition:
                CameraPosition(target: _initialPosition, zoom: 13),
            markers: _markers,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // ── Sending banner ─────────────────────────────────────────────
          if (_isSendingLocation)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF06B6D4).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  const Text('Sending your location every 5 seconds',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ]),
              ),
            ),

          // ── Legend ────────────────────────────────────────────────────
          Positioned(
            top: _isSendingLocation ? 76 : 16,
            right: 20,
            child: _legend(),
          ),

          // ── Bottom panel ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.34),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 12),

                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _tabChip(0, 'Shared Users',
                            Icons.people_alt_rounded, _devices.length),
                        const SizedBox(width: 10),
                        _tabChip(1, 'Alert Pins',
                            Icons.location_on_rounded, alertsWithLoc.length),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tab content
                  SizedBox(
                    height: 130,
                    child: _bottomTab == 0
                        ? _devicesRow()
                        : _alertLocationsRow(alertsWithLoc),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Legend widget ─────────────────────────────────────────────────────────
  Widget _legend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.93),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _legendRow(const Color(0xFF4ECDC4), 'Active user'),
          _legendRow(const Color(0xFFF59E0B), 'Charging'),
          _legendRow(const Color(0xFFFF6B6B), 'Inactive'),
          _legendRow(const Color(0xFF8B5CF6), 'Unknown person'),
          _legendRow(const Color(0xFF06B6D4), 'Known person'),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Tab chip ─────────────────────────────────────────────────────────────
  Widget _tabChip(int idx, String label, IconData icon, int count) {
    final isSelected = _bottomTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _bottomTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)])
              : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey.shade600)),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            isSelected ? Colors.white : Colors.grey.shade700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Devices horizontal list ───────────────────────────────────────────────
  Widget _devicesRow() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No shared locations yet',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => _buildDeviceCard(_devices.values.elementAt(i)),
    );
  }

  // ── Alert locations horizontal list ───────────────────────────────────────
  Widget _alertLocationsRow(List<AlertModel> alerts) {
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('No alert locations available',
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      scrollDirection: Axis.horizontal,
      itemCount: alerts.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) => _buildAlertLocationCard(alerts[i]),
    );
  }

  // ── Device card ───────────────────────────────────────────────────────────
  Widget _buildDeviceCard(DeviceLocation device) {
    Color statusColor;
    IconData statusIcon;
    switch (device.status) {
      case DeviceStatus.active:
        statusColor = const Color(0xFF4ECDC4);
        statusIcon  = Icons.check_circle_rounded;
        break;
      case DeviceStatus.charging:
        statusColor = const Color(0xFFFF9800);
        statusIcon  = Icons.battery_charging_full_rounded;
        break;
      case DeviceStatus.inactive:
        statusColor = const Color(0xFFFF6B6B);
        statusIcon  = Icons.cancel_rounded;
        break;
    }

    final isSelected = _selectedDeviceId == device.userId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _focusOnDevice(device),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? statusColor.withOpacity(0.15)
                : statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: statusColor.withOpacity(isSelected ? 0.6 : 0.3),
                width: isSelected ? 2.5 : 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.phone_android_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(device.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(device.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(statusIcon, color: statusColor, size: 13),
                const SizedBox(width: 4),
                Text(device.status.name.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(
                  Icons.battery_std_rounded,
                  color: device.battery < 20
                      ? const Color(0xFFFF6B6B)
                      : Colors.grey.shade600,
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text('${device.battery}%',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Alert location card ───────────────────────────────────────────────────
  Widget _buildAlertLocationCard(AlertModel alert) {
    final isUnknown = alert.type == AlertType.unknownFace;
    final cardColor = isUnknown
        ? const Color(0xFF8B5CF6)
        : const Color(0xFF06B6D4);
    final isSelected = _selectedAlertId == alert.id;

    final lat = alert.latitude!.toStringAsFixed(4);
    final lng = alert.longitude!.toStringAsFixed(4);
    final coordLabel = '$lat, $lng';

    // Relative time
    final diff = DateTime.now().difference(alert.createdAt);
    String timeText;
    if (diff.inMinutes < 1) {
      timeText = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeText = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeText = '${diff.inHours}h ago';
    } else {
      timeText = '${diff.inDays}d ago';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _focusOnAlert(alert),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 155,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? cardColor.withOpacity(0.15)
                : cardColor.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: cardColor.withOpacity(isSelected ? 0.6 : 0.3),
                width: isSelected ? 2.5 : 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                    isUnknown
                        ? Icons.person_off_rounded
                        : Icons.person_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alert.type.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
              const SizedBox(height: 8),

              // Coordinates
              Row(children: [
                Icon(Icons.location_on_rounded, size: 12, color: cardColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    coordLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cardColor),
                  ),
                ),
              ]),
              const SizedBox(height: 4),

              // Note / lens
              Text(
                alert.note.isNotEmpty
                    ? alert.note
                    : 'Lens: ${alert.lens.isEmpty ? 'N/A' : alert.lens}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),

              // Time
              Text(timeText,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small helpers ─────────────────────────────────────────────────────────
  Widget _backButton() => Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2))
          ],
        ),
        child: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF1F2937)),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers used by both desktop and mobile fallback
// ─────────────────────────────────────────────────────────────────────────────
PreferredSizeWidget _simpleAppBar(String title) {
  return AppBar(
    elevation: 0,
    backgroundColor: Colors.white,
    title: ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
      ).createShader(bounds),
      child: Text(title,
          style:
              const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
    ),
  );
}

Widget _gradientCircleIcon(IconData icon, double size) {
  return Container(
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [
          const Color(0xFF06B6D4).withOpacity(0.1),
          const Color(0xFF8B5CF6).withOpacity(0.1),
        ],
      ),
    ),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)]),
      ),
      child: Icon(icon, size: size, color: Colors.white),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────
class DeviceLocation {
  final String userId;
  final String deviceName;
  final String email;
  final LatLng position;
  final DeviceStatus status;
  final int battery;

  DeviceLocation({
    required this.userId,
    required this.deviceName,
    required this.email,
    required this.position,
    required this.status,
    required this.battery,
  });
}

enum DeviceStatus { active, charging, inactive }