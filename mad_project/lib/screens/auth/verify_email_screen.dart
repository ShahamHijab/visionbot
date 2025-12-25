import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final AuthService _authService = AuthService();

  bool _loading = false;
  String _email = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args == null) return;

      setState(() {
        _email = (args['email'] ?? '').toString();
      });
    });
  }

  Future<void> _checkVerified() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final ok = await _authService.refreshAndCheckEmailVerified();

      if (!mounted) return;

      if (!ok) {
        setState(() => _loading = false);
        _showError('Not verified yet. Open your email and click the link.');
        return;
      }

      await _authService.finalizeVerifiedUser();

      final role = await _authService.getCurrentUserRole();

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

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
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      _showError(_getErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      _showError('Verification check failed. Please try again.');
    }
  }

  Future<void> _resendLink() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _authService.resendEmailVerificationLink();

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification link sent again. Check your inbox.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(_getErrorMessage(e.code));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to resend link. Please try again.');
    }
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'no-current-user':
        return 'No user found. Please sign up again.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      default:
        return 'Something went wrong. Please try again.';
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

  Future<void> _goBack() async {
    await _authService.signOut();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.signup,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6A11CB).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 80,
                color: Color(0xFF6A11CB),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Check Your Email',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'We sent a verification link to:',
              style: TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_email.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A11CB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _email,
                  style: const TextStyle(
                    color: Color(0xFF6A11CB),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Click the verification link in your email',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check spam folder if you do not see it',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _checkVerified,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A11CB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'I Verified. Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive the email?",
                  style: TextStyle(color: Colors.black54),
                ),
                TextButton(
                  onPressed: _loading ? null : _resendLink,
                  child: const Text(
                    'Resend',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Link may take a moment to arrive',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
