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
      'title': 'Group',
      'time': 'Yesterday',
      'asset': 'assets/group.jfif',
      'type': 'Crowd Detection',
      'camera': 'Camera 4',
      'location': 'Main Entrance',
      'confidence': '78%',
      'description': 'Multiple people detected near entrance',
    },
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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Image Gallery',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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

                // Enhanced gradient overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),

                // Bottom label with gradient accent
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.3),
                        width: 1,
                      ),
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
