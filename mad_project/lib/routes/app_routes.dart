import 'package:flutter/material.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/role_selection_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/alerts/alerts_dashboard.dart';
import '../screens/alerts/alert_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/change_password_screen.dart';
import '../screens/gallery/image_gallery_screen.dart';
import '../screens/gallery/image_detail_screen.dart';
import '../screens/tracking/gps_tracking_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/logs/logs_history_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/settings/user_guide_screen.dart';
import '../screens/auth/verify_email_screen.dart';

class AppRoutes {
  // Auth Routes
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String roleSelection = '/role-selection';
  static const String verifyEmail = '/verify-email';

  // Main Routes
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';
  static const String changePassword = '/change-password';

  // Alert Routes
  static const String alerts = '/alerts';
  static const String alertDetail = '/alert-detail';

  // Gallery Routes
  static const String gallery = '/gallery';
  static const String imageDetail = '/image-detail';

  // Tracking Routes
  static const String tracking = '/tracking';

  // Notification Routes
  static const String notifications = '/notifications';

  // Logs Routes
  static const String logs = '/logs';

  // Settings Routes
  static const String settings = '/settings';
  static const String about = '/about';
  static const String userGuide = '/user-guide';

  static Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    roleSelection: (_) => const RoleSelectionScreen(),
    dashboard: (_) => const DashboardScreen(),
    profile: (_) => const ProfileScreen(),
    changePassword: (_) => const ChangePasswordScreen(),
    alerts: (_) => const AlertsDashboard(),
    alertDetail: (_) => const AlertDetailScreen(),
    gallery: (_) => const ImageGalleryScreen(),
    imageDetail: (_) => const ImageDetailScreen(),
    tracking: (_) => const GPSTrackingScreen(),
    notifications: (_) => const NotificationsScreen(),
    logs: (_) => const LogsHistoryScreen(),
    settings: (_) => const SettingsScreen(),
    about: (_) => const AboutScreen(),
    userGuide: (_) => const UserGuideScreen(),
    verifyEmail: (_) => const VerifyEmailScreen(),
  };
}
