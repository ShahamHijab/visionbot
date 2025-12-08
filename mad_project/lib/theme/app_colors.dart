import 'package:flutter/material.dart';

class AppColors {
  // Primary Gradient Colors
  static const Color gradientStart = Color(0xFFB800FF); // Purple
  static const Color gradientEnd = Color(0xFF7EE8FA); // Cyan
  static const Color gradientMiddle = Color(0xFFCE77FF); // Pink-Purple

  // Background Colors
  static const Color background = Colors.white;
  static const Color cardBackground = Colors.white;
  static const Color scaffoldBackground = Color(0xFFF8F9FA);

  // Text Colors
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Colors.black54;
  static const Color textLight = Colors.white;
  static const Color textHint = Colors.black38;

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderActive = Color(0xFFB800FF);

  // Alert/Severity Colors
  static const Color critical = Color(0xFFFF3B30); // Red
  static const Color warning = Color(0xFFFF9500); // Orange
  static const Color info = Color(0xFF007AFF); // Blue
  static const Color success = Color(0xFF34C759); // Green

  // Alert Type Colors
  static const Color fireAlert = Color(0xFFFF4444);
  static const Color smokeAlert = Color(0xFF9E9E9E);
  static const Color humanAlert = Color(0xFFFF9800);
  static const Color motionAlert = Color(0xFF2196F3);
  static const Color restrictedAlert = Color(0xFFE91E63);

  // Status Colors
  static const Color active = Color(0xFF4CAF50);
  static const Color inactive = Color(0xFF9E9E9E);
  static const Color charging = Color(0xFFFFC107);
  static const Color alertStatus = Color(0xFFFF5722);

  // UI Element Colors
  static const Color iconColor = Colors.black54;
  static const Color iconActiveColor = Color(0xFFB800FF);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);

  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFCE77FF), // pink-purple
      Color(0xFF8BB0FF),
      Color(0xFF7EE8FA), // cyan
    ],
  );

  // Shimmer Colors
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
}