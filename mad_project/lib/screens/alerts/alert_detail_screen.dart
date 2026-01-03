import 'package:flutter/material.dart';
import '../../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final AlertModel? alert = args is AlertModel ? args : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: alert == null
          ? const Center(child: Text('No alert data found'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _header(alert),
                const SizedBox(height: 16),
                _infoTile('Title', alert.title),
                _infoTile('Type', alert.type.displayName),
                _infoTile('Severity', alert.severity.displayName),
                _infoTile(
                  'Location',
                  alert.location.isEmpty ? 'Unknown' : alert.location,
                ),
                _infoTile('Time', _formatDateTime(alert.timestamp)),
                if (alert.description.isNotEmpty)
                  _infoTile('Description', alert.description),
                _infoTile('Read', alert.isRead ? 'Yes' : 'No'),
                const SizedBox(height: 16),
                if (alert.imageUrl.isNotEmpty) _imageBlock(alert.imageUrl),
              ],
            ),
    );
  }

  Widget _header(AlertModel alert) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.black.withOpacity(0.06),
          ),
          child: Text(alert.type.icon, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                alert.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${alert.severity.displayName}  •  ${_formatDateTime(alert.timestamp)}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _imageBlock(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Colors.black.withOpacity(0.06),
              alignment: Alignment.center,
              child: const Text('Image failed to load'),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.black.withOpacity(0.06),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          },
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
