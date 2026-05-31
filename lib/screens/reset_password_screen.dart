import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';

const _cyan = Color(0xFF00B4D8);
const _magenta = Color(0xFFFF006E);
const _yellow = Color(0xFFFFDE89);
const _green = Color(0xFF80B918);

class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _newPwCtrl = TextEditingController();
  final _confPwCtrl = TextEditingController();
  bool _showNew = false;
  bool _showConf = false;
  bool _isSaving = false;
  bool _success = false;
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
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Z]').hasMatch(password))
      return 'Password must contain at least one uppercase letter.';
    if (!RegExp(r'[a-z]').hasMatch(password))
      return 'Password must contain at least one lowercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(password))
      return 'Password must contain at least one number.';
    if (!RegExp(
      r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/\\|`~'
      "'\"]",
    ).hasMatch(password))
      return 'Password must contain at least one special character.';
    return null;
  }

  Future<void> _save() async {
    final pw = _newPwCtrl.text.trim();
    final conf = _confPwCtrl.text.trim();

    if (pw.isEmpty || conf.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }
    final pwError = _validatePassword(pw);
    if (pwError != null) {
      setState(() => _error = pwError);
      return;
    }
    if (pw != conf) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: pw,
      );
      if (mounted)
        setState(() {
          _success = true;
          _isSaving = false;
        });
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.code == 'expired-action-code'
              ? 'This reset link has expired. Please request a new one.'
              : e.code == 'invalid-action-code'
              ? 'Invalid reset link. Please request a new one.'
              : (e.message ?? 'Failed to reset password. Try again.');
          _isSaving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _isSaving = false;
        });
      }
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
                      child: Icon(
                        _success
                            ? Icons.check_rounded
                            : Icons.lock_outline_rounded,
                        color: _yellow,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _success ? 'Password updated!' : 'Set new password',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _success
                          ? 'Your password has been reset.\nYou can now sign in.'
                          : 'Enter and confirm your new password.',
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
                            child: _success ? _buildSuccess() : _buildForm(),
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
          label: 'New Password',
          controller: _newPwCtrl,
          icon: Icons.lock_outline_rounded,
          obscureText: !_showNew,
          textInputAction: TextInputAction.next,
          hint: 'Enter new password',
          suffix: IconButton(
            icon: Icon(
              _showNew
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
            onPressed: () => setState(() => _showNew = !_showNew),
            splashRadius: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Min. 8 chars · uppercase · lowercase · number · special character',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.25),
            fontSize: 10,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 14),

        _AuthField(
          label: 'Confirm Password',
          controller: _confPwCtrl,
          icon: Icons.lock_outline_rounded,
          obscureText: !_showConf,
          textInputAction: TextInputAction.done,
          hint: 'Re-enter new password',
          onSubmitted: (_) => _save(),
          suffix: IconButton(
            icon: Icon(
              _showConf
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
            onPressed: () => setState(() => _showConf = !_showConf),
            splashRadius: 16,
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isSaving ? null : _save,
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
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Save Password',
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
        Text(
          'All set! Your password has been\nsuccessfully updated.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: _yellow,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sign In',
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
