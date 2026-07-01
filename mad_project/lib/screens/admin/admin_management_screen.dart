import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'package:mad_project/widgets/visionbot_app_bar.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;
  UserModel? _currentUser;
  bool _hasPermission = false;

  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;
  bool _confirmTouched = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    try {
      final currentUser = await _authService.getCurrentUserData();
      setState(() => _currentUser = currentUser);

      if (currentUser != null &&
          currentUser.permissions.canCreateAdminAccounts) {
        setState(() => _hasPermission = true);
      } else {
        setState(() => _hasPermission = false);
      }
    } catch (e) {
      print('Error checking permissions: $e');
      setState(() => _hasPermission = false);
    }
  }

  bool _isValidName(String name) {
    final trimmed = name.trim();
    return trimmed.length >= 3 && trimmed.contains(RegExp(r'[A-Za-z]'));
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());
  }

  String? _validateNameField(String name) {
    if (name.isEmpty) {
      return 'Full name is required';
    }
    if (!_isValidName(name)) {
      return 'Enter a valid full name (at least three letters)';
    }
    return null;
  }

  String? _validateEmailField(String email) {
    if (email.isEmpty) {
      return 'Email is required';
    }
    if (!_isValidEmail(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePasswordField(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.contains(' ')) {
      return 'Password cannot contain spaces';
    }
    if (password.length < 8) {
      return 'Password must be at least eight characters long';
    }
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    if (!hasUppercase || !hasLowercase || !hasNumber) {
      return 'Password must include uppercase, lowercase, and a number';
    }
    return null;
  }

  String? _validateConfirmPasswordField(String password, String confirm) {
    if (confirm.isEmpty) {
      return 'Confirm password is required';
    }
    if (password != confirm) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleCreateAdmin() async {
    if (_loading) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    final nameError = _validateNameField(name);
    final emailError = _validateEmailField(email);
    final passwordError = _validatePasswordField(password);
    final confirmError = _validateConfirmPasswordField(password, confirm);

    setState(() {
      _nameTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
      _confirmTouched = true;
      _nameError = nameError;
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if (nameError != null ||
        emailError != null ||
        passwordError != null ||
        confirmError != null) {
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.createAdminAccount(
        name: name,
        email: email,
        password: password,
      );

      if (!mounted) return;

      _showSuccess(
        'Admin account created successfully! Verification email sent to $email',
      );

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();

      setState(() => _loading = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(_getAuthErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to create admin account');
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Email already exists';
      case 'invalid-email':
        return 'Invalid email format';
      case 'permission-denied':
        return 'You do not have permission to create admin accounts. Only Security Officers can create admins.';
      case 'no-current-user':
        return 'You must be logged in';
      case 'user-not-found':
        return 'User data not found';
      case 'invalid-input':
        return 'Invalid input provided';
      default:
        return 'Error: ${code}';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission) {
      return Scaffold(
        appBar: VisionBotAppBar(
          pageTitle: 'Admin Management',
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only Security Officers can create admin accounts.\nAdmins cannot create other admins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: VisionBotAppBar(
        pageTitle: 'Create Admin Account',
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only Security Officers can create admin accounts. '
                      'Admins cannot create other admins.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Form Fields
            Text(
              'Admin Information',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Name Field
            TextField(
              controller: _nameController,
              enabled: !_loading,
              onChanged: (value) {
                setState(() {
                  _nameTouched = true;
                  _nameError = _validateNameField(value);
                });
              },
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter admin full name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _nameTouched ? _nameError : null,
              ),
            ),
            const SizedBox(height: 16),
            // Email Field
            TextField(
              controller: _emailController,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              onChanged: (value) {
                setState(() {
                  _emailTouched = true;
                  _emailError = _validateEmailField(value);
                });
              },
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'admin@example.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _emailTouched ? _emailError : null,
              ),
            ),
            const SizedBox(height: 16),
            // Password Field
            TextField(
              controller: _passwordController,
              enabled: !_loading,
              obscureText: _obscurePassword,
              onChanged: (value) {
                setState(() {
                  _passwordTouched = true;
                  _passwordError = _validatePasswordField(value);
                  _confirmError = _validateConfirmPasswordField(
                    value,
                    _confirmPasswordController.text,
                  );
                });
              },
              decoration: InputDecoration(
                labelText: 'Password',
                hintText:
                    'At least eight characters with uppercase, lowercase, and number',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _passwordTouched ? _passwordError : null,
              ),
            ),
            const SizedBox(height: 16),
            // Confirm Password Field
            TextField(
              controller: _confirmPasswordController,
              enabled: !_loading,
              obscureText: _obscureConfirmPassword,
              onChanged: (value) {
                setState(() {
                  _confirmTouched = true;
                  _confirmError = _validateConfirmPasswordField(
                    _passwordController.text,
                    value,
                  );
                });
              },
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _confirmTouched ? _confirmError : null,
              ),
            ),
            const SizedBox(height: 32),
            // Create Admin Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleCreateAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined),
                          SizedBox(width: 10),
                          Text(
                            'Create Admin Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Info Text
            Center(
              child: Text(
                'A verification email will be sent to the new admin.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
