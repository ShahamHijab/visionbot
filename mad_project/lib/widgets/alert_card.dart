import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../theme/app_colors.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({
    super.key,
    required this.alert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Alert Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getAlertColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                alert.type.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 16),
            
            // Alert Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      _buildSeverityBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.location,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Time
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(alert.timestamp),
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 12,
                  ),
                ),
                if (!alert.isRead)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 8,
                    width: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.critical,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getAlertColor() {
    switch (alert.type) {
      case AlertType.fire:
        return AppColors.fireAlert;
      case AlertType.smoke:
        return AppColors.smokeAlert;
      case AlertType.human:
        return AppColors.humanAlert;
      case AlertType.motion:
        return AppColors.motionAlert;
      case AlertType.restricted:
        return AppColors.restrictedAlert;
      default:
        return AppColors.info;
    }
  }

  Widget _buildSeverityBadge() {
    Color color;
    switch (alert.severity) {
      case AlertSeverity.critical:
        color = AppColors.critical;
        break;
      case AlertSeverity.warning:
        color = AppColors.warning;
        break;
      case AlertSeverity.info:
        color = AppColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        alert.severity.displayName,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}