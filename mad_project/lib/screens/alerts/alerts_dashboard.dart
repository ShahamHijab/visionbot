import 'package:flutter/material.dart';

class AlertsDashboard extends StatelessWidget {
  const AlertsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts Dashboard')),
      body: const Center(child: Text('Alerts Dashboard Screen')),
    );
  }
}