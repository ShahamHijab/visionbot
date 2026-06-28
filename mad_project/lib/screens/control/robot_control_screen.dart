import 'package:mad_project/widgets/visionbot_app_bar.dart';
// mad_project/lib/screens/control/robot_control_screen.dart
// ✅ Robot Control UI — sends commands to detectapp via Firebase

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../services/robot_control_service.dart';
import '../../widgets/visionbot_app_bar.dart';

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  State<RobotControlScreen> createState() => _RobotControlScreenState();
}

class _RobotControlScreenState extends State<RobotControlScreen>
    with SingleTickerProviderStateMixin {
  final RobotControlService _service = RobotControlService();

  RobotStatus _status = RobotStatus.offline();
  int _speed = 60;
  bool _isManualMode = false;
  RobotDirection? _activeDir;
  RobotCamera _selectedCamera = RobotCamera.front;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  final List<BluetoothDiscoveryResult> _devices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _btConnection;
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  StreamSubscription<BluetoothState>? _stateSubscription;
  bool _isDiscovering = false;
  bool _isBTConnecting = false;
  final List<String> _btLog = [];

  Timer? _holdTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    if (!kIsWeb) {
      FlutterBluetoothSerial.instance.state.then((value) {
        if (mounted) {
          setState(() => _bluetoothState = value);
        }
      });
      _stateSubscription = FlutterBluetoothSerial.instance
          .onStateChanged()
          .listen((value) {
            if (mounted) {
              setState(() => _bluetoothState = value);
            }
          });
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseCtrl.dispose();
    _service.dispose();
    _discoverySubscription?.cancel();
    _stateSubscription?.cancel();
    _disconnectBT();
    super.dispose();
  }

  // ── Send while button held ────────────────────────────────────────────────
  void _startSending(RobotDirection dir) {
    if (!_isManualMode) {
      _showModeWarning();
      return;
    }
    setState(() => _activeDir = dir);
    HapticFeedback.lightImpact();
    _sendControlCommand(dir, speed: _speed);

    _holdTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _sendControlCommand(dir, speed: _speed);
    });
  }

  void _stopSending() {
    _holdTimer?.cancel();
    if (_activeDir != null) {
      _sendControlCommand(RobotDirection.stop, speed: 0);
      setState(() => _activeDir = null);
    }
  }

  void _showModeWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Switch to Manual Mode first',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEC4899),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleMode() async {
    HapticFeedback.mediumImpact();
    final newMode = _isManualMode ? 'auto' : 'manual';
    await _service.setMode(newMode);
    setState(() => _isManualMode = !_isManualMode);
  }

  Future<void> _onEmergencyStop() async {
    HapticFeedback.heavyImpact();
    _holdTimer?.cancel();
    setState(() => _activeDir = null);
    await _service.emergencyStop();
    _showSnack('🛑 Emergency Stop Activated', const Color(0xFFFF6B6B));
  }

  Future<void> _switchCamera(RobotCamera cam) async {
    setState(() => _selectedCamera = cam);
    await _service.switchCamera(cam);
    HapticFeedback.selectionClick();
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _requestEnableBluetooth() async {
    if (kIsWeb) return;
    if (_bluetoothState == BluetoothState.STATE_OFF ||
        _bluetoothState == BluetoothState.STATE_TURNING_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  Future<void> _scanForDevices() async {
    if (kIsWeb) return;
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await _requestEnableBluetooth();
    }
    setState(() {
      _devices.clear();
      _isDiscovering = true;
    });
    _discoverySubscription?.cancel();
    _discoverySubscription = FlutterBluetoothSerial.instance
        .startDiscovery()
        .listen(
          (result) {
            if (!_devices.any(
              (device) => device.device.address == result.device.address,
            )) {
              setState(() => _devices.add(result));
            }
          },
          onDone: () {
            if (mounted) {
              setState(() => _isDiscovering = false);
            }
          },
        );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (kIsWeb || _isBTConnecting) return;
    setState(() {
      _isBTConnecting = true;
      _selectedDevice = device;
    });
    _logBT('Connecting to ${device.name ?? device.address}...');
    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      _btConnection = connection;
      _logBT('Connected to ${device.name ?? device.address}.');
      connection.input
          ?.listen((Uint8List data) {
            final incoming = utf8.decode(data);
            _logBT('Received: $incoming');
          })
          .onDone(() {
            if (mounted) {
              setState(() {
                _btConnection = null;
                _logBT('Bluetooth connection closed.');
              });
            }
          });
    } catch (error) {
      _logBT('Connection failed: $error');
      if (mounted) {
        setState(() => _btConnection = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isBTConnecting = false);
      }
    }
  }

  Future<void> _disconnectBT() async {
    if (_btConnection != null) {
      try {
        await _btConnection!.close();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _btConnection = null;
          _logBT('Disconnected from Bluetooth device.');
        });
      }
    }
  }

  Future<void> _sendBluetoothCommand(String command) async {
    if (_btConnection == null || !_btConnection!.isConnected) {
      _logBT('Cannot send command, Bluetooth is not connected.');
      return;
    }
    try {
      final message = utf8.encode('$command\n');
      _btConnection!.output.add(Uint8List.fromList(message));
      await _btConnection!.output.allSent;
      _logBT('Sent: $command');
    } catch (error) {
      _logBT('Send failed: $error');
    }
  }

  Future<void> _sendControlCommand(
    RobotDirection direction, {
    int speed = 60,
  }) async {
    if (_btConnection != null && _btConnection!.isConnected) {
      final command = '${direction.name.toUpperCase()}:$speed';
      await _sendBluetoothCommand(command);
    } else {
      await _service.sendCommand(direction, speed: speed);
    }
  }

  void _logBT(String message) {
    if (!mounted) return;
    setState(() {
      _btLog.insert(0, '${DateTime.now().toIso8601String()} - $message');
      if (_btLog.length > 50) {
        _btLog.removeLast();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: _buildAppBar(),
      body: StreamBuilder<RobotStatus>(
        stream: _service.streamRobotStatus(),
        builder: (context, snap) {
          final status = snap.data ?? RobotStatus.offline();
          _status = status;
          return _buildBody(status);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return VisionBotAppBar(
      pageTitle: 'Robot Control',
      backgroundColor: const Color(0xFF0D0F14),
      elevation: 0,
      actions: [
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _service.streamRecentCommands(limit: 1),
          builder: (context, snap) {
            final hasRecent = snap.data?.isNotEmpty ?? false;
            return Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasRecent
                    ? const Color(0xFF10B981).withOpacity(0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasRecent
                      ? const Color(0xFF10B981).withOpacity(0.5)
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasRecent
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasRecent ? 'Live' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasRecent
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody(RobotStatus status) {
    return SafeArea(
      child: Column(
        children: [
          _buildStatusBar(status),
          _buildBluetoothSection(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildModeAndCameraRow(),
                  const SizedBox(height: 24),
                  _buildSpeedSlider(),
                  const SizedBox(height: 28),
                  _buildDPad(),
                  const SizedBox(height: 28),
                  _buildEmergencyStop(),
                  const SizedBox(height: 24),
                  _buildRecentCommandLog(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status bar ────────────────────────────────────────────────────────────
  Widget _buildStatusBar(RobotStatus status) {
    final isOnline = status.isOnline;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Online indicator
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: isOnline ? _pulse.value : 1.0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline
                      ? const Color(0xFF10B981).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                ),
                child: Icon(
                  isOnline ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
                  color: isOnline
                      ? const Color(0xFF10B981)
                      : Colors.grey.shade600,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'VisionBot Robot' : 'Robot Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: isOnline ? Colors.white : Colors.grey.shade500,
                  ),
                ),
                Text(
                  isOnline
                      ? 'Mode: ${status.mode.toUpperCase()}'
                      : 'Not reachable',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          // Battery
          if (isOnline) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Icon(
                      status.batteryLevel > 20
                          ? Icons.battery_std_rounded
                          : Icons.battery_alert_rounded,
                      size: 14,
                      color: status.batteryLevel > 20
                          ? const Color(0xFF10B981)
                          : const Color(0xFFFF6B6B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.batteryLevel}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Camera: ${status.currentCamera}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Mode + Camera row ─────────────────────────────────────────────────────
  Widget _buildModeAndCameraRow() {
    return Row(
      children: [
        // Mode toggle
        Expanded(
          child: GestureDetector(
            onTap: _toggleMode,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _isManualMode
                    ? const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                      )
                    : null,
                color: _isManualMode ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isManualMode
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isManualMode
                        ? Icons.gamepad_rounded
                        : Icons.auto_fix_high_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isManualMode ? 'MANUAL' : 'AUTO',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    _isManualMode ? 'Tap to auto' : 'Tap for manual',
                    style: TextStyle(fontSize: 10, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Camera selector
        Expanded(
          child: Column(
            children: [
              _cameraChip(
                RobotCamera.front,
                Icons.camera_front_rounded,
                'FRONT',
              ),
              const SizedBox(height: 8),
              _cameraChip(RobotCamera.back, Icons.camera_rear_rounded, 'BACK'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cameraChip(RobotCamera cam, IconData icon, String label) {
    final isSelected = _selectedCamera == cam;
    return GestureDetector(
      onTap: () => _switchCamera(cam),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF06B6D4).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF06B6D4).withOpacity(0.7)
                : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF06B6D4) : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isSelected
                    ? const Color(0xFF06B6D4)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Speed slider ──────────────────────────────────────────────────────────
  Widget _buildSpeedSlider() {
    Color sliderColor;
    String speedLabel;
    if (_speed <= 30) {
      sliderColor = const Color(0xFF10B981);
      speedLabel = 'Slow';
    } else if (_speed <= 65) {
      sliderColor = const Color(0xFFF59E0B);
      speedLabel = 'Medium';
    } else {
      sliderColor = const Color(0xFFFF6B6B);
      speedLabel = 'Fast';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: sliderColor),
              const SizedBox(width: 8),
              Text(
                'Speed',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: sliderColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_speed% · $speedLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: sliderColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              activeTrackColor: sliderColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: sliderColor,
              overlayColor: sliderColor.withOpacity(0.2),
            ),
            child: Slider(
              min: 10,
              max: 100,
              divisions: 9,
              value: _speed.toDouble(),
              onChanged: (v) => setState(() => _speed = v.round()),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['10', '30', '50', '70', '100']
                .map(
                  (s) => Text(
                    s,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  // ── D-Pad ─────────────────────────────────────────────────────────────────
  Widget _buildDPad() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 80),
              _dirButton(
                icon: Icons.keyboard_arrow_up_rounded,
                dir: RobotDirection.forward,
                label: 'FWD',
              ),
              const SizedBox(width: 80),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _dirButton(
                icon: Icons.keyboard_arrow_left_rounded,
                dir: RobotDirection.left,
                label: 'LEFT',
              ),
              const SizedBox(width: 14),
              _stopButton(),
              const SizedBox(width: 14),
              _dirButton(
                icon: Icons.keyboard_arrow_right_rounded,
                dir: RobotDirection.right,
                label: 'RIGHT',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 80),
              _dirButton(
                icon: Icons.keyboard_arrow_down_rounded,
                dir: RobotDirection.backward,
                label: 'BWD',
              ),
              const SizedBox(width: 80),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dirButton({
    required IconData icon,
    required RobotDirection dir,
    required String label,
  }) {
    final isActive = _activeDir == dir;
    return GestureDetector(
      onTapDown: (_) => _startSending(dir),
      onTapUp: (_) => _stopSending(),
      onTapCancel: _stopSending,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFFEC4899).withOpacity(0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stopButton() {
    return GestureDetector(
      onTap: () {
        if (_isManualMode) {
          HapticFeedback.lightImpact();
          _sendControlCommand(RobotDirection.stop, speed: 0);
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: const Icon(Icons.stop_rounded, color: Colors.white54, size: 28),
      ),
    );
  }

  Widget _buildBluetoothSection() {
    final statusText = kIsWeb
        ? 'Bluetooth unavailable on web'
        : _btConnection != null && _btConnection!.isConnected
        ? 'Connected to ${_selectedDevice?.name ?? _selectedDevice?.address ?? 'device'}'
        : _isBTConnecting
        ? 'Connecting...'
        : _isDiscovering
        ? 'Scanning devices...'
        : _bluetoothState == BluetoothState.STATE_OFF
        ? 'Bluetooth off'
        : 'Disconnected';
    final statusColor = kIsWeb
        ? Colors.grey
        : _btConnection != null && _btConnection!.isConnected
        ? Colors.green
        : _bluetoothState == BluetoothState.STATE_OFF
        ? Colors.red
        : Colors.orange;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bluetooth',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(statusText, style: TextStyle(color: statusColor)),
                  ],
                ),
              ),
              if (!kIsWeb)
                ElevatedButton(
                  onPressed: _isDiscovering || _isBTConnecting
                      ? null
                      : _scanForDevices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12,
                  ),
                  child: Text(
                    _isDiscovering ? 'Scanning' : 'Scan',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!kIsWeb) _buildBluetoothDeviceList(),
          if (_btLog.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        'BT Log',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => _btLog.clear()),
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      itemCount: _btLog.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12),
                      itemBuilder: (context, index) => Text(
                        _btLog[index],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBluetoothDeviceList() {
    if (_devices.isEmpty) {
      return const Text(
        'No devices found yet. Tap Scan to discover nearby car/robot Bluetooth devices.',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      );
    }

    return Column(
      children: _devices.map((result) {
        final device = result.device;
        final isSelected = _selectedDevice?.address == device.address;
        final isConnected =
            _btConnection != null && _btConnection!.isConnected && isSelected;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.devices, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? device.address,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      device.address,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected ? Colors.red : Colors.blue,
                ),
                onPressed: _isBTConnecting
                    ? null
                    : () {
                        if (isConnected) {
                          _disconnectBT();
                        } else {
                          _connectToDevice(device);
                        }
                      },
                child: Text(isConnected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Emergency stop ────────────────────────────────────────────────────────
  Widget _buildEmergencyStop() {
    return GestureDetector(
      onTap: _onEmergencyStop,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4444).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emergency_rounded, color: Colors.white, size: 26),
            SizedBox(width: 10),
            Text(
              'EMERGENCY STOP',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent command log ────────────────────────────────────────────────────
  Widget _buildRecentCommandLog() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.streamRecentCommands(limit: 6),
      builder: (context, snap) {
        final cmds = snap.data ?? [];
        if (cmds.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Commands',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...cmds.map((cmd) => _commandRow(cmd)),
            ],
          ),
        );
      },
    );
  }

  Widget _commandRow(Map<String, dynamic> cmd) {
    final dir = cmd['direction'] ?? cmd['action'] ?? '—';
    final speed = cmd['speed'];
    final executed = cmd['is_executed'] == true;
    final mode = cmd['mode'];

    IconData icon;
    Color color;
    switch (dir) {
      case 'forward':
        icon = Icons.arrow_upward_rounded;
        color = const Color(0xFF10B981);
        break;
      case 'backward':
        icon = Icons.arrow_downward_rounded;
        color = const Color(0xFFF59E0B);
        break;
      case 'left':
        icon = Icons.arrow_back_rounded;
        color = const Color(0xFF06B6D4);
        break;
      case 'right':
        icon = Icons.arrow_forward_rounded;
        color = const Color(0xFF8B5CF6);
        break;
      case 'stop':
        icon = Icons.stop_rounded;
        color = const Color(0xFFFF6B6B);
        break;
      default:
        icon = Icons.settings_rounded;
        color = Colors.grey.shade500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mode != null
                  ? 'Mode → ${mode.toString().toUpperCase()}'
                  : dir.toString().toUpperCase() +
                        (speed != null ? '  ·  ${speed}%' : ''),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Icon(
            executed ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 14,
            color: executed ? const Color(0xFF10B981) : Colors.grey.shade600,
          ),
        ],
      ),
    );
  }
}
