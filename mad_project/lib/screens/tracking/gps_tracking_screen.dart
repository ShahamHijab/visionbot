// lib/screens/tracking/gps_tracking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GPSTrackingScreen extends StatefulWidget {
  const GPSTrackingScreen({super.key});

  @override
  State<GPSTrackingScreen> createState() => _GPSTrackingScreenState();
}

class _GPSTrackingScreenState extends State<GPSTrackingScreen> {
  GoogleMapController? _mapController;
  
  final LatLng _initialPosition = const LatLng(31.4504, 73.1350); // Faisalabad
  
  final Set<Marker> _markers = {};
  final List<RobotLocation> _robots = [
    RobotLocation(
      id: 'robot_1',
      name: 'Robot 1',
      position: const LatLng(31.4504, 73.1350),
      status: RobotStatus.active,
      battery: 85,
    ),
    RobotLocation(
      id: 'robot_2',
      name: 'Robot 2',
      position: const LatLng(31.4520, 73.1360),
      status: RobotStatus.active,
      battery: 92,
    ),
    RobotLocation(
      id: 'robot_3',
      name: 'Robot 3',
      position: const LatLng(31.4490, 73.1340),
      status: RobotStatus.charging,
      battery: 45,
    ),
    RobotLocation(
      id: 'robot_4',
      name: 'Robot 4',
      position: const LatLng(31.4510, 73.1370),
      status: RobotStatus.inactive,
      battery: 12,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _createMarkers();
  }

  void _createMarkers() {
    for (var robot in _robots) {
      _markers.add(
        Marker(
          markerId: MarkerId(robot.id),
          position: robot.position,
          infoWindow: InfoWindow(
            title: robot.name,
            snippet: '${robot.status.name} - ${robot.battery}%',
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
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _focusOnRobot(RobotLocation robot) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: robot.position,
          zoom: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
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
      body: Stack(
        children: [
          // Map
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 13,
            ),
            markers: _markers,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          
          // Robot List
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 200,
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
                            'Active Robots',
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
                            '${_robots.where((r) => r.status == RobotStatus.active).length}/${_robots.length}',
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
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _robots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _buildRobotCard(_robots[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _focusOnRobot(robot),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(0.1),
                statusColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      robot.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    robot.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.battery_std_rounded,
                    color: robot.battery < 20
                        ? const Color(0xFFFF6B6B)
                        : Colors.grey.shade600,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${robot.battery}%',
                    style: TextStyle(
                      fontSize: 13,
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

enum RobotStatus {
  active,
  charging,
  inactive,
}