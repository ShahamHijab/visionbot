import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../routes/app_routes.dart';
import '../../services/alert_service.dart';
import '../../widgets/alert_card.dart';

class AlertsDashboard extends StatelessWidget {
  const AlertsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AlertService alertService = AlertService();

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
        stream: alertService.streamAlerts(limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load alerts'));
          }

          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(child: Text('No alerts found'));
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
