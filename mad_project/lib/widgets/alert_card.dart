// lib/widgets/alert_card.dart
import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({super.key, required this.alert, this.onTap});

  bool get _isFaceAlert {
    final t = alert.type.toString().toLowerCase();
    return t.contains('unknown_face') ||
        t.contains('unknownface') ||
        t.contains('known_face') ||
        t.contains('knownface') ||
        t.contains('intruder');
  }

  bool get _hasImage => alert.imageUrl.isNotEmpty;

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
              // ── Avatar: face photo OR icon ──────────────────────────
              _buildAvatar(color),

              const SizedBox(width: 12),

              // ── Content ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        // Badge for face alerts
                        if (_isFaceAlert) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _hasImage
                                      ? Icons.photo_camera_rounded
                                      : Icons.no_photography_rounded,
                                  size: 10,
                                  color: color,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _hasImage ? 'PHOTO' : 'NO IMG',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar builder ────────────────────────────────────────────────────────
  Widget _buildAvatar(Color color) {
    // Face alert with actual image URL — show the photo
    if (_isFaceAlert && _hasImage) {
      return _FaceImageAvatar(
        imageUrl: alert.imageUrl,
        color: color,
        size: 56,
      );
    }

    // Face alert but no image stored in Firestore
    if (_isFaceAlert && !_hasImage) {
      return _noPhotoPlaceholder(color);
    }

    // Non-face alert — emoji icon
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        alert.type.icon,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }

  // ── No-photo placeholder ──────────────────────────────────────────────────
  Widget _noPhotoPlaceholder(Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.face_retouching_off_rounded, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            'No\nPhoto',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
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

// ── Reusable face image widget with loading + error states ─────────────────
class _FaceImageAvatar extends StatelessWidget {
  final String imageUrl;
  final Color color;
  final double size;

  const _FaceImageAvatar({
    required this.imageUrl,
    required this.color,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          // Cache headers help with repeated loads
          headers: const {
            'Cache-Control': 'max-age=3600',
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: SizedBox(
                  width: size * 0.35,
                  height: size * 0.35,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded /
                            progress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // On error, show a styled placeholder with the error hint
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withOpacity(0.25), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_rounded,
                      color: color.withOpacity(0.6), size: size * 0.35),
                  const SizedBox(height: 2),
                  Text(
                    'Load\nFailed',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7,
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Extensions ────────────────────────────────────────────────────────────
extension AlertTypeText on String {
  String get displayName {
    final t = toLowerCase().trim();
    if (t == 'unknown_face' ||
        t == 'unknownface' ||
        t == 'alerttype.unknownface') return 'Unknown person';
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
        t == 'alerttype.unknownface') return '👤';
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
        t == 'alerttype.unknownface') return const Color(0xFFF59E0B);
    return const Color(0xFF45B7D1);
  }
}