import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'browser_utils_io.dart' if (dart.library.html) 'browser_utils_web.dart';

/// Wraps a protected screen and verifies the current user's role before
/// rendering it. Shows a loading screen during the check. If the role does
/// not match [requiredRole], or the user is not logged in, redirects
/// immediately — the protected screen is never shown.
///
/// Also blocks access from mobile browsers entirely (web is desktop-only).
class RoleGuard extends StatefulWidget {
  final String requiredRole;
  final Widget child;
  const RoleGuard({super.key, required this.requiredRole, required this.child});

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final role = doc.data()?['user_role'] as String? ?? '';
      if (role == widget.requiredRole) {
        setState(() => _verified = true);
      } else {
        final dest = role == 'customer' ? '/customer'
                   : role == 'employee' ? '/employee'
                   : role == 'admin'    ? '/admin'
                   : '/';
        Navigator.pushNamedAndRemoveUntil(context, dest, (_) => false);
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isMobileBrowser()) {
      return Scaffold(
        backgroundColor: const Color(0xFF0d0d1a),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phone_android_rounded,
                    size: 64, color: Colors.white38),
                const SizedBox(height: 20),
                const Text(
                  'Desktop Only',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The Imprenta X web app is designed for desktop use.\n'
                  'Please use the mobile app on your phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_verified) {
      return const Scaffold(
        backgroundColor: Color(0xFF0d0d1a),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return widget.child;
  }
}
