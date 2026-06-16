import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'app_theme.dart';

const _cyan = Color(0xFF00B4D8);
const _magenta = Color(0xFFFF006E);
const _yellow = Color(0xFFFFDE89);
const _green = Color(0xFF80B918);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _isSending = false;
  bool _linkSent = false;
  String? _error;

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
    _dotCtrl.dispose();
    super.dispose();
  }

  /// Resolves the typed email to the Firebase Auth email, or returns null
  /// with an appropriate error set on [_error].
  ///
  /// Returns:
  ///   - A non-null String  → the Auth email to send the reset to.
  ///   - null               → abort; [_error] has already been set.
  Future<String?> _resolveAuthEmail(String typedEmail) async {
    final firestore = FirebaseFirestore.instance;

    // ── 1. Look up the typed email in the User collection ─────────────────
    final snap = await firestore
        .collection('User')
        .where('email', isEqualTo: typedEmail)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      // The email doesn't belong to any account in the system.
      setState(() {
        _error = 'No account found with that email address.\n'
            'Please try a different email.';
      });
      return null;
    }

    final data = snap.docs.first.data();
    final role = (data['user_role'] as String? ?? '');

    // ── 2. Customers → use their email directly as the Auth email ─────────
    if (role != 'employee' && role != 'admin') return typedEmail;

    // ── 3. Admin / Employee → look up the placeholder Auth email ──────────
    final uid = snap.docs.first.id;
    final indexDoc = await firestore.collection('AuthIndex').doc(uid).get();
    final authEmail = indexDoc.data()?['placeholder_email'] as String?;

    if (authEmail == null || authEmail.endsWith('@imprenta.internal')) {
      setState(() {
        _error = 'Your email hasn\'t been verified yet.\n'
            'Please check your inbox for the verification link\n'
            'that was sent when you set your email, then try again.';
      });
      return null;
    }

    return authEmail;
  }

  Future<void> _sendResetLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final authEmail = await _resolveAuthEmail(email);
      if (authEmail == null) {
        // _error is already set inside _resolveAuthEmail.
        setState(() => _isSending = false);
        return;
      }

      final continueUrl =
          kIsWeb ? Uri.base.origin + '/' : 'https://imprenta-x-system.web.app/';

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: authEmail,
        actionCodeSettings: ActionCodeSettings(
          url: continueUrl,
          handleCodeInApp: true,
        ),
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _linkSent = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ??
              'Could not send reset link. Check your email and try again.';
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not send reset link. Check your email and try again.';
          _isSending = false;
        });
      }
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
                    // ── Brand icon ──────────────────────────────────────────
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
                        Icons.lock_reset,
                        color: _yellow,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _linkSent ? 'Check your inbox' : 'Forgot password?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _linkSent
                          ? 'We sent a reset link to\n${_emailCtrl.text.trim()}'
                          : 'Enter your email and we\'ll send\na password reset link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Card ────────────────────────────────────────────────
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
                            child: _linkSent ? _buildSuccess() : _buildForm(),
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
          onSubmitted: (_) => _sendResetLink(),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 20),

        // Primary CTA
        ElevatedButton(
          onPressed: _isSending ? null : _sendResetLink,
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
                  'Send Reset Link',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
        ),

        const SizedBox(height: 20),

        // ── Back to Sign In — flanked by dividers ───────────────────────────
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: 0.08),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 10,
                      color: _yellow.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Back to Sign In',
                      style: TextStyle(
                        color: _yellow.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: 0.08),
                thickness: 1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        _CmykDots(controller: _dotCtrl),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.greenAccent,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Reset link sent!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Click the link in your email to set\na new password. Check spam if needed.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // Resend — ghost button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isSending ? null : _sendResetLink,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  )
                : const Text(
                    'Resend email',
                    style: TextStyle(fontSize: 13),
                  ),
          ),
        ),
        const SizedBox(height: 10),

        // Try different email — ghost button (unchanged)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _linkSent = false;
              _error = null;
            }),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text(
              'Try a different email',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Back to sign in — solid yellow primary
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),
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
