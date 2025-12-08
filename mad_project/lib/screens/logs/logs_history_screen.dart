import 'package:flutter/material.dart';

class LogsHistoryScreen extends StatelessWidget {
  const LogsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs & History')),
      body: const Center(child: Text('Logs History Screen')),
    );
  }
}