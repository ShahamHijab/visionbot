import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';

class ImageGalleryScreen extends StatelessWidget {
  const ImageGalleryScreen({super.key});

  static const List<Map<String, dynamic>> _demoImages = [
    {
      'title': 'Fire',
      'time': '2 mins ago',
      'asset': 'assets/fire.jfif',
      'type': 'Fire Detection',
      'camera': 'Camera 1',
      'location': 'Building A, Floor 2',
      'confidence': '92%',
      'description': 'Fire detected near electrical panel',
    },
    {
      'title': 'Person',
      'time': '15 mins ago',
      'asset': 'assets/person.jfif',
      'type': 'Human Detection',
      'camera': 'Camera 3',
      'location': 'Restricted Zone',
      'confidence': '87%',
      'description': 'Unknown person detected in restricted area',
    },
    {
      'title': 'Fire',
      'time': '1 hour ago',
      'asset': 'assets/fire.jfif',
      'type': 'Fire Detection',
      'camera': 'Camera 2',
      'location': 'Parking Area',
      'confidence': '90%',
      'description': 'Smoke and flames detected',
    },
    {
      'title': 'Group',
      'time': 'Yesterday',
      'asset': 'assets/group.jfif',
      'type': 'Crowd Detection',
      'camera': 'Camera 4',
      'location': 'Main Entrance',
      'confidence': '78%',
      'description': 'Multiple people detected near entrance',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Gallery')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: _demoImages.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final item = _demoImages[index];
            final title = (item['title'] ?? 'Camera').toString();
            final time = (item['time'] ?? '').toString();
            final asset = (item['asset'] ?? '').toString();

            return _GalleryTile(
              title: title,
              time: time,
              assetPath: asset,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.imageDetail,
                  arguments: item,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String title;
  final String time;
  final String assetPath;
  final VoidCallback onTap;

  const _GalleryTile({
    required this.title,
    required this.time,
    required this.assetPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image background
                Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded, size: 40),
                      ),
                    );
                  },
                ),

                // Soft dark overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.05),
                        Colors.black.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),

                // Bottom label
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
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
