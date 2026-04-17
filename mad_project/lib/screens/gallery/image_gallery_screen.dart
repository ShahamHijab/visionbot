import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../models/gallery_image_item.dart';
import '../../services/alert_service.dart';

class ImageGalleryScreen extends StatefulWidget {
  const ImageGalleryScreen({super.key});

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen>
    with SingleTickerProviderStateMixin {
  final AlertService _alertService = AlertService();

  AlertType? _filterType;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // LABELS
  // ─────────────────────────────────────────────────────────────
  String _labelFor(AlertType type, {required bool isFace}) {
    switch (type) {
      case AlertType.fire:
        return 'Fire';
      case AlertType.smoke:
        return 'Smoke';
      case AlertType.group:
        return 'Group'; // ✅ FIX
      case AlertType.human:
        return 'Person';
      case AlertType.motion:
        return 'Motion';
      case AlertType.restricted:
        return 'Restricted';
      case AlertType.unknownFace:
        return 'Unknown Person';
      case AlertType.knownFace:
        return 'Known Person';
      case AlertType.intruder:
        return 'Intruder';
      case AlertType.other:
        return 'Alert';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // COLORS
  // ─────────────────────────────────────────────────────────────
  Color _colorFor(AlertType type) {
    switch (type) {
      case AlertType.fire:
        return const Color(0xFFFF6B6B);
      case AlertType.smoke:
        return const Color(0xFFF59E0B);
      case AlertType.group:
        return const Color(0xFF10B981); // ✅ FIX (green)
      case AlertType.unknownFace:
      case AlertType.intruder:
        return const Color(0xFFEC4899);
      case AlertType.knownFace:
        return const Color(0xFF4ECDC4);
      case AlertType.human:
        return const Color(0xFF45B7D1);
      case AlertType.motion:
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF06B6D4);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ICONS
  // ─────────────────────────────────────────────────────────────
  IconData _iconFor(AlertType type) {
    switch (type) {
      case AlertType.fire:
        return Icons.local_fire_department_rounded;
      case AlertType.smoke:
        return Icons.cloud_rounded;
      case AlertType.group:
        return Icons.groups_rounded; // ✅ FIX
      case AlertType.unknownFace:
        return Icons.person_off_rounded;
      case AlertType.knownFace:
        return Icons.verified_user_rounded;
      case AlertType.human:
        return Icons.person_rounded;
      case AlertType.motion:
        return Icons.directions_run_rounded;
      case AlertType.intruder:
        return Icons.security_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ─────────────────────────────────────────────────────────────
  // FILTER TYPES
  // ─────────────────────────────────────────────────────────────
  static const _filterTypes = [
    null,
    AlertType.fire,
    AlertType.smoke,
    AlertType.group, // ✅ FIX
    AlertType.unknownFace,
    AlertType.knownFace,
    AlertType.human,
    AlertType.motion,
    AlertType.intruder,
  ];

  String _filterLabel(AlertType? t) {
    if (t == null) return 'All';
    return _labelFor(t, isFace: false);
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD ITEMS
  // ─────────────────────────────────────────────────────────────
  List<GalleryImageItem> _buildItems(List<AlertModel> alerts) {
    final items = <GalleryImageItem>[];

    for (final alert in alerts) {
      // FACE CROPS
      for (final url in alert.faceImageUrls) {
        if (url.isNotEmpty) {
          items.add(
            GalleryImageItem(
              imageUrl: url,
              label: _labelFor(alert.type, isFace: true),
              alertId: alert.id,
              timestamp: alert.timestamp,
              alertType: alert.type,
              lens: alert.lens,
              note: alert.note,
              isFaceCrop: true,
            ),
          );
        }
      }

      // MAIN IMAGE (IMPORTANT FOR GROUP)
      if (alert.imageUrl.isNotEmpty &&
          !alert.faceImageUrls.contains(alert.imageUrl)) {
        items.add(
          GalleryImageItem(
            imageUrl: alert.imageUrl,
            label: _labelFor(alert.type, isFace: false),
            alertId: alert.id,
            timestamp: alert.timestamp,
            alertType: alert.type,
            lens: alert.lens,
            note: alert.note,
            isFaceCrop: false,
          ),
        );
      }
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  // ─────────────────────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Image Gallery"),
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertService.streamAlerts(limit: 200),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data ?? [];
          final items = _buildItems(alerts);

          final filtered = _filterType == null
              ? items
              : items.where((i) => i.alertType == _filterType).toList();

          return Column(
            children: [
              _buildFilterRow(items),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text("No images"))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return Image.network(item.imageUrl,
                              fit: BoxFit.cover);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterRow(List<GalleryImageItem> items) {
    final availableTypes = <AlertType?>{null};
    for (final item in items) {
      availableTypes.add(item.alertType);
    }

    final visibleFilters =
        _filterTypes.where((t) => availableTypes.contains(t)).toList();

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: visibleFilters.length,
        itemBuilder: (context, index) {
          final type = visibleFilters[index];
          return GestureDetector(
            onTap: () => setState(() => _filterType = type),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(label: Text(_filterLabel(type))),
            ),
          );
        },
      ),
    );
  }
}