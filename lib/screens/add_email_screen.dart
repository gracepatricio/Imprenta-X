import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

const _cyan = Color(0xFF00B4D8);
const _magenta = Color(0xFFFF006E);
const _yellow = Color(0xFFFFDE89);
const _green = Color(0xFF80B918);

/// Optional screen shown after the forced password change.
/// The user can skip and add their email later from their profile.
class AddEmailScreen extends StatefulWidget {
  final String role;
  final String newPassword;

  const AddEmailScreen({
    super.key,
    required this.role,
    required this.newPassword,
  });

  @override
  State<AddEmailScreen> createState() => _AddEmailScreenState();
}

class _AddEmailScreenState extends State<AddEmailScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isSending = false;
  bool _verificationSent = false;
  bool _usedMigrationPath = false;
  String? _error;
  Timer? _pollTimer;

  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pollTimer?.cancel();
    _dotCtrl.dispose();
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

    final result = await _authService.addEmail(
      email,
      currentPassword: widget.newPassword,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result == 'migration_sent' || result == 'verification_sent') {
      setState(() {
        _verificationSent = true;
        _usedMigrationPath = result == 'migration_sent';
      });
      _startPolling(email);
    } else {
      setState(() => _error = result ?? 'Failed to send verification.');
    }
  }

  void _startPolling(String email) {
    _pollTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) {
        _pollTimer?.cancel();
        return;
      }
      try {
        if (_usedMigrationPath) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
          final migratedEmail = await _authService.checkAndFinalizeMigration(
            currentUid,
          );
          if (migratedEmail != null) {
            _pollTimer?.cancel();
            if (mounted) _navigateHome();
          }
        } else {
          await FirebaseAuth.instance.currentUser?.reload();
          final user = FirebaseAuth.instance.currentUser;
          if (user?.email == email) {
            _pollTimer?.cancel();
            await _authService.finalizeEmailUpdate(email);
            if (mounted) _navigateHome();
          }
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
      canPop: false,
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
                      // ── Brand icon ──────────────────────────────────────
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
                          Icons.email_outlined,
                          color: _yellow,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Add Your Email',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Adding an email lets you log in with it\nin addition to your ID.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Card ────────────────────────────────────────────
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 400 : double.infinity,
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
                              child: _verificationSent
                                  ? _buildWaiting()
                                  : _buildForm(),
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

                      // ── Skip link ───────────────────────────────────────
                      if (!_verificationSent) ...[
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _skip,
                          child: Text(
                            'Skip for now — I\'ll add it in my profile settings',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.28),
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                            ),
                          ),
                        ),
                      ],
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
        _AuthField(
          label: 'Email Address',
          controller: _emailCtrl,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          hint: 'Enter your email address',
          onSubmitted: (_) => _sendVerification(),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: Colors.black,
            disabledBackgroundColor: _yellow.withValues(alpha: 0.5),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Send Verification Email',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
        ),

        const SizedBox(height: 20),
        _CmykDots(controller: _dotCtrl),
      ],
    );
  }

  Widget _buildWaiting() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _yellow.withValues(alpha: 0.1),
            border: Border.all(
              color: _yellow.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: _yellow,
            size: 26,
          ),
        ),
        const SizedBox(height: 14),
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
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),

        // Animated waiting indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _yellow,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Waiting for verification…',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Divider
        Divider(color: Colors.white.withValues(alpha: 0.08), thickness: 1),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: _skip,
          child: Text(
            'Skip — I\'ll verify later in my profile',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.28),
              fontSize: 12,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _CmykDots(controller: _dotCtrl),
      ],
    );
  }
}

// ── Shared field widget ────────────────────────────────────────────────────────

class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? hint;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: _focused
                ? _yellow.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.38),
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w500,
          ),
          child: Text(widget.label.toUpperCase()),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: _focused
                  ? _yellow.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: _yellow.withValues(alpha: 0.08),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                widget.icon,
                color: _focused
                    ? _yellow.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.28),
                size: 18,
              ),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
            ),
          ),
        ),
      ],
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
