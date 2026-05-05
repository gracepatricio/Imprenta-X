import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

/// Optional screen shown after the forced password change.
/// The user can skip and add their email later from their profile.
class AddEmailScreen extends StatefulWidget {
  final String role;

  const AddEmailScreen({super.key, required this.role});

  @override
  State<AddEmailScreen> createState() => _AddEmailScreenState();
}

class _AddEmailScreenState extends State<AddEmailScreen> {
  final _emailCtrl = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isSending = false;
  bool _verificationSent = false;
  bool _isPolling = false;
  String? _error;
  Timer? _pollTimer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter an email address.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    final result = await _authService.addEmail(email);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result == 'verification_sent') {
      setState(() => _verificationSent = true);
      _startPolling();
    } else {
      setState(() => _error = result ?? 'Failed to send verification.');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _isPolling = true;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        await FirebaseAuth.instance.currentUser?.reload();
        final user = FirebaseAuth.instance.currentUser;
        // Check if email was updated (verifyBeforeUpdateEmail updates on confirm)
        final email = _emailCtrl.text.trim();
        if (user?.email == email) {
          _pollTimer?.cancel();
          await _authService.finalizeEmailUpdate(email);
          if (mounted) _navigateHome();
        }
      } catch (_) {}
    });
  }

  void _navigateHome() {
    switch (widget.role) {
      case 'admin':
        if (kIsWeb) {
          Navigator.pushNamedAndRemoveUntil(context, '/admin', (_) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
        }
        break;
      case 'employee':
        Navigator.pushNamedAndRemoveUntil(context, '/employee', (_) => false);
        break;
      default:
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  void _skip() {
    _pollTimer?.cancel();
    _navigateHome();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // prevent back navigation
      child: Scaffold(
        body: Container(
          decoration: AppTheme.backgroundDecoration,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isWide ? 24 : 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.gold.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.email_outlined,
                          color: AppTheme.gold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Add Your Email',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Adding an email lets you log in with it\nin addition to your ID.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),

                      const SizedBox(height: 28),

                      Container(
                        width: isWide ? 400 : double.infinity,
                        padding: EdgeInsets.all(isWide ? 28 : 20),
                        decoration: AppTheme.glassCard(opacity: 0.18),
                        child: _verificationSent
                            ? _buildWaiting()
                            : _buildForm(),
                      ),

                      const SizedBox(height: 20),

                      // Skip button
                      if (!_verificationSent)
                        TextButton(
                          onPressed: _skip,
                          child: const Text(
                            'Skip for now — I\'ll add it in my profile settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendVerification(),
          decoration: AppTheme.inputDecoration(
            'Your email address',
            icon: Icons.email_outlined,
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isSending ? null : _sendVerification,
          style: AppTheme.primaryButton(),
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text('Send Verification Email'),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          color: AppTheme.gold,
          size: 48,
        ),
        const SizedBox(height: 16),
        const Text(
          'Verification email sent!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a link to ${_emailCtrl.text.trim()}.\n'
          'Click the link to confirm your email.\n\n'
          'This screen will advance automatically.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 20),
        const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.gold,
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: _skip,
          child: const Text(
            'Skip — I\'ll verify later in my profile',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
