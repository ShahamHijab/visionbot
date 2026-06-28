import 'package:mad_project/widgets/visionbot_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/alert_service.dart';
import '../../services/backend_fetch_service.dart';
import '../../models/alert_model.dart';
import '../../routes/app_routes.dart';
import '../../widgets/visionbot_app_bar.dart';

class AlertsDashboard extends StatefulWidget {
  const AlertsDashboard({super.key});

  @override
  State<AlertsDashboard> createState() => _AlertsDashboardState();
}

class _AlertsDashboardState extends State<AlertsDashboard> {
  final AlertService _alertService = AlertService();
  final BackendFetchService _backendFetch = BackendFetchService();
  final Connectivity _connectivity = Connectivity();

  List<AlertModel> _cachedAlerts = [];
  bool _isOnline = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
    _monitorConnectivity();
  }

  Future<void> _init() async {
    await _backendFetch.initialize();
    await _loadCachedAlerts();
  }

  void _monitorConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;

      if (_isOnline != isOnline) {
        setState(() {
          _isOnline = isOnline;
        });

        if (isOnline) {
          _loadCachedAlerts();
        }
      }
    });
  }

  Future<void> _loadCachedAlerts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final alerts = await _backendFetch.getAlerts(limit: 50);

      if (mounted) {
        setState(() {
          _cachedAlerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return const Color(0xFFFF6B6B);
      case 'smoke':
        return const Color(0xFFF59E0B);
      case 'group':
      case 'group_detected':
        return const Color(0xFF10B981);
      case 'unknown_face':
      case 'intruder':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF45B7D1);
    }
  }

  String _formatTime(DateTime dt) {
    return "${dt.year}-${dt.month}-${dt.day} ${dt.hour}:${dt.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: VisionBotAppBar(
        pageTitle: 'Alerts',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCachedAlerts,
          ),
        ],
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertService.streamAlerts(limit: 50),
        builder: (context, snapshot) {
          final streamData = snapshot.data;

          final alerts = (streamData != null && streamData.isNotEmpty)
              ? streamData
              : _cachedAlerts;

          if (_isLoading && alerts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (alerts.isEmpty) {
            return const Center(child: Text("No alerts"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final color = _getColor(alert.type.toString());
              final imageUrl = alert.imageUrl ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.alertDetail,
                    arguments: alert,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // ✅ IMAGE REPLACES ICON (ONLY CHANGE)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey.shade200,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                child: const Icon(
                                  Icons.image_not_supported_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                      ),

                      const SizedBox(width: 12),

                      // TEXT SECTION
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.type.toString(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(alert.timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _backendFetch.dispose();
    super.dispose();
  }
}
