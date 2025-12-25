// lib/screens/auth/role_selection_screen.dart
import 'package:flutter/material.dart';
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

  Future<void> _continue() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a role')));
      return;
    }

    try {
      await _authService.setRoleForCurrentUser(_selectedRole!);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (route) => false,
      );
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save role')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RadioListTile(
            title: const Text('Admin'),
            value: 'admin',
            groupValue: _selectedRole,
            onChanged: (v) => setState(() => _selectedRole = v),
          ),
          RadioListTile(
            title: const Text('Officer'),
            value: 'officer',
            groupValue: _selectedRole,
            onChanged: (v) => setState(() => _selectedRole = v),
          ),
          ElevatedButton(onPressed: _continue, child: const Text('Continue')),
        ],
      ),
    );
  }
}
