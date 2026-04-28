import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../services/otp_service.dart';
import 'email_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _isSending  = false;
  bool _linkSent   = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    setState(() { _isSending = true; _error = null; });

    String generatedCode;
    try {
      generatedCode = await OtpService().sendResetOtp(email);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not send code. Check your email and try again.';
          _isSending = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isSending = false);

    // Navigate to OTP screen.
    // After OTP verified: Firebase sends the secure reset link — user clicks
    // it and the app opens the in-app "Set New Password" screen.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailOtpScreen(
          email:        email,
          expectedCode: generatedCode,
          onVerified: () async {
            final continueUrl = kIsWeb
                ? Uri.base.origin + '/'
                : 'https://imprenta-x-system.web.app/';

            await FirebaseAuth.instance.sendPasswordResetEmail(
              email: email,
              actionCodeSettings: ActionCodeSettings(
                url: continueUrl,
                handleCodeInApp: true,
              ),
            );

            if (mounted) setState(() => _linkSent = true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white60, size: 18),
                        label: const Text('Back to Sign In',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: const Icon(Icons.lock_reset,
                          color: AppTheme.gold, size: 30),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      _linkSent ? 'Check your inbox' : 'Forgot password?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _linkSent
                          ? 'We sent a password reset link to\n${_emailCtrl.text.trim()}\n\nClick the link to set your new password.'
                          : 'Enter your email and we\'ll send\na verification code to confirm it\'s you.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      width: isWide ? 400 : double.infinity,
                      padding: EdgeInsets.all(isWide ? 28 : 20),
                      decoration: AppTheme.glassCard(opacity: 0.18),
                      child: _linkSent ? _buildSuccess() : _buildForm(),
                    ),
                  ],
                ),
              ),
            );
          },
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
          onSubmitted: (_) => _sendCode(),
          decoration: AppTheme.inputDecoration(
            'Email address',
            icon: Icons.email_outlined,
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],

        const SizedBox(height: 20),

        ElevatedButton(
          onPressed: _isSending ? null : _sendCode,
          style: AppTheme.primaryButton(),
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                )
              : const Text('Send Verification Code'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const Icon(Icons.check_circle_outline,
            color: Colors.greenAccent, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Reset link sent!',
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Didn\'t receive it? Check your spam folder.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _linkSent = false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Try a different email'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.primaryButton(),
            child: const Text('Back to Sign In'),
          ),
        ),
      ],
    );
  }
}
