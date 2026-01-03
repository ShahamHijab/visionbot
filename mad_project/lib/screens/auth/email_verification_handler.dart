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

class _EmailVerificationHandlerState extends State<EmailVerificationHandler>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _loading = true;
  String _status = 'Checking verification...';
  bool _success = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _check();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFEC4899).withOpacity(0.08),
              const Color(0xFF06B6D4).withOpacity(0.08),
              const Color(0xFF8B5CF6).withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Status Icon
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              (_loading
                                      ? const Color(0xFF06B6D4)
                                      : _success
                                      ? const Color(0xFF06B6D4)
                                      : const Color(0xFFEC4899))
                                  .withOpacity(0.15),
                              (_loading
                                      ? const Color(0xFF8B5CF6)
                                      : _success
                                      ? const Color(0xFF8B5CF6)
                                      : const Color(0xFFEC4899))
                                  .withOpacity(0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_loading
                                          ? const Color(0xFF06B6D4)
                                          : _success
                                          ? const Color(0xFF06B6D4)
                                          : const Color(0xFFEC4899))
                                      .withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _loading
                                  ? const [Color(0xFF06B6D4), Color(0xFF8B5CF6)]
                                  : _success
                                  ? const [Color(0xFF06B6D4), Color(0xFF8B5CF6)]
                                  : const [
                                      Color(0xFFEC4899),
                                      Color(0xFFEC4899),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 4,
                                  ),
                                )
                              : Icon(
                                  _success
                                      ? Icons.check_circle_rounded
                                      : Icons.error_rounded,
                                  size: 56,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Status Text
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: _loading
                            ? const [Color(0xFF06B6D4), Color(0xFF8B5CF6)]
                            : _success
                            ? const [Color(0xFF06B6D4), Color(0xFF8B5CF6)]
                            : const [Color(0xFFEC4899), Color(0xFFEC4899)],
                      ).createShader(bounds),
                      child: Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Action Buttons (only show when not loading and not success)
                    if (!_loading && !_success) ...[
                      const SizedBox(height: 48),
                      // Check Again Button
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFEC4899),
                              Color(0xFF8B5CF6),
                              Color(0xFF06B6D4),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: const Color(0xFF06B6D4).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.verifyEmail,
                                (route) => false,
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: const Center(
                              child: Text(
                                'Check Again',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sign Up Again Button
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              await _authService.signOut();
                              if (!context.mounted) return;

                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.signup,
                                (route) => false,
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Center(
                              child: ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFFEC4899),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ).createShader(bounds),
                                child: const Text(
                                  'Sign Up Again',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
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
        ),
      ),
    );
  }
}
