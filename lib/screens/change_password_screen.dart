import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'add_email_screen.dart';
import 'app_theme.dart';

/// Shown when `must_change_password == true` after login.
/// The user CANNOT skip this screen — no back button.
class ChangePasswordScreen extends StatefulWidget {
  /// The role ('admin' or 'employee') passed from the login flow.
  final String role;

  const ChangePasswordScreen({super.key, required this.role});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confPwCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConf = false;
  bool _isSaving = false;
  String? _error;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentPwCtrl.text.trim();
    final newPw = _newPwCtrl.text.trim();
    final conf = _confPwCtrl.text.trim();

    if (current.isEmpty || newPw.isEmpty || conf.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (newPw.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters.');
      return;
    }
    if (newPw == current) {
      setState(
            () => _error =
        'New password must be different from your temporary password.',
      );
      return;
    }
    if (newPw != conf) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final result = await _authService.changePassword(current, newPw);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result == 'success') {
      // Navigate to the optional Add Email screen, passing the new password
      // so addEmail() can create the migrated Firebase Auth account with the
      // same password the user just set.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AddEmailScreen(
            role: widget.role,
            newPassword: newPw,
          ),
        ),
      );
    } else {
      setState(() => _error = result ?? 'Failed to change password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // WillPopScope prevents the back button from dismissing this screen
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
                          Icons.lock_reset,
                          color: AppTheme.gold,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Change Your Password',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'You must set a new password before\nyou can access your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),

                      const SizedBox(height: 8),
                      // Info banner
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isWide ? 80 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 14,
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Enter the temporary password given to you by your administrator.',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Container(
                        width: isWide ? 400 : double.infinity,
                        padding: EdgeInsets.all(isWide ? 28 : 20),
                        decoration: AppTheme.glassCard(opacity: 0.18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Current (temp) password
                            TextField(
                              controller: _currentPwCtrl,
                              obscureText: !_showCurrent,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.next,
                              decoration: AppTheme.inputDecoration(
                                'Temporary password',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showCurrent
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                        () => _showCurrent = !_showCurrent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // New password
                            TextField(
                              controller: _newPwCtrl,
                              obscureText: !_showNew,
                              style: const TextStyle(color: Colors.white),
                              textInputAction: TextInputAction.next,
                              decoration: AppTheme.inputDecoration(
                                'New password',
                                icon: Icons.lock_reset,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showNew
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showNew = !_showNew),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Confirm new password
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
                                    _showConf
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white54,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _showConf = !_showConf),
                                ),
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
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
                                  : const Text('Set New Password'),
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
      ),
    );
  }
}