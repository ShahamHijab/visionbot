import 'package:flutter/material.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const VisionBotApp());
}

class VisionBotApp extends StatelessWidget {
  const VisionBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Bot',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
