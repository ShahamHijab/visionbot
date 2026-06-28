import 'package:mad_project/widgets/visionbot_app_bar.dart';
import 'package:flutter/material.dart';
import '../../widgets/visionbot_app_bar.dart';

class ImageDetailScreen extends StatelessWidget {
  const ImageDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final title = (args?['title'] ?? 'Image').toString();
    final time = (args?['time'] ?? '').toString();
    final asset = (args?['asset'] ?? '').toString();
    final type = (args?['type'] ?? '').toString();
    final camera = (args?['camera'] ?? '').toString();
    final location = (args?['location'] ?? '').toString();
    final confidence = (args?['confidence'] ?? '').toString();
    final description = (args?['description'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: VisionBotAppBar(
        pageTitle: title,
        pageSubtitle: 'Image Details',
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1F2937),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: 1,
                child: asset.startsWith('http')
                    ? Image.network(
                        asset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 56),
                            ),
                          );
                        },
                      )
                    : Image.asset(
                        asset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded, size: 56),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),

            _row(title, time, bold: true),
            const SizedBox(height: 12),

            _infoCard('Type', type),
            _infoCard('Camera', camera),
            _infoCard('Location', location),
            _infoCard('Confidence', confidence),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Text(description),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String title, String time, {bool bold = false}) {
    return Text(
      '$title $time',
      style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
    );
  }

  Widget _infoCard(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}
