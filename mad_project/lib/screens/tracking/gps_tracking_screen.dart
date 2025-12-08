import 'package:flutter/material.dart';

class GPSTrackingScreen extends StatelessWidget {
  const GPSTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPS Tracking')),
      body: const Center(child: Text('GPS Tracking Screen')),
    );
  }
}
