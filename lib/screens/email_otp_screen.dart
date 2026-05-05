import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final Future<void> Function() onVerified;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  bool _handled = false; // prevents double-navigation
  String? _error;

  int _resendCooldown = 60;
  Timer? _pollTimer;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_resendCooldown > 0) _resendCooldown--;
      });
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkVerification(silent: true);
    });
  }

  Future<void> _checkVerification({bool silent = false}) async {
    // Prevent handling verification more than once
    if (_handled) return;

    if (!silent) {
      if (!mounted) return;
      setState(() {
        _isChecking = true;
        _error = null;
      });
    }

    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;

      if (verified) {
        if (_handled) return;
        _handled = true;
        _pollTimer?.cancel();
        _resendTimer?.cancel();

        if (!mounted) return;
        // Clear checking state before handing off
        if (!silent) setState(() => _isChecking = false);

        // onVerified handles navigation — do NOT pop after this
        await widget.onVerified();
      } else {
        if (!silent && mounted) {
          setState(() {
            _isChecking = false;
            _error = 'Not verified yet. Check your inbox and click the link.';
          });
        }
      }
    } catch (e) {
      if (!silent && mounted) {
        setState(() {
          _isChecking = false;
          _error = 'Could not check status. Try again.';
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) _startResendTimer();
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not resend. Try again later.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white60,
                          size: 18,
                        ),
                        label: const Text(
                          'Back',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
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
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: AppTheme.gold,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Verify your email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a verification link to\n${widget.email}\n\n'
                      'Click the link in the email, then tap the button below.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      width: isWide ? 420 : double.infinity,
                      padding: EdgeInsets.all(isWide ? 28 : 20),
                      decoration: AppTheme.glassCard(opacity: 0.18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_error != null) ...[
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          ElevatedButton(
                            onPressed: _isChecking
                                ? null
                                : () => _checkVerification(),
                            style: AppTheme.primaryButton(),
                            child: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text("I've verified my email"),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Didn't receive it?  ",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                              _isResending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.gold,
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: _resendCooldown == 0
                                          ? _resend
                                          : null,
                                      child: Text(
                                        _resendCooldown > 0
                                            ? 'Resend in ${_resendCooldown}s'
                                            : 'Resend',
                                        style: TextStyle(
                                          color: _resendCooldown == 0
                                              ? AppTheme.gold
                                              : Colors.white38,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
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
}
