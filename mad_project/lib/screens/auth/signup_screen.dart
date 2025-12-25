import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _loading = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.trim());
  }

  Future<void> _handleSignup() async {
    if (_loading) return;

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (!_agreeToTerms) {
      _showError('Please agree to Terms and Privacy Policy');
      return;
    }

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Please fill all fields');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Enter a valid email');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _loading = true);

    try {
      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        role: '',
      );

      if (!mounted) return;

      _showSuccess('Verification link sent to your email!');

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        AppRoutes.verifyEmail,
        arguments: {'email': email.trim().toLowerCase()},
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(_getAuthErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Signup failed. Please try again.');
    }
  }

  Future<void> _handleGoogleSignup() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      await _authService.signInWithGoogle();

      if (!mounted) return;

      final role = await _authService.getCurrentUserRole();

      if (!mounted) return;

      if (role == null || role.isEmpty) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleSelection,
          (route) => false,
        );
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.dashboard,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Google signup failed. Please try again.');
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Email already registered. Please login instead.';
      case 'invalid-email':
        return 'Invalid email format';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'permission-denied':
        return 'Permission error. Please check Firestore rules.';
      default:
        return 'Signup failed. Please try again';
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 25),
              Image.asset("assets/logobg.png", width: 95),
              const SizedBox(height: 12),
              const Text(
                "Join VisionBot",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                "Create your account",
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 28),
              _inputField(
                label: "Full name",
                hint: "Your name",
                icon: Icons.person_outline,
                controller: _nameController,
              ),
              const SizedBox(height: 18),
              _inputField(
                label: "Email Address",
                hint: "your.email@example.com",
                icon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _inputField(
                label: "Password",
                hint: "Create a password",
                icon: Icons.lock_outline,
                controller: _passwordController,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 18),
              _inputField(
                label: "Confirm Password",
                hint: "Re-enter password",
                icon: Icons.lock_outline,
                controller: _confirmPasswordController,
                obscure: _obscureConfirmPassword,
                suffix: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (v) =>
                        setState(() => _agreeToTerms = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      "I agree to the Terms of Service and Privacy Policy",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "You'll receive a verification link via email",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6A11CB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading ? null : _handleGoogleSignup,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Continue with Google",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.login);
                    },
                    child: const Text("Log in"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
