import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  bool _notificationsEnabled = true;
  bool _fireAlerts = true;
  bool _smokeAlerts = true;
  bool _motionAlerts = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  bool _loadingPrefs = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    _loadPrefs();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  User? get _user => FirebaseAuth.instance.currentUser;

  DocumentReference<Map<String, dynamic>>? get _userDocRef {
    final u = _user;
    if (u == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  Future<void> _loadPrefs() async {
    final ref = _userDocRef;

    if (ref == null) {
      setState(() => _loadingPrefs = false);
      return;
    }

    try {
      final snap = await ref.get();
      final data = snap.data() ?? {};

      setState(() {
        _notificationsEnabled =
            (data['notifications_enabled'] ?? _notificationsEnabled) == true;
        _fireAlerts = (data['notify_fire'] ?? _fireAlerts) == true;
        _smokeAlerts = (data['notify_smoke'] ?? _smokeAlerts) == true;
        _motionAlerts = (data['notify_motion'] ?? _motionAlerts) == true;
        _soundEnabled = (data['notify_sound'] ?? _soundEnabled) == true;
        _vibrationEnabled =
            (data['notify_vibration'] ?? _vibrationEnabled) == true;

        _loadingPrefs = false;
      });

      await _applyTopicsFromState();
    } catch (_) {
      setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _savePrefs() async {
    final ref = _userDocRef;
    if (ref == null) return;

    await ref.set({
      'notifications_enabled': _notificationsEnabled,
      'notify_fire': _fireAlerts,
      'notify_smoke': _smokeAlerts,
      'notify_motion': _motionAlerts,
      'notify_sound': _soundEnabled,
      'notify_vibration': _vibrationEnabled,
      'prefs_updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _applyTopicsFromState() async {
    final fcm = FirebaseMessaging.instance;

    if (!_notificationsEnabled) {
      await fcm.unsubscribeFromTopic('alerts_all');
      await fcm.unsubscribeFromTopic('alerts_fire');
      await fcm.unsubscribeFromTopic('alerts_smoke');
      await fcm.unsubscribeFromTopic('alerts_motion');
      return;
    }

    await fcm.subscribeToTopic('alerts_all');

    if (_fireAlerts) {
      await fcm.subscribeToTopic('alerts_fire');
    } else {
      await fcm.unsubscribeFromTopic('alerts_fire');
    }

    if (_smokeAlerts) {
      await fcm.subscribeToTopic('alerts_smoke');
    } else {
      await fcm.unsubscribeFromTopic('alerts_smoke');
    }

    if (_motionAlerts) {
      await fcm.subscribeToTopic('alerts_motion');
    } else {
      await fcm.unsubscribeFromTopic('alerts_motion');
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    setState(() => _notificationsEnabled = value);

    if (!value) {
      setState(() {
        _fireAlerts = false;
        _smokeAlerts = false;
        _motionAlerts = false;
      });
    } else {
      setState(() {
        _fireAlerts = true;
        _smokeAlerts = true;
        _motionAlerts = true;
      });
    }

    await _savePrefs();
    await _applyTopicsFromState();
  }

  Future<void> _setFireAlerts(bool value) async {
    setState(() => _fireAlerts = value);
    await _savePrefs();
    await _applyTopicsFromState();
  }

  Future<void> _setSmokeAlerts(bool value) async {
    setState(() => _smokeAlerts = value);
    await _savePrefs();
    await _applyTopicsFromState();
  }

  Future<void> _setMotionAlerts(bool value) async {
    setState(() => _motionAlerts = value);
    await _savePrefs();
    await _applyTopicsFromState();
  }

  Future<void> _setSoundEnabled(bool value) async {
    setState(() => _soundEnabled = value);
    await _savePrefs();
  }

  Future<void> _setVibrationEnabled(bool value) async {
    setState(() => _vibrationEnabled = value);
    await _savePrefs();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _loadingPrefs;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF1F2937),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionHeader('Notifications', Icons.notifications_rounded),
            const SizedBox(height: 16),

            _buildSwitchTile(
              'Enable Notifications',
              'Receive push notifications',
              _notificationsEnabled,
              disabled ? null : (value) => _setNotificationsEnabled(value),
            ),
            const SizedBox(height: 12),

            _buildSwitchTile(
              'Fire Alerts',
              'Get notified about fire detection',
              _fireAlerts,
              (!_notificationsEnabled || disabled)
                  ? null
                  : (value) => _setFireAlerts(value),
              enabled: _notificationsEnabled && !disabled,
            ),
            const SizedBox(height: 12),

            _buildSwitchTile(
              'Smoke Alerts',
              'Get notified about smoke detection',
              _smokeAlerts,
              (!_notificationsEnabled || disabled)
                  ? null
                  : (value) => _setSmokeAlerts(value),
              enabled: _notificationsEnabled && !disabled,
            ),
            const SizedBox(height: 12),

            _buildSwitchTile(
              'Motion Alerts',
              'Get notified about motion detection',
              _motionAlerts,
              (!_notificationsEnabled || disabled)
                  ? null
                  : (value) => _setMotionAlerts(value),
              enabled: _notificationsEnabled && !disabled,
            ),

            const SizedBox(height: 32),

            _buildSectionHeader('Sound & Vibration', Icons.volume_up_rounded),
            const SizedBox(height: 16),

            _buildSwitchTile(
              'Sound',
              'Play sound for notifications',
              _soundEnabled,
              disabled ? null : (value) => _setSoundEnabled(value),
            ),
            const SizedBox(height: 12),

            _buildSwitchTile(
              'Vibration',
              'Vibrate for notifications',
              _vibrationEnabled,
              disabled ? null : (value) => _setVibrationEnabled(value),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged, {
    bool enabled = true,
  }) {
    final effectiveEnabled = enabled && onChanged != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: effectiveEnabled
                        ? const Color(0xFF1F2937)
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: effectiveEnabled
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: effectiveEnabled ? onChanged : null,
              activeThumbColor: const Color(0xFF06B6D4),
              activeTrackColor: const Color(0xFF06B6D4).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDestructive
                      ? const Color(0xFFFF6B6B).withOpacity(0.1)
                      : const Color(0xFF06B6D4).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF06B6D4),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDestructive
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDestructive
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF06B6D4),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF1F2937),
          ),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await _authService.signOut();
              if (!context.mounted) return;

              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              ).createShader(bounds),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
