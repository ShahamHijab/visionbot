// lib/widgets/alert_card.dart
import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({super.key, required this.alert, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = alert.type.displayName;
    final subtitle = _subtitle();
    final timeText = _formatTime(alert.createdAt);
    final color = alert.type.toString().severityColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
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
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  alert.type.icon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                timeText,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final lensText = alert.lens.isEmpty ? 'unknown' : alert.lens;
    final noteText = alert.note.isEmpty ? '' : alert.note;
    if (noteText.isEmpty) return 'Lens: $lensText';
    return 'Lens: $lensText. $noteText';
  }

  static String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
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

  Color get severityColor {
    final t = toLowerCase().trim();

    if (t == 'fire' || t == 'intruder') return const Color(0xFFFF6B6B);
    if (t == 'smoke' ||
        t == 'unknown_face' ||
        t == 'unknownface' ||
        t == 'alerttype.unknownface') {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF45B7D1);
  }
}
