// lib/screens/alerts/alert_detail_screen.dart
import 'package:flutter/material.dart';
import '../../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alert = ModalRoute.of(context)!.settings.arguments as AlertModel;

    final typeText = alert.type.toString().displayName;
    final severityText = alert.type.toString().severityDisplayName;

    final lensText = alert.lens.isEmpty ? 'Unknown' : alert.lens;
    final noteText = alert.note.isEmpty ? 'Unknown' : alert.note;
    final timeText = _formatDateTime(alert.createdAt);

    final thresholdText = (alert.threshold == null)
        ? 'Unknown'
        : '${alert.threshold}';

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      alert.type.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$severityText  •  $timeText',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _infoTile('Type', typeText),
            _infoTile('Lens', lensText),
            _infoTile('Note', noteText),
            _infoTile('Threshold', thresholdText),
            _infoTile('Time', timeText),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final m = two(dt.month);
    final d = two(dt.day);
    final hh = two(dt.hour);
    final mm = two(dt.minute);
    return '$y-$m-$d $hh:$mm';
  }
}

extension AlertTypeText on String {
  String get displayName {
    final t = toLowerCase().trim();

    if (t == 'unknown_face' ||
        t == 'unknownface' ||
        t == 'alerttype.unknownface') {
      return 'Unknown person';
    }
    if (t == 'known_face' || t == 'knownface') return 'Known person';
    if (t == 'motion') return 'Motion detected';
    if (t == 'fire') return 'Fire detected';
    if (t == 'smoke') return 'Smoke detected';
    if (t == 'intruder') return 'Intruder detected';

    if (t.isEmpty) return 'Alert';
    final pretty = t.replaceAll('_', ' ').replaceAll('alerttype.', '');
    return pretty[0].toUpperCase() + pretty.substring(1);
  }

  String get severityDisplayName {
    final t = toLowerCase().trim();

    if (t == 'fire' || t == 'intruder') return 'Critical';
    if (t == 'smoke' ||
        t == 'unknown_face' ||
        t == 'unknownface' ||
        t == 'alerttype.unknownface') {
      return 'Warning';
    }
    return 'Info';
  }

  String get icon {
    final t = toLowerCase().trim();

    if (t == 'fire') return '🔥';
    if (t == 'smoke') return '💨';
    if (t == 'unknown_face' ||
        t == 'unknownface' ||
        t == 'alerttype.unknownface')
      return '👤';
    if (t == 'known_face' || t == 'knownface') return '🙂';
    if (t == 'motion') return '🏃';
    if (t == 'intruder') return '🛡️';
    return '⚠️';
  }
}
