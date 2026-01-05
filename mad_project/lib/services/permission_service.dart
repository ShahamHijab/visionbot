import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class PermissionService {
  final AuthService _authService = AuthService();
  UserPermissions? _cachedPermissions;
  String? _cachedUserId;

  Future<UserPermissions?> getCurrentUserPermissions() async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        debugPrint('No current user for permission check');
        return null;
      }

      // Use cache if user hasn't changed
      if (_cachedUserId == currentUser.uid && _cachedPermissions != null) {
        return _cachedPermissions;
      }

      final userData = await _authService.getCurrentUserData();
      if (userData == null) {
        debugPrint('No user data found for permission check');
        return null;
      }

      _cachedUserId = currentUser.uid;
      _cachedPermissions = userData.permissions;

      debugPrint(
        'Loaded permissions for user ${currentUser.email}: '
        'dashboard=${userData.permissions.canAccessDashboard}, '
        'gps=${userData.permissions.canAccessGPSTracking}, '
        'live_camera=${userData.permissions.canViewLiveCameraFeed}',
      );

      return userData.permissions;
    } catch (e) {
      debugPrint('Error getting permissions: $e');
      return null;
    }
  }

  // Clear cache when user logs out
  void clearCache() {
    _cachedPermissions = null;
    _cachedUserId = null;
  }

  Future<bool> hasPermission(String permissionKey) async {
    try {
      final permissions = await getCurrentUserPermissions();
      if (permissions == null) {
        debugPrint('No permissions found for key: $permissionKey');
        return false;
      }

      final hasAccess = switch (permissionKey) {
        'dashboard' => permissions.canAccessDashboard,
        'live_camera' => permissions.canViewLiveCameraFeed,
        'smoke_alerts' => permissions.canReceiveSmokeAlerts,
        'unauthorized_alerts' => permissions.canReceiveUnauthorizedPersonAlerts,
        'face_images' => permissions.canViewDetectedFaceImages,
        'face_verification' => permissions.canPerformFaceVerification,
        'gps_tracking' => permissions.canAccessGPSTracking,
        'alert_logs' => permissions.canViewAlertLogs,
        _ => false,
      };

      debugPrint('Permission check [$permissionKey]: $hasAccess');
      return hasAccess;
    } catch (e) {
      debugPrint('Error checking permission [$permissionKey]: $e');
      return false;
    }
  }

  void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'You do not have permission to access this feature. Please contact your administrator.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
