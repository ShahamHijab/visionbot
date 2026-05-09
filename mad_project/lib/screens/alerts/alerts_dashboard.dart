import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/alert_service.dart';
import '../../services/backend_fetch_service.dart';
import '../../models/alert_model.dart';
import '../../routes/app_routes.dart';

class AlertsDashboard extends StatefulWidget {
  const AlertsDashboard({super.key});

  @override
  State<AlertsDashboard> createState() => _AlertsDashboardState();
}

class _AlertsDashboardState extends State<AlertsDashboard> {
  final AlertService _alertService = AlertService();
  final BackendFetchService _backendFetch = BackendFetchService();
  final Connectivity _connectivity = Connectivity(); // ✅ NEW

  List<AlertModel> _cachedAlerts = [];
  bool _isOnline = true;
  bool _isLoading = false; // ✅ NEW: Track loading state

  @override
  void initState() {
    super.initState();
    _initializeBackend();
    _loadCachedAlerts();
    _monitorConnectivity(); // ✅ NEW: Monitor internet changes
  }

  /// ✅ NEW: Monitor internet connectivity changes
  void _monitorConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      if (_isOnline != isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
        
        if (isOnline) {
          debugPrint('🌐 Internet restored - reloading alerts');
          _loadCachedAlerts();
        } else {
          debugPrint('📴 Internet lost - showing cached alerts');
        }
      }
    });
  }

  Future<void> _initializeBackend() async {
    debugPrint('🔧 Initializing backend fetch service...');
    await _backendFetch.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCachedAlerts() async {
    if (_isLoading) return; // ✅ NEW: Prevent concurrent loads
    
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('📡 Loading alerts...');
      final alerts = await _backendFetch.getAlerts(limit: 50);
      
      if (mounted) {
        setState(() {
          _cachedAlerts = alerts;
          _isLoading = false;
        });
        
        debugPrint('✅ Loaded ${alerts.length} alerts');
      }
    } catch (e) {
      debugPrint('❌ Load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            'Alerts',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        elevation: 0,
        actions: [
          // ✅ UPDATED: Show connection status
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Tooltip(
                message: _isOnline
                    ? 'Online - syncing alerts'
                    : 'Offline - showing cached alerts',
                child: Row(
                  children: [
                    Icon(
                      _isOnline ? Icons.cloud_done : Icons.cloud_off,
                      size: 20,
                      color: _isOnline ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ✅ UPDATED: Refresh button with loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadCachedAlerts();
              },
              tooltip: 'Refresh alerts',
            ),
        ],
      ),
      body: _buildAlertsList(),
      floatingActionButton: _isLoading
          ? null // ✅ NEW: Hide FAB while loading
          : FloatingActionButton(
              onPressed: () {
                _loadCachedAlerts();
              },
              tooltip: 'Refresh',
              child: const Icon(Icons.cloud_download),
            ),
    );
  }

  /// ✅ FIXED: Removed duplicate code
  Widget _buildAlertsList() {
    return RefreshIndicator(
      onRefresh: () async {
        debugPrint('⬇️ Pull-to-refresh triggered');
        await _loadCachedAlerts();
      },
      child: StreamBuilder<List<AlertModel>>(
        stream: _alertService.streamAlerts(limit: 50),
        builder: (context, snapshot) {
          // ✅ Show cached alerts while loading
          final alerts = snapshot.data ?? _cachedAlerts;

          // Loading state (only if no cached data)
          if (snapshot.connectionState == ConnectionState.waiting &&
              alerts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading alerts...'),
                ],
              ),
            );
          }

          // Error state (only if no cached data)
          if (snapshot.hasError && alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadCachedAlerts();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No alerts',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadCachedAlerts();
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }

          // ✅ Show alerts list (cached or fresh)
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return _buildCompactAlertCard(alert);
            },
          );
        },
      ),
    );
  }

  /// ✅ UPDATED: Better error handling for images
  Widget _buildCompactAlertCard(AlertModel alert) {
    final typeLabel = _getTypeLabel(alert.type);
    final typeColor = _getTypeColor(alert.type);
    final typeIcon = _getTypeIcon(alert.type);

    final thumbnailUrl = alert.imageUrl.isNotEmpty
        ? alert.imageUrl
        : (alert.faceImageUrls.isNotEmpty ? alert.faceImageUrls.first : '');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.alertDetail,
            arguments: alert,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ✅ UPDATED: Better image handling
              if (thumbnailUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: Image.network(
                      thumbnailUrl,
                      fit: BoxFit.cover,
                      cacheHeight: 120,
                      cacheWidth: 120,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 24,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    ),
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 28),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      typeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(alert.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    // ✅ NEW: Show description if available
                    if (alert.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        alert.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: alert.isRead ? Colors.grey[200] : Colors.blue[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  alert.isRead ? 'Read' : 'New',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: alert.isRead ? Colors.grey[700] : Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(AlertType type) {
    switch (type) {
      case AlertType.unknownFace:
        return '👤 Unknown Person';
      case AlertType.knownFace:
        return '✅ Known Person';
      case AlertType.group:
        return '👥 Group Detected';
      case AlertType.smoke:
        return '💨 Smoking Detected';
      case AlertType.fire:
        return '🔥 Fire Detected';
      case AlertType.intruder:
        return '🛡️ Intruder Detected';
      default:
        return '⚠️ Alert';
    }
  }

  Color _getTypeColor(AlertType type) {
    switch (type) {
      case AlertType.unknownFace:
      case AlertType.fire:
        return Colors.red;
      case AlertType.knownFace:
        return Colors.green;
      case AlertType.group:
        return Colors.orange;
      case AlertType.smoke:
        return Colors.amber;
      case AlertType.intruder:
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.unknownFace:
        return Icons.person_search;
      case AlertType.knownFace:
        return Icons.verified_user;
      case AlertType.group:
        return Icons.people_outline;
      case AlertType.smoke:
        return Icons.smoking_rooms;
      case AlertType.fire:
        return Icons.local_fire_department;
      case AlertType.intruder:
        return Icons.security;
      default:
        return Icons.warning_outlined;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _backendFetch.dispose();
    super.dispose();
  }
}