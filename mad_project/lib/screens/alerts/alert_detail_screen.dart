import 'package:flutter/material.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: const Center(child: Text('Alert Detail Screen')),
    );
  }
}