import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';

const _cyan = Color(0xFF00B4D8);
const _magenta = Color(0xFFFF006E);
const _yellow = Color(0xFFFFDE89);
const _green = Color(0xFF80B918);

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

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  bool _isResending = false;
  bool _handled = false;
  String? _error;

  int _resendCooldown = 60;
  Timer? _pollTimer;
  Timer? _resendTimer;

  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _startResendTimer();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    _dotCtrl.dispose();
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
        if (!silent) setState(() => _isChecking = false);
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
        decoration: AppTheme.backgroundDecoration(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isWide ? 24 : 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),

                    // ── Brand icon ────────────────────────────────────────
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: _yellow,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Verify your email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We sent a verification link to\n${widget.email}\n\n'
                      'Click the link in the email, then tap the button below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Card ─────────────────────────────────────────────
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 420 : double.infinity,
                      ),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Container(
                            padding: EdgeInsets.fromLTRB(
                              isWide ? 28 : 20,
                              32,
                              isWide ? 28 : 20,
                              24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                ElevatedButton(
                                  onPressed: _isChecking
                                      ? null
                                      : () => _checkVerification(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _yellow,
                                    foregroundColor: Colors.black,
                                    disabledBackgroundColor: _yellow.withValues(
                                      alpha: 0.5,
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isChecking
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          "I've verified my email",
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                ),

                                const SizedBox(height: 20),

                                // Divider
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  thickness: 1,
                                ),

                                const SizedBox(height: 16),

                                // Resend row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Didn't receive it?  ",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                    _isResending
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.5,
                                              color: _yellow,
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
                                                    ? _yellow
                                                    : Colors.white.withValues(
                                                        alpha: 0.22,
                                                      ),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                  ],
                                ),

                                const SizedBox(height: 20),
                                _CmykDots(controller: _dotCtrl),

                                const SizedBox(height: 20),

                                // Divider
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  thickness: 1,
                                ),

                                const SizedBox(height: 16),

                                // ── Back to Register button ───────────────
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: _yellow,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Back to Register',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // CMYK accent bar
                          Positioned(
                            top: 0,
                            left: 40,
                            right: 40,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(4),
                                ),
                                gradient: const LinearGradient(
                                  colors: [_cyan, _magenta, _yellow, _green],
                                ),
                              ),
                            ),
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

// ── CMYK dots ─────────────────────────────────────────────────────────────────

class _CmykDots extends StatelessWidget {
  const _CmykDots({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final colors = [_cyan, _magenta, _yellow, _green];
    final delays = [0.0, 0.2, 0.4, 0.6];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final anim = Tween<double>(begin: 0.25, end: 0.9).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              delays[i],
              (delays[i] + 0.4).clamp(0, 1),
              curve: Curves.easeInOut,
            ),
          ),
        );
        return AnimatedBuilder(
          animation: anim,
          builder: (_, __) => Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors[i].withValues(alpha: anim.value),
            ),
          ),
        );
      }),
    );
  }
}
