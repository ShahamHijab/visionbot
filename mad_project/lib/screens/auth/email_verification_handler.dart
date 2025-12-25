import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';

class EmailVerificationHandler extends StatefulWidget {
  final String? verificationId;

  const EmailVerificationHandler({super.key, this.verificationId});

  @override
  State<EmailVerificationHandler> createState() =>
      _EmailVerificationHandlerState();
}

class _EmailVerificationHandlerState extends State<EmailVerificationHandler> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  String _status = 'Checking verification...';
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final ok = await _authService.refreshAndCheckEmailVerified();

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _loading = false;
          _status =
              'Email not verified yet. Open your email and click the link.';
          _success = false;
        });
        return;
      }

      await _authService.finalizeVerifiedUser();
      final role = await _authService.getCurrentUserRole();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _status = 'Email verified successfully!';
        _success = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      if (role == null || role.isEmpty) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleSelection,
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboard,
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _status = 'Verification failed. Please try again.';
        _success = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading)
                  const CircularProgressIndicator(color: Color(0xFF6A11CB))
                else
                  Icon(
                    _success ? Icons.check_circle : Icons.error,
                    size: 80,
                    color: _success ? Colors.green : Colors.red,
                  ),
                const SizedBox(height: 32),
                Text(
                  _status,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (!_loading && !_success) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.verifyEmail,
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A11CB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Check Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () async {
                        await _authService.signOut();
                        if (!context.mounted) return;

                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.signup,
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Sign Up Again',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
