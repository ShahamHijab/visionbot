// lib/screens/alerts/alerts_dashboard.dart - FIXED

import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../routes/app_routes.dart';
import '../../services/alert_service.dart';
import '../../widgets/alert_card.dart';

class AlertsDashboard extends StatefulWidget {
  const AlertsDashboard({super.key});

  @override
  State<AlertsDashboard> createState() => _AlertsDashboardState();
}

class _AlertsDashboardState extends State<AlertsDashboard> {
  late final AlertService _alertService;

  @override
  void initState() {
    super.initState();
    _alertService = AlertService();
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
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertService.streamAlerts(limit: 100),
        builder: (context, snapshot) {
          // ✅ Handle connection states
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load alerts',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
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
                    'Check back later for new detections',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final alert = alerts[index];

              return AlertCard(
                alert: alert,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.alertDetail,
                    arguments: alert,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}