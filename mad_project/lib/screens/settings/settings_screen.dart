// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFEC4899), Color(0xFF06B6D4)],
          ).createShader(bounds),
          child: const Text(
            'Settings',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Notifications Section
            _buildSectionHeader('Notifications', Icons.notifications_rounded),
            const SizedBox(height: 16),
            _buildSwitchTile(
              'Enable Notifications',
              'Receive push notifications',
              _notificationsEnabled,
              (value) => setState(() => _notificationsEnabled = value),
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              'Fire Alerts',
              'Get notified about fire detection',
              _fireAlerts,
              (value) => setState(() => _fireAlerts = value),
              enabled: _notificationsEnabled,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              'Smoke Alerts',
              'Get notified about smoke detection',
              _smokeAlerts,
              (value) => setState(() => _smokeAlerts = value),
              enabled: _notificationsEnabled,
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              'Motion Alerts',
              'Get notified about motion detection',
              _motionAlerts,
              (value) => setState(() => _motionAlerts = value),
              enabled: _notificationsEnabled,
            ),
            
            const SizedBox(height: 32),
            
            // Sound & Vibration Section
            _buildSectionHeader('Sound & Vibration', Icons.volume_up_rounded),
            const SizedBox(height: 16),
            _buildSwitchTile(
              'Sound',
              'Play sound for notifications',
              _soundEnabled,
              (value) => setState(() => _soundEnabled = value),
            ),
            const SizedBox(height: 12),
            _buildSwitchTile(
              'Vibration',
              'Vibrate for notifications',
              _vibrationEnabled,
              (value) => setState(() => _vibrationEnabled = value),
            ),
            
            const SizedBox(height: 32),
            
            // App Section
            _buildSectionHeader('App', Icons.phone_android_rounded),
            const SizedBox(height: 16),
            _buildNavigationTile(
              'About',
              'App version and information',
              Icons.info_outline_rounded,
              () => Navigator.pushNamed(context, AppRoutes.about),
            ),
            const SizedBox(height: 12),
            _buildNavigationTile(
              'User Guide',
              'Learn how to use the app',
              Icons.help_outline_rounded,
              () => Navigator.pushNamed(context, AppRoutes.userGuide),
            ),
            
            const SizedBox(height: 32),
            
            // Account Section
            _buildSectionHeader('Account', Icons.person_outline_rounded),
            const SizedBox(height: 16),
            _buildNavigationTile(
              'Logout',
              'Sign out of your account',
              Icons.logout_rounded,
              () => _showLogoutDialog(),
              isDestructive: true,
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
    ValueChanged<bool> onChanged, {
    bool enabled = true,
  }) {
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
                    color: enabled ? const Color(0xFF1F2937) : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeColor: const Color(0xFF06B6D4),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
            child: const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}