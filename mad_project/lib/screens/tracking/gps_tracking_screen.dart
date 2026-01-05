import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../widgets/protected_route.dart';

class GPSTrackingScreen extends StatelessWidget {
  const GPSTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if running on web
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF1F2937),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
            ).createShader(bounds),
            child: const Text(
              'GPS Tracking',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
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
                    gradient: LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                    ),
                  ),
                  child: const Icon(
                    Icons.phone_android_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'GPS Tracking',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'GPS tracking is only available on mobile devices.\nPlease use the mobile app for this feature.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
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

class _GPSTrackingContent extends StatefulWidget {
  const _GPSTrackingContent();

  @override
  State<_GPSTrackingContent> createState() => _GPSTrackingContentState();
}

class _GPSTrackingContentState extends State<_GPSTrackingContent> {
  GoogleMapController? _mapController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Set<Marker> _markers = {};
  final Map<String, RobotLocation> _robots = {};

  Timer? _locationTimer;
  StreamSubscription<QuerySnapshot>? _locationSubscription;

  bool _isSendingLocation = false;
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _selectedRobotId;
  String? _errorMessage;

  final LatLng _initialPosition = const LatLng(31.4504, 73.1350);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // Check permissions first
      await _checkPermissions();

      // Start listening to locations
      _startListeningToLocations();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Initialization error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize GPS tracking: $e';
      });
    }
  }

  Future<void> _checkPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

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

      setState(() {
        _hasPermission = true;
      });
    } catch (e) {
      debugPrint('Permission error: $e');
      setState(() {
        _hasPermission = false;
        _errorMessage = e.toString();
      });
      rethrow;
    }
  }

  Future<void> _startSendingLocation() async {
    if (!_hasPermission) {
      await _checkPermissions();
    }

    setState(() => _isSendingLocation = true);

    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        await _db.collection('device_locations').doc('current_device').set({
          'device_id': 'current_device',
          'lat': position.latitude,
          'lng': position.longitude,
          'battery': 85,
          'status': 'active',
          'updated_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showSuccess(
            'Location sent: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          );
        }
      } catch (e) {
        debugPrint('Error sending location: $e');
        if (mounted) {
          _showError('Failed to send location: $e');
        }
      }
    });

    _showSuccess('Started sending location every 5 seconds');
  }

  void _stopSendingLocation() {
    _locationTimer?.cancel();
    setState(() => _isSendingLocation = false);
    _showSuccess('Stopped sending location');
  }

  void _startListeningToLocations() {
    _locationSubscription = _db
        .collection('device_locations')
        .snapshots()
        .listen(
          (snapshot) {
            setState(() {
              _robots.clear();
              _markers.clear();

              for (var doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  final deviceId = data['device_id'] ?? doc.id;
                  final lat = (data['lat'] ?? 0).toDouble();
                  final lng = (data['lng'] ?? 0).toDouble();
                  final battery = (data['battery'] ?? 0).toInt();
                  final status = data['status'] ?? 'inactive';

                  if (lat == 0 && lng == 0) continue;

                  final robot = RobotLocation(
                    id: deviceId,
                    name: _getDeviceName(deviceId),
                    position: LatLng(lat, lng),
                    status: _parseStatus(status),
                    battery: battery,
                  );

                  _robots[deviceId] = robot;

                  _markers.add(
                    Marker(
                      markerId: MarkerId(deviceId),
                      position: LatLng(lat, lng),
                      infoWindow: InfoWindow(
                        title: robot.name,
                        snippet: '${robot.status.name} - $battery%',
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        robot.status == RobotStatus.active
                            ? BitmapDescriptor.hueGreen
                            : robot.status == RobotStatus.charging
                            ? BitmapDescriptor.hueYellow
                            : BitmapDescriptor.hueRed,
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('Error processing location doc: $e');
                }
              }
            });
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to load locations: $error';
              });
            }
          },
        );
  }

  String _getDeviceName(String deviceId) {
    if (deviceId == 'current_device') return 'My Device';
    if (deviceId.startsWith('robot')) {
      return 'Robot ${deviceId.replaceAll('robot', '')}';
    }
    return deviceId;
  }

  RobotStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return RobotStatus.active;
      case 'charging':
        return RobotStatus.charging;
      default:
        return RobotStatus.inactive;
    }
  }

  void _focusOnRobot(RobotLocation robot) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: robot.position, zoom: 16),
      ),
    );
    setState(() => _selectedRobotId = robot.id);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF06B6D4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
        elevation: 8,
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEC4899),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initializing GPS...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && !_hasPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF1F2937),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
            ).createShader(bounds),
            child: const Text(
              'GPS Tracking',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    size: 80,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Location Access Required',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Unable to access location',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1F2937),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'GPS Tracking',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        actions: [
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
                onPressed: () {
                  if (_isSendingLocation) {
                    _stopSendingLocation();
                  } else {
                    _startSendingLocation();
                  }
                },
                tooltip: _isSendingLocation ? 'Stop Sending' : 'Start Sending',
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 13,
            ),
            markers: _markers,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Status Banner
          if (_isSendingLocation)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sending location every 5 seconds',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Device List
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.25,
                ),
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
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
                            ).createShader(bounds),
                            child: const Text(
                              'Tracked Devices',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_robots.values.where((r) => r.status == RobotStatus.active).length}/${_robots.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: _robots.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_off_rounded,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No devices tracked yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: _robots.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final robot = _robots.values.elementAt(index);
                                return _buildRobotCard(robot);
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRobotCard(RobotLocation robot) {
    Color statusColor;
    IconData statusIcon;

    switch (robot.status) {
      case RobotStatus.active:
        statusColor = const Color(0xFF4ECDC4);
        statusIcon = Icons.check_circle_rounded;
        break;
      case RobotStatus.charging:
        statusColor = const Color(0xFFFF9800);
        statusIcon = Icons.battery_charging_full_rounded;
        break;
      case RobotStatus.inactive:
        statusColor = const Color(0xFFFF6B6B);
        statusIcon = Icons.cancel_rounded;
        break;
    }

    final isSelected = _selectedRobotId == robot.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _focusOnRobot(robot),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 140,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.2),
                      statusColor.withOpacity(0.1),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      statusColor.withOpacity(0.1),
                      statusColor.withOpacity(0.05),
                    ],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: statusColor.withOpacity(isSelected ? 0.5 : 0.3),
              width: isSelected ? 2.5 : 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      robot.id == 'current_device'
                          ? Icons.phone_android_rounded
                          : Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      robot.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      robot.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.battery_std_rounded,
                    color: robot.battery < 20
                        ? const Color(0xFFFF6B6B)
                        : Colors.grey.shade600,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${robot.battery}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RobotLocation {
  final String id;
  final String name;
  final LatLng position;
  final RobotStatus status;
  final int battery;

  RobotLocation({
    required this.id,
    required this.name,
    required this.position,
    required this.status,
    required this.battery,
  });
}

enum RobotStatus { active, charging, inactive }
