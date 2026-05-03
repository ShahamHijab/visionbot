import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeBackend();
  }

  Future<void> _initializeBackend() async {
    await _backendFetch.initialize();
    if (mounted) {
      setState(() {});
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh alerts',
          ),
        ],
      ),
      body: _buildAlertsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {}),
        tooltip: 'Refresh',
        child: const Icon(Icons.cloud_download),
      ),
    );
  }

  Widget _buildAlertsList() {
    return StreamBuilder<List<AlertModel>>(
      stream: _alertService.streamAlerts(limit: 50),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // Empty state
        final alerts = snapshot.data ?? [];

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
              ],
            ),
          );
        }

        // Alerts list - COMPACT VERSION
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return _buildCompactAlertCard(alert);
          },
        );
      },
    );
  }

  /// ✅ COMPACT alert card (like before)
  Widget _buildCompactAlertCard(AlertModel alert) {
    final typeLabel = _getTypeLabel(alert.type);
    final typeColor = _getTypeColor(alert.type);
    final typeIcon = _getTypeIcon(alert.type);

    // Get thumbnail image URL
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
              // ✅ Thumbnail image (small, left side)
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
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.grey.shade400,
                              ),
                            ),
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

              // ✅ Details (center)
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
                    if (alert.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        alert.description,
                        style: TextStyle(
                          fontSize: 11,
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

              // ✅ Status (right)
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
                    color: alert.isRead
                        ? Colors.grey[700]
                        : Colors.blue[700],
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
      case AlertType.fire:
        return 'Fire Detected';
      case AlertType.smoke:
        return 'Smoking Detected';
      case AlertType.human:
        return 'Person Detected';
      case AlertType.motion:
        return 'Motion Detected';
      case AlertType.restricted:
        return 'Restricted Area';
      case AlertType.group:
        return 'Group Detected';
      case AlertType.unknownFace:
        return 'Unknown Person';
      case AlertType.knownFace:
        return 'Known Person';
      case AlertType.intruder:
        return 'Intruder Detected';
      case AlertType.other:
        return 'Alert';
    }
  }

  Color _getTypeColor(AlertType type) {
    switch (type) {
      case AlertType.fire:
        return Colors.red;
      case AlertType.smoke:
        return Colors.amber;
      case AlertType.human:
        return Colors.blue;
      case AlertType.motion:
        return Colors.cyan;
      case AlertType.restricted:
        return Colors.purple;
      case AlertType.group:
        return Colors.orange;
      case AlertType.unknownFace:
        return Colors.red;
      case AlertType.knownFace:
        return Colors.green;
      case AlertType.intruder:
        return Colors.deepOrange;
      case AlertType.other:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(AlertType type) {
    switch (type) {
      case AlertType.fire:
        return Icons.local_fire_department;
      case AlertType.smoke:
        return Icons.smoking_rooms;
      case AlertType.human:
        return Icons.person_outline;
      case AlertType.motion:
        return Icons.directions_run;
      case AlertType.restricted:
        return Icons.block;
      case AlertType.group:
        return Icons.people_outline;
      case AlertType.unknownFace:
        return Icons.person_search;
      case AlertType.knownFace:
        return Icons.verified_user;
      case AlertType.intruder:
        return Icons.security;
      case AlertType.other:
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
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  void dispose() {
    _backendFetch.dispose();
    super.dispose();
  }
}