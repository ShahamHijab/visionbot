import 'package:flutter/material.dart';
import '../models/alert_model.dart';

class AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback? onTap;

  const AlertCard({super.key, required this.alert, this.onTap});

  bool get _isVisualAlert {
    return alert.type == AlertType.unknownFace ||
        alert.type == AlertType.knownFace ||
        alert.type == AlertType.intruder ||
        alert.type == AlertType.group;
  }

  bool get _hasAnyImage {
    return alert.faceImageUrls.isNotEmpty || alert.imageUrl.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final title = alert.type.displayName;
    final subtitle = _subtitle();
    final timeText = _formatTime(alert.createdAt);
    final color = _severityColor;

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
              _buildAvatar(color),
              const SizedBox(width: 12),

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
                        if (_isVisualAlert) ...[
                          const SizedBox(width: 6),
                          _imageBadge(color),
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
                    if (alert.hasLocation) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: Color(0xFF06B6D4),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              alert.locationName ??
                                  '${alert.latitude!.toStringAsFixed(4)}, '
                                      '${alert.longitude!.toStringAsFixed(4)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  const SizedBox(height: 4),
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

  Widget _imageBadge(Color color) {
    final faceCount = alert.faceImageUrls.length;
    final hasFullFrame = alert.imageUrl.isNotEmpty;

    if (!_hasAnyImage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography_rounded,
              size: 10,
              color: Colors.grey.shade400,
            ),
            const SizedBox(width: 3),
            Text(
              'NO IMG',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    String label;
    IconData icon;

    if (alert.type == AlertType.group) {
      label = 'GROUP';
      icon = Icons.groups_rounded;
    } else if (faceCount > 0) {
      label = '${faceCount} FACE${faceCount > 1 ? 'S' : ''}';
      icon = Icons.face_rounded;
    } else if (hasFullFrame) {
      label = 'PHOTO';
      icon = Icons.photo_camera_rounded;
    } else {
      label = 'PHOTO';
      icon = Icons.photo_camera_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Color color) {
    if (_isVisualAlert) {
      if (alert.faceImageUrls.isNotEmpty) {
        return _NetworkImageAvatar(
          imageUrl: alert.faceImageUrls.first,
          color: color,
          size: 56,
        );
      }

      if (alert.imageUrl.isNotEmpty) {
        return _NetworkImageAvatar(
          imageUrl: alert.imageUrl,
          color: color,
          size: 56,
        );
      }

      return _noPhotoPlaceholder(color);
    }

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

  Widget _noPhotoPlaceholder(Color color) {
    final isGroup = alert.type == AlertType.group;

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
          Icon(
            isGroup ? Icons.groups_rounded : Icons.face_retouching_off_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            isGroup ? 'No\nGroup' : 'No\nPhoto',
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

  Color get _severityColor {
    switch (alert.type) {
      case AlertType.fire:
      case AlertType.intruder:
        return const Color(0xFFFF6B6B);
      case AlertType.smoke:
      case AlertType.unknownFace:
        return const Color(0xFFF59E0B);
      case AlertType.group:
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF45B7D1);
    }
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

class _NetworkImageAvatar extends StatelessWidget {
  final String imageUrl;
  final Color color;
  final double size;

  const _NetworkImageAvatar({
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
          headers: const {'Cache-Control': 'max-age=3600'},
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: color.withOpacity(0.1),
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
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                border: Border.all(
                  color: color.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_rounded,
                    color: color.withOpacity(0.6),
                    size: size * 0.35,
                  ),
                  Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 7,
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
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