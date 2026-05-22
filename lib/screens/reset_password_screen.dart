import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPwCtrl = TextEditingController();
  final _confPwCtrl = TextEditingController();
  bool _showNew = false;
  bool _showConf = false;
  bool _isSaving = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    super.dispose();
  }

  /// Returns null if valid, or an error message string if invalid.
  String? _validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain at least one number.';
    }
    if (!RegExp(
      r'[!@#$%^&*()\-_=+\[\]{};:,.<>?/\\|`~'
      "'\"]",
    ).hasMatch(password)) {
      return 'Password must contain at least one special character.';
    }
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
                        Icons.lock_outline,
                        color: AppTheme.gold,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(
                      _success ? 'Password updated!' : 'Set new password',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _success
                          ? 'Your password has been reset.\nYou can now sign in.'
                          : 'Enter and confirm your new password.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      width: isWide ? 400 : double.infinity,
                      padding: EdgeInsets.all(isWide ? 28 : 20),
                      decoration: AppTheme.glassCard(opacity: 0.18),
                      child: _success ? _buildSuccess() : _buildForm(),
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
          controller: _newPwCtrl,
          obscureText: !_showNew,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.next,
          decoration: AppTheme.inputDecoration(
            'New password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _showNew ? Icons.visibility : Icons.visibility_off,
                color: Colors.white54,
                size: 18,
              ),
              onPressed: () => setState(() => _showNew = !_showNew),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Min. 8 chars with uppercase, lowercase, number & special character',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _confPwCtrl,
          obscureText: !_showConf,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: AppTheme.inputDecoration(
            'Confirm new password',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _showConf ? Icons.visibility : Icons.visibility_off,
                color: Colors.white54,
                size: 18,
              ),
              onPressed: () => setState(() => _showConf = !_showConf),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: AppTheme.primaryButton(),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text('Save Password'),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Colors.greenAccent,
          size: 52,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
            style: AppTheme.primaryButton(),
            child: const Text('Sign In'),
          ),
        ),
      ],
    );
  }
}
