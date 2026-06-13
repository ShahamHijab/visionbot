import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  final List<BluetoothDiscoveryResult> _devices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  StreamSubscription<BluetoothState>? _stateSubscription;
  bool _isDiscovering = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  double _speed = 50;
  final List<String> _commandLog = [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      FlutterBluetoothSerial.instance.state.then((state) {
        setState(() => _bluetoothState = state);
      });
      _stateSubscription =
          FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
        if (mounted) {
          setState(() => _bluetoothState = state);
        }
      });
    }
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _stateSubscription?.cancel();
    _disconnect();
    super.dispose();
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
    _discoverySubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((result) {
      if (!_devices.any((device) => device.device.address == result.device.address)) {
        setState(() {
          _devices.add(result);
        });
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (kIsWeb) return;
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _selectedDevice = device;
    });
    _logCommand('Connecting to ${device.name ?? device.address}...');

    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      _isConnected = true;
      _logCommand('Connected to ${device.name ?? device.address}.');

      connection.input?.listen((Uint8List data) {
        final incoming = utf8.decode(data);
        _logCommand('Received: $incoming');
      }).onDone(() {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _connection = null;
            _logCommand('Connection closed.');
          });
        }
      });
    } catch (error) {
      _logCommand('Connection failed: $error');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _connection = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isConnected = false;
          _connection = null;
          _logCommand('Disconnected from device.');
        });
      }
    }
  }

  Future<void> _sendCommand(String command) async {
    if (_connection == null || !_isConnected) {
      _logCommand('Cannot send command: not connected');
      return;
    }

    try {
      final message = utf8.encode('$command\n');
      _connection!.output.add(Uint8List.fromList(message));
      await _connection!.output.allSent;
      _logCommand('Sent: $command');
    } catch (error) {
      _logCommand('Send failed: $error');
    }
  }

  void _logCommand(String message) {
    if (!mounted) return;
    setState(() {
      _commandLog.insert(0, '${DateTime.now().toIso8601String()} - $message');
      if (_commandLog.length > 50) {
        _commandLog.removeLast();
      }
    });
  }

  Widget _buildStatusIndicator() {
    final status = kIsWeb
        ? 'Unsupported on web'
        : _isConnected
            ? 'Connected'
            : _isConnecting
                ? 'Connecting...'
                : _bluetoothState == BluetoothState.STATE_OFF
                    ? 'Bluetooth off'
                    : _isDiscovering
                        ? 'Scanning for devices'
                        : 'Disconnected';

    final color = kIsWeb
        ? Colors.grey
        : _isConnected
            ? Colors.green
            : _bluetoothState == BluetoothState.STATE_OFF
                ? Colors.red
                : Colors.orange;

    return Row(
      children: [
        Icon(Icons.bluetooth, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connection Status',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        if (!kIsWeb)
          ElevatedButton(
            onPressed: _isDiscovering ? null : _scanForDevices,
            child: Text(_isDiscovering ? 'Scanning...' : 'Scan'),
          ),
      ],
    );
  }

  Widget _buildDevicesList() {
    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Bluetooth scanning is not supported on web.'),
      );
    }

    if (_devices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          _isDiscovering
              ? 'Searching for nearby Bluetooth devices...'
              : 'No devices found. Tap Scan to search.',
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final result = _devices[index];
        final device = result.device;
        final isSelected = _selectedDevice?.address == device.address;

        return ListTile(
          leading: const Icon(Icons.devices),
          title: Text(device.name ?? device.address),
          subtitle: Text(device.address),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSelected && _isConnected ? Colors.red : Colors.blue,
            ),
            onPressed: _isConnecting
                ? null
                : () {
                    if (_isConnected && isSelected) {
                      _disconnect();
                      return;
                    }
                    _connectToDevice(device);
                  },
            child: Text(
              _isConnected && isSelected ? 'Disconnect' : 'Connect',
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButton(String label, IconData icon, String command) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: _isConnected ? Colors.deepPurple : Colors.grey,
          ),
          icon: Icon(icon, size: 20),
          label: Text(label),
          onPressed: _isConnected ? () => _sendCommand(command) : null,
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        Row(
          children: [
            const Spacer(),
            _buildControlButton('Forward', Icons.arrow_upward, 'FORWARD:${_speed.toInt()}'),
            const Spacer(),
          ],
        ),
        Row(
          children: [
            _buildControlButton('Left', Icons.arrow_back, 'LEFT:${_speed.toInt()}'),
            _buildControlButton('Stop', Icons.stop, 'STOP'),
            _buildControlButton('Right', Icons.arrow_forward, 'RIGHT:${_speed.toInt()}'),
          ],
        ),
        Row(
          children: [
            const Spacer(),
            _buildControlButton('Backward', Icons.arrow_downward, 'BACKWARD:${_speed.toInt()}'),
            const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Speed: ${_speed.toInt()}%',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Slider(
          value: _speed,
          min: 0,
          max: 100,
          divisions: 20,
          label: '${_speed.toInt()}%',
          onChanged: _isConnected
              ? (value) {
                  setState(() {
                    _speed = value;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildCommandLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Command Log',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _commandLog.clear();
                });
              },
              child: const Text('Clear'),
            ),
          ],
        ),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _commandLog.isEmpty
              ? const Center(
                  child: Text(
                    'No commands yet. Connect to a device and use the buttons above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _commandLog.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    return Text(
                      _commandLog[index],
                      style: const TextStyle(fontSize: 14),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Controls'),
        centerTitle: true,
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isDiscovering ? null : _scanForDevices,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildStatusIndicator(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!kIsWeb) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Devices',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                _buildDevicesList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Drive Controls',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              _buildControlPanel(),
                              const SizedBox(height: 20),
                              _buildSpeedSlider(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildCommandLog(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
