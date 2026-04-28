import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import '../services/otp_service.dart';

class EmailOtpScreen extends StatefulWidget {
  final String email;

  /// The correct OTP code returned by [OtpService.sendOtp] /
  /// [OtpService.sendResetOtp]. Verified in-memory — no Firestore read needed.
  final String expectedCode;

  final Future<void> Function() onVerified;

  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.expectedCode,
    required this.onVerified,
  });

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final List<TextEditingController> _ctrl =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  // Resend sends a new code — we update expectedCode via this mutable field.
  late String _activeCode;

  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;

  int _resendCooldown = 60;
  int _expirySecs     = 600;
  Timer? _resendTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _activeCode = widget.expectedCode;
    _startTimers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nodes[0].requestFocus();
    });
  }

  void _startTimers() {
    _resendCooldown = 60;
    _expirySecs     = 600;
    _resendTimer?.cancel();
    _expiryTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() { if (_resendCooldown > 0) _resendCooldown--; });
    });

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_expirySecs > 0) {
          _expirySecs--;
        } else {
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in _ctrl)  { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    _resendTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  String get _entered => _ctrl.map((c) => c.text).join();

  String get _expiryLabel {
    final m = _expirySecs ~/ 60;
    final s = _expirySecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _verify() async {
    if (_entered.length < 6) {
      setState(() => _error = 'Enter all 6 digits.');
      return;
    }
    if (_expirySecs == 0) {
      setState(() => _error = 'Code expired. Request a new one.');
      return;
    }

    // ── In-memory verification — no Firestore read required ──────────────
    if (_entered.trim() != _activeCode.trim()) {
      setState(() => _error = 'Incorrect code. Please try again.');
      return;
    }
    // ─────────────────────────────────────────────────────────────────────

    setState(() { _isVerifying = true; _error = null; });

    try {
      await widget.onVerified();
      // Only pop if still in the stack (registration uses
      // pushNamedAndRemoveUntil which already removes this screen).
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() { _isResending = true; _error = null; });
    try {
      // sendOtp returns the new code; update _activeCode so the next
      // attempt is verified against the fresh code.
      _activeCode = await OtpService().sendOtp(widget.email);
      for (final c in _ctrl) { c.clear(); }
      _nodes[0].requestFocus();
      _startTimers();
    } catch (e) {
      if (mounted) setState(() => _error = 'Resend failed. Check your connection.');
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
                    // Back
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white60, size: 18),
                        label: const Text('Back',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Icon
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
                      child: const Icon(Icons.mark_email_read_outlined,
                          color: AppTheme.gold, size: 30),
                    ),
                    const SizedBox(height: 18),

                    const Text('Verify your email',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit code to\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _expirySecs > 0
                          ? 'Code expires in $_expiryLabel'
                          : 'Code has expired',
                      style: TextStyle(
                        color: _expirySecs > 60
                            ? Colors.white38
                            : Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Card
                    Container(
                      width: isWide ? 420 : double.infinity,
                      padding: EdgeInsets.all(isWide ? 28 : 20),
                      decoration: AppTheme.glassCard(opacity: 0.18),
                      child: Column(
                        children: [
                          // OTP digit boxes
                          Row(
                            children: List.generate(
                              6,
                              (i) => Expanded(
                                child: _OtpDigitBox(
                                  controller: _ctrl[i],
                                  focusNode:  _nodes[i],
                                  onFilled: () {
                                    if (i < 5) _nodes[i + 1].requestFocus();
                                    setState(() => _error = null);
                                  },
                                  onErased: () {
                                    if (i > 0) {
                                      _nodes[i - 1].requestFocus();
                                      _ctrl[i - 1].clear();
                                    }
                                    setState(() => _error = null);
                                  },
                                ),
                              ),
                            ),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ],

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isVerifying ? null : _verify,
                              style: AppTheme.primaryButton(),
                              child: _isVerifying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.black),
                                    )
                                  : const Text('Verify Code'),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Resend row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Didn't receive it?  ",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 13)),
                              _isResending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppTheme.gold),
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

// ── Single digit box ──────────────────────────────────────────────────────────

class _OtpDigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onFilled;
  final VoidCallback onErased;

  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.onFilled,
    required this.onErased,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.22), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (val) {
          if (val.length == 1) {
            onFilled();
          } else if (val.isEmpty) {
            onErased();
          }
        },
      ),
    );
  }
}
