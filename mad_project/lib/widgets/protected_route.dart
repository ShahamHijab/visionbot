import 'package:flutter/material.dart';
import '../services/permission_service.dart';

class ProtectedRoute extends StatefulWidget {
  final String permissionKey;
  final Widget child;
  final String? accessDeniedMessage;

  const ProtectedRoute({
    super.key,
    required this.permissionKey,
    required this.child,
    this.accessDeniedMessage,
  });

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  final PermissionService _permissionService = PermissionService();
  bool _loading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _permissionService.hasPermission(
      widget.permissionKey,
    );

    setState(() {
      _hasPermission = hasPermission;
      _loading = false;
    });

    if (!hasPermission && mounted) {
      // Show dialog and navigate back after dialog closes
      Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: Color(0xFFFF6B6B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ],
            ),
            content: Text(
              widget.accessDeniedMessage ??
                  'You do not have permission to access this feature. Please contact your administrator.',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext); // Close dialog
                  if (mounted && context.mounted) {
                    Navigator.pop(context); // Navigate back
                  }
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFEC4899).withOpacity(0.08),
                const Color(0xFF06B6D4).withOpacity(0.08),
                Colors.white,
              ],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFEC4899).withOpacity(0.08),
                const Color(0xFF06B6D4).withOpacity(0.08),
                Colors.white,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF6B6B).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    size: 80,
                    color: Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Access Denied',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    widget.accessDeniedMessage ??
                        'You do not have permission to access this feature.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
