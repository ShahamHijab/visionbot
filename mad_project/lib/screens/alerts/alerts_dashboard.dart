// 📱 PHONE: Display alerts with HYBRID fetching
// ✅ Firebase PRIMARY → Laptop Backup → Local Cache

import 'package:flutter/material.dart';
import '../../services/backend_fetch_service.dart';
import '../../services/database_service.dart';
import '../../routes/app_routes.dart';

class AlertsDashboard extends StatefulWidget {
  const AlertsDashboard({super.key});

  @override
  State<AlertsDashboard> createState() => _AlertsDashboardState();
}

class _AlertsDashboardState extends State<AlertsDashboard> {
  final BackendFetchService _backendFetch = BackendFetchService();
  final DatabaseService _localDb = DatabaseService();

  List<Map<String, dynamic>> _alerts = [];
  bool _loading = false;
  String _status = '⏳ Loading...';
  String _source = ''; // Track where data came from

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  /// ✅ Load alerts from hybrid sources
  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _status = '🔄 Fetching...';
      _source = '';
    });

    try {
      // ✅ Try hybrid fetch (Firebase → Laptop → Cache)
      final alerts = await _backendFetch.getAlerts();

      // Determine source
      String source = '❓ Unknown';
      if (alerts.isNotEmpty) {
        // Check if from Firebase (will have created_at timestamp)
        if (alerts.first.containsKey('created_at') && 
            alerts.first['created_at'] != null) {
          source = '🌐 Firebase';
        } 
        // Check if from laptop (will have receivedAt)
        else if (alerts.first.containsKey('receivedAt')) {
          source = '📡 Laptop';
        } 
        // Otherwise from cache
        else {
          source = '💾 Cache';
        }
      }

      setState(() {
        _alerts = alerts;
        _status = '✅ ${alerts.length} alerts';
        _source = source;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _source = '❌ Failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Alert Dashboard',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _status,
                style: TextStyle(
                  fontSize: 11,
                  color: _status.startsWith('✅')
                      ? Colors.green
                      : _status.startsWith('❌')
                          ? Colors.red
                          : Colors.orange,
                ),
              ),
              if (_source.isNotEmpty)
                Text(
                  _source,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAlerts,
              tooltip: 'Refresh alerts',
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadAlerts,
        tooltip: 'Fetch alerts',
        child: const Icon(Icons.cloud_download),
      ),
    );
  }

  Widget _buildBody() {
    if (_alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No alerts found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (_source.isNotEmpty)
              Text(
                _source,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAlerts,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final alert = _alerts[index];

        return Card(
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.warning_rounded,
                color: Colors.blue.shade700,
              ),
            ),
            title: Text(
              alert['type']?.toString() ?? 'Alert',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  alert['created_at_local']?.toString() ?? 
                  alert['receivedAt']?.toString() ?? 
                  'Unknown time',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: Chip(
              label: Text(
                _getAlertSourceLabel(alert),
                style: const TextStyle(fontSize: 10),
              ),
              backgroundColor: _getAlertSourceColor(alert),
            ),
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.alertDetail,
                arguments: alert,
              );
            },
          ),
        );
      },
    );
  }

  /// ✅ Determine alert source
  String _getAlertSourceLabel(Map<String, dynamic> alert) {
    if (alert['created_at'] != null) {
      return '☁️ Cloud';
    }
    if (alert['receivedAt'] != null) {
      return '📡 Server';
    }
    if (alert['synced_to_firebase'] == 1) {
      return '✅ Synced';
    }
    return '💾 Local';
  }

  /// ✅ Determine alert source color
  Color _getAlertSourceColor(Map<String, dynamic> alert) {
    if (alert['created_at'] != null) {
      return Colors.blue.shade100;
    }
    if (alert['receivedAt'] != null) {
      return Colors.orange.shade100;
    }
    if (alert['synced_to_firebase'] == 1) {
      return Colors.green.shade100;
    }
    return Colors.grey.shade100;
  }

  @override
  void dispose() {
    _backendFetch.dispose();
    super.dispose();
  }
}