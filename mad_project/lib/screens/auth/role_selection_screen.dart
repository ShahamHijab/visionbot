import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  final AuthService _authService = AuthService();

  String _mapRole(String role) {
    if (role == 'officer') return 'securityOfficer';
    return role;
  }

  Future<void> _handleContinue() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a role to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final fromGoogle = (args?['fromGoogle'] == true);

    final roleToSave = _mapRole(_selectedRole!);

    if (fromGoogle) {
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await _authService.signInWithGoogle();
          await _authService.ensureGoogleUserDocBasic();
        }

        await _authService.setRoleForCurrentUser(roleToSave);

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (route) => false,
        );
      } on FirebaseAuthException catch (e) {
        final msg = e.code == 'popup-blocked'
            ? 'Popup blocked. Allow popups'
            : e.code == 'unauthorized-domain'
            ? 'Unauthorized domain. Add localhost in Firebase'
            : e.code == 'operation-not-allowed'
            ? 'Google sign in not enabled'
            : e.code == 'popup-closed-by-user'
            ? 'Popup closed'
            : 'Google failed';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final name = (args?['name'] ?? '').toString();
    final email = (args?['email'] ?? '').toString();
    final password = (args?['password'] ?? '').toString();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signup data missing. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        role: roleToSave,
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'email-already-in-use'
          ? 'Email already in use'
          : e.code == 'weak-password'
          ? 'Password is too weak'
          : e.code == 'invalid-email'
          ? 'Invalid email'
          : e.code == 'operation-not-allowed'
          ? 'Email/Password not enabled in Firebase'
          : 'Signup failed';

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signup failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color)
            else
              Icon(Icons.circle_outlined, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Your Role'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 18),
              const Text(
                "Choose your role",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "This will decide your access level",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              _buildRoleCard(
                role: 'admin',
                title: 'Administrator',
                subtitle: 'Full access and management',
                icon: Icons.admin_panel_settings,
                color: const Color(0xFF6A11CB),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                role: 'officer',
                title: 'Security Officer',
                subtitle: 'Monitor alerts and activity',
                icon: Icons.security,
                color: const Color(0xFF2575FC),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
