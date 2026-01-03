import 'package:flutter/material.dart';
import '../../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  String _formatThreshold(dynamic v) {
    if (v == null) return 'N/A';
    if (v is num) return v.toStringAsFixed(2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args == null || args is! AlertModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alert Detail')),
        body: const Center(child: Text('No alert data found')),
      );
    }

    final alert = args;

    final typeText = (alert.type.toString()).isEmpty
        ? 'N/A'
        : alert.type.toString();
    final lensText = alert.lens.isEmpty ? 'N/A' : alert.lens;
    final noteText = alert.note.isEmpty ? 'N/A' : alert.note;

    final createdAtText = _formatDateTime(alert.createdAt);

    // created_at_local can be String or DateTime depending on your model
    final createdAtLocalRaw = alert.createdAtLocal;
    String createdAtLocalText;
    if (createdAtLocalRaw == null) {
      createdAtLocalText = 'N/A';
    } else if (createdAtLocalRaw is DateTime) {
      createdAtLocalText = _formatDateTime(createdAtLocalRaw);
    } else {
      createdAtLocalText = createdAtLocalRaw.toString();
    }

    final thresholdText = _formatThreshold(alert.threshold);

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Alert Details',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoTile('created_at', createdAtText),
          _infoTile('created_at_local', createdAtLocalText),
          _infoTile('lens', lensText),
          _infoTile('note', noteText),
          _infoTile('threshold', thresholdText),
          _infoTile('type', typeText),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
