// ─────────────────────────────────────────────────────────────────────────────
// Data model for a gallery image entry
// ─────────────────────────────────────────────────────────────────────────────
import '../models/alert_model.dart';

class GalleryImageItem {
  final String imageUrl;
  final String label; // e.g. "Unknown Person", "Fire", "Smoke"
  final String alertId;
  final DateTime timestamp;
  final AlertType alertType;
  final String lens;
  final String note;
  final bool isFaceCrop; // true = face crop, false = full frame

  const GalleryImageItem({
    required this.imageUrl,
    required this.label,
    required this.alertId,
    required this.timestamp,
    required this.alertType,
    required this.lens,
    required this.note,
    required this.isFaceCrop,
  });
}
