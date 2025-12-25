import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const VisionBotApp());
}

class VisionBotApp extends StatelessWidget {
  const VisionBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Bot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}


// import 'package:flutter/material.dart';
// import 'routes/app_routes.dart';
// import 'theme/app_theme.dart';

// void main() {
//   runApp(const VisionBotApp());
// }

// class VisionBotApp extends StatelessWidget {
//   const VisionBotApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Vision Bot',
//       debugShowCheckedModeBanner: false,
//       theme: AppTheme.lightTheme,
//       initialRoute: AppRoutes.splash,
//       routes: AppRoutes.routes,
//     );
//   }
// }