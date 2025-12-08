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
  }) : notificationPreferences = notificationPreferences ?? {
          'fire': true,
          'smoke': true,
          'human': true,
          'motion': true,
          'restricted': true,
        };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${json['role']}',
        orElse: () => UserRole.securityOfficer,
      ),
      phoneNumber: json['phoneNumber'],
      avatarUrl: json['avatarUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      notificationPreferences: json['notificationPreferences'] != null
          ? Map<String, bool>.from(json['notificationPreferences'])
          : null,
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
      notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    );
  }
}

enum UserRole {
  admin,
  securityOfficer,
}

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
        return 'Monitor alerts and surveillance';
    }
  }
}