// lib/services/permission_service.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class PermissionService {
  final AuthService _authService = AuthService();

  Future<UserPermissions?> getCurrentUserPermissions() async {
    try {
      final userData = await _authService.getCurrentUserData();
      return userData?.permissions;
    } catch (e) {
      debugPrint('Error getting permissions: $e');
      return null;
    }
  }

  Future<bool> hasPermission(String permissionKey) async {
    try {
      final permissions = await getCurrentUserPermissions();
      if (permissions == null) return false;

      switch (permissionKey) {
        case 'dashboard':
          return permissions.canAccessDashboard;
        case 'live_camera':
          return permissions.canViewLiveCameraFeed;
        case 'smoke_alerts':
          return permissions.canReceiveSmokeAlerts;
        case 'unauthorized_alerts':
          return permissions.canReceiveUnauthorizedPersonAlerts;
        case 'face_images':
          return permissions.canViewDetectedFaceImages;
        case 'face_verification':
          return permissions.canPerformFaceVerification;
        case 'gps_tracking':
          return permissions.canAccessGPSTracking;
        case 'alert_logs':
          return permissions.canViewAlertLogs;
        default:
          return false;
      }
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Color(0xFFFF6B6B),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Access Denied',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: const Text(
          'You do not have permission to access this feature. Please contact your administrator.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}