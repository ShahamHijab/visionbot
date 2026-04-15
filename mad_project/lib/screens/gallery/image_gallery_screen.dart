import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../models/gallery_image_item.dart';
import '../../services/alert_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Main Gallery Screen
// ─────────────────────────────────────────────────────────────────────────────
class ImageGalleryScreen extends StatefulWidget {
  const ImageGalleryScreen({super.key});

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen>
    with SingleTickerProviderStateMixin {
  final AlertService _alertService = AlertService();

  // Filter: null = All
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
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _labelFor(AlertType type, {required bool isFace}) {
    switch (type) {
      case AlertType.fire:
        return 'Fire';
      case AlertType.smoke:
        return 'Smoke';
      case AlertType.human:
        return 'Person';
      case AlertType.motion:
        return 'Motion';
      case AlertType.restricted:
        return 'Restricted';
      case AlertType.unknownFace:
        return isFace ? 'Unknown Person' : 'Unknown Person';
      case AlertType.knownFace:
        return isFace ? 'Known Person' : 'Known Person';
      case AlertType.intruder:
        return 'Intruder';
      case AlertType.other:
        return 'Alert';
    }
  }

  Color _colorFor(AlertType type) {
    switch (type) {
      case AlertType.fire:
        return const Color(0xFFFF6B6B);
      case AlertType.smoke:
        return const Color(0xFFF59E0B);
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

  IconData _iconFor(AlertType type) {
    switch (type) {
      case AlertType.fire:
        return Icons.local_fire_department_rounded;
      case AlertType.smoke:
        return Icons.cloud_rounded;
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

  // ── Filter chips ──────────────────────────────────────────────────────────
  static const _filterTypes = [
    null, // All
    AlertType.fire,
    AlertType.smoke,
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

  List<GalleryImageItem> _buildItems(List<AlertModel> alerts) {
    final items = <GalleryImageItem>[];

    for (final alert in alerts) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(b),
          child: const Text(
            'Image Gallery',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
      body: StreamBuilder<List<AlertModel>>(
        stream: _alertService.streamAlerts(limit: 200),
        builder: (context, snapshot) {
          // ── Loading ───────────────────────────────────────────────────────
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ── Error ─────────────────────────────────────────────────────────
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFFF6B6B),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load images',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final allAlerts = snapshot.data ?? [];
          final allItems = _buildItems(allAlerts);

          // Apply filter
          final filtered = _filterType == null
              ? allItems
              : allItems.where((i) => i.alertType == _filterType).toList();

          return FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // ── Filter chips ──────────────────────────────────────────
                _buildFilterRow(allItems),

                // ── Count banner ──────────────────────────────────────────
                if (allItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_library_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${filtered.length} image${filtered.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Grid ─────────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmpty()
                      : _buildGrid(filtered),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Filter row ────────────────────────────────────────────────────────────
  Widget _buildFilterRow(List<GalleryImageItem> allItems) {
    // Only show filter types that have images
    final availableTypes = <AlertType?>{null};
    for (final item in allItems) {
      availableTypes.add(item.alertType);
    }

    return Container(
      height: 56,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filterTypes.where((t) => availableTypes.contains(t)).length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filtered = _filterTypes
              .where((t) => availableTypes.contains(t))
              .toList();
          final type = filtered[index];
          final isSelected = _filterType == type;
          final color = type == null
              ? const Color(0xFF06B6D4)
              : _colorFor(type);

          return GestureDetector(
            onTap: () => setState(() => _filterType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                    : null,
                color: isSelected ? null : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (type != null)
                    Icon(
                      _iconFor(type),
                      size: 13,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  if (type != null) const SizedBox(width: 5),
                  Text(
                    _filterLabel(type),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Grid ──────────────────────────────────────────────────────────────────
  Widget _buildGrid(List<GalleryImageItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.88,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _GalleryTile(
          item: items[index],
          color: _colorFor(items[index].alertType),
          icon: _iconFor(items[index].alertType),
          timeAgo: _timeAgo(items[index].timestamp),
          onTap: () => _showFullscreen(context, items, index),
        );
      },
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF06B6D4).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              size: 64,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _filterType == null ? 'No Images Yet' : 'No Images Found',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterType == null
                ? 'Alert images will appear here once\nyour system detects events.'
                : 'No images for this filter type.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── Fullscreen viewer ─────────────────────────────────────────────────────
  void _showFullscreen(
    BuildContext context,
    List<GalleryImageItem> items,
    int startIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullscreenGallery(
          items: items,
          initialIndex: startIndex,
          colorFor: _colorFor,
          iconFor: _iconFor,
          timeAgo: _timeAgo,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual gallery tile
// ─────────────────────────────────────────────────────────────────────────────
class _GalleryTile extends StatelessWidget {
  final GalleryImageItem item;
  final Color color;
  final IconData icon;
  final String timeAgo;
  final VoidCallback onTap;

  const _GalleryTile({
    required this.item,
    required this.color,
    required this.icon,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Image ───────────────────────────────────────────────
                Image.network(
                  item.imageUrl,
                  fit: BoxFit.cover,
                  headers: const {'Cache-Control': 'max-age=3600'},
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: color.withOpacity(0.1),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                    progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: color.withOpacity(0.08),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_rounded,
                          color: color.withOpacity(0.5),
                          size: 36,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No image',
                          style: TextStyle(
                            fontSize: 11,
                            color: color.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Gradient overlay ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.65),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),

                // ── Top badge (face crop indicator) ─────────────────────
                if (item.isFaceCrop)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'FACE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),

                // ── Bottom label ─────────────────────────────────────────
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Type label with icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(icon, color: Colors.white, size: 11),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Time
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fullscreen gallery with swipe navigation
// ─────────────────────────────────────────────────────────────────────────────
class _FullscreenGallery extends StatefulWidget {
  final List<GalleryImageItem> items;
  final int initialIndex;
  final Color Function(AlertType) colorFor;
  final IconData Function(AlertType) iconFor;
  final String Function(DateTime) timeAgo;

  const _FullscreenGallery({
    required this.items,
    required this.initialIndex,
    required this.colorFor,
    required this.iconFor,
    required this.timeAgo,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final color = widget.colorFor(item.alertType);
    final icon = widget.iconFor(item.alertType);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.8),
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.items.length}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Swipeable image viewer ──────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, index) {
                final img = widget.items[index];
                return InteractiveViewer(
                  child: Center(
                    child: Image.network(
                      img.imageUrl,
                      fit: BoxFit.contain,
                      headers: const {'Cache-Control': 'max-age=3600'},
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      },
                      errorBuilder: (_, __, ___) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Image unavailable',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Info panel ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              border: Border(
                top: BorderSide(color: color.withOpacity(0.4), width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type + time row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 13),
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (item.isFaceCrop) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text(
                                'FACE CROP',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.timeAgo(item.timestamp),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (item.lens.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.camera_alt_rounded,
                        size: 13,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lens: ${item.lens}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 13,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.note,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Thumbnail strip ──────────────────────────────────────
                const SizedBox(height: 14),
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isActive = index == _currentIndex;
                      final thumb = widget.items[index];
                      final thumbColor = widget.colorFor(thumb.alertType);
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive ? thumbColor : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              thumb.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: thumbColor.withOpacity(0.2),
                                child: Icon(
                                  widget.iconFor(thumb.alertType),
                                  color: thumbColor,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
