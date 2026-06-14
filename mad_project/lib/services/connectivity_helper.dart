// 📱 PHONE: Check internet connectivity

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityHelper {
  static final ConnectivityHelper _instance = ConnectivityHelper._internal();
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;

  factory ConnectivityHelper() {
    return _instance;
  }

  ConnectivityHelper._internal();

  bool get isOnline => _isOnline;

  /// ✅ Initialize connectivity monitoring
  Future<void> initialize() async {
    debugPrint('🔍 Checking connectivity...');

    // Check current status
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  /// Update connectivity status
  void _updateStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (_isOnline && !wasOnline) {
      debugPrint('🌐 ONLINE');
    } else if (!_isOnline && wasOnline) {
      debugPrint('❌ OFFLINE');
    }
  }
}