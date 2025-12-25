// lib/screens/auth/signup_screen.dart
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
    setState(() => _loading = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (!_agreeToTerms) {
      _showError('Please agree to Terms and Privacy Policy');
      return _stopLoading();
    }

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Please fill all fields');
      return _stopLoading();
    }

    if (!_isValidEmail(email)) {
      _showError('Enter a valid email');
      return _stopLoading();
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return _stopLoading();
    }

    if (password != confirm) {
      _showError('Passwords do not match');
      return _stopLoading();
    }

    try {
      // IMPORTANT: reset any existing session
      await FirebaseAuth.instance.signOut();

      await _authService.signUp(
        name: name,
        email: email,
        password: password,
        role: '',
      );

      if (!mounted) return;
      _goToVerify();
    } on FirebaseAuthException catch (e) {
      // USER ALREADY CREATED → GO TO VERIFY
      if (e.code == 'email-already-in-use') {
        _goToVerify();
        return;
      }

      _showError('Signup failed');
    } catch (_) {
      // Even if something failed AFTER user creation
      _goToVerify();
    }
  }

  void _goToVerify() {
    _stopLoading();
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.verifyEmail,
      (route) => false,
    );
  }

  void _stopLoading() {
    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _handleGoogleSignup() async {
    try {
      await _authService.signInWithGoogle();
      await _authService.ensureGoogleUserDocBasic();

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.roleSelection,
        arguments: {'fromGoogle': true},
      );
    } catch (_) {
      _showError('Google signup failed');
    }
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

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _handleSignup,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Continue"),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _handleGoogleSignup,
                  child: const Text("Continue with Google"),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
