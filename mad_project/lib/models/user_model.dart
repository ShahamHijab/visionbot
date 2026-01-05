import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phoneNumber;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool notificationsEnabled;
  final Map<String, bool> notificationPreferences;
  final UserPermissions permissions;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
    this.avatarUrl,
    required this.createdAt,
    this.notificationsEnabled = true,
    Map<String, bool>? notificationPreferences,
    UserPermissions? permissions,
  }) : notificationPreferences =
           notificationPreferences ??
           {
             'fire': true,
             'smoke': true,
             'human': true,
             'motion': true,
             'restricted': true,
           },
       permissions = permissions ?? UserPermissions.fromRole(role);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = UserRole.values.firstWhere(
      (e) => e.toString() == 'UserRole.${json['role']}',
      orElse: () => UserRole.securityOfficer,
    );

    // Handle createdAt which could be a Timestamp or String
    DateTime createdAt;
    try {
      final createdAtValue = json['createdAt'];
      if (createdAtValue == null) {
        createdAt = DateTime.now();
      } else if (createdAtValue is Timestamp) {
        createdAt = createdAtValue.toDate();
      } else if (createdAtValue is String) {
        createdAt = DateTime.parse(createdAtValue);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: role,
      phoneNumber: json['phoneNumber'],
      avatarUrl: json['avatarUrl'],
      createdAt: createdAt,
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      notificationPreferences: json['notificationPreferences'] != null
          ? Map<String, bool>.from(json['notificationPreferences'])
          : null,
      permissions: json['permissions'] != null
          ? UserPermissions.fromJson(json['permissions'])
          : UserPermissions.fromRole(role),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'phoneNumber': phoneNumber,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'notificationsEnabled': notificationsEnabled,
      'notificationPreferences': notificationPreferences,
      'permissions': permissions.toJson(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? phoneNumber,
    String? avatarUrl,
    DateTime? createdAt,
    bool? notificationsEnabled,
    Map<String, bool>? notificationPreferences,
    UserPermissions? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      permissions: permissions ?? this.permissions,
    );
  }
}

enum UserRole { admin, securityOfficer }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.securityOfficer:
        return 'Security Officer';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin:
        return 'Full system access and management';
      case UserRole.securityOfficer:
        return 'Monitor alerts and respond to incidents';
    }
  }
}

class UserPermissions {
  // Login & Dashboard
  final bool canAccessDashboard;

  // Live Camera Feed
  final bool canViewLiveCameraFeed;

  // Smoke Detection Alerts
  final bool canReceiveSmokeAlerts;

  // Unauthorized Person Alerts
  final bool canReceiveUnauthorizedPersonAlerts;

  // View Detected Face Images
  final bool canViewDetectedFaceImages;

  // Face Verification Review
  final bool canPerformFaceVerification;

  // GPS Location Tracking
  final bool canAccessGPSTracking;

  // Alert & Event Logs
  final bool canViewAlertLogs;

  UserPermissions({
    required this.canAccessDashboard,
    required this.canViewLiveCameraFeed,
    required this.canReceiveSmokeAlerts,
    required this.canReceiveUnauthorizedPersonAlerts,
    required this.canViewDetectedFaceImages,
    required this.canPerformFaceVerification,
    required this.canAccessGPSTracking,
    required this.canViewAlertLogs,
  });

  factory UserPermissions.fromRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return UserPermissions(
          canAccessDashboard: true,
          canViewLiveCameraFeed: true,
          canReceiveSmokeAlerts: true,
          canReceiveUnauthorizedPersonAlerts: true,
          canViewDetectedFaceImages: true,
          canPerformFaceVerification: true,
          canAccessGPSTracking: true,
          canViewAlertLogs: true,
        );
      case UserRole.securityOfficer:
        return UserPermissions(
          canAccessDashboard: true,
          canViewLiveCameraFeed: false, // Alerts only
          canReceiveSmokeAlerts: true,
          canReceiveUnauthorizedPersonAlerts: true,
          canViewDetectedFaceImages: true,
          canPerformFaceVerification: true,
          canAccessGPSTracking: true,
          canViewAlertLogs: true,
        );
    }
  }

  factory UserPermissions.fromJson(Map<String, dynamic> json) {
    return UserPermissions(
      canAccessDashboard: json['canAccessDashboard'] ?? true,
      canViewLiveCameraFeed: json['canViewLiveCameraFeed'] ?? false,
      canReceiveSmokeAlerts: json['canReceiveSmokeAlerts'] ?? true,
      canReceiveUnauthorizedPersonAlerts:
          json['canReceiveUnauthorizedPersonAlerts'] ?? true,
      canViewDetectedFaceImages: json['canViewDetectedFaceImages'] ?? true,
      canPerformFaceVerification: json['canPerformFaceVerification'] ?? true,
      canAccessGPSTracking:
          json['canAccessGPSTracking'] ?? true, // Default to true
      canViewAlertLogs: json['canViewAlertLogs'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canAccessDashboard': canAccessDashboard,
      'canViewLiveCameraFeed': canViewLiveCameraFeed,
      'canReceiveSmokeAlerts': canReceiveSmokeAlerts,
      'canReceiveUnauthorizedPersonAlerts': canReceiveUnauthorizedPersonAlerts,
      'canViewDetectedFaceImages': canViewDetectedFaceImages,
      'canPerformFaceVerification': canPerformFaceVerification,
      'canAccessGPSTracking': canAccessGPSTracking,
      'canViewAlertLogs': canViewAlertLogs,
    };
  }
}
