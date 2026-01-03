import 'package:flutter/material.dart';

class ImageGalleryScreen extends StatelessWidget {
  const ImageGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Gallery')),
      body: const Center(child: Text('Image Gallery Screen')),
    );
  }
}
