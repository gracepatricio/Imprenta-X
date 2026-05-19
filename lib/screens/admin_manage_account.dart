import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

// ── Liquid Glass Design Tokens ─────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xF5FFFFFF);
  static const Color surfaceMid = Color(0xD8FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);

  static const Color borderMid = Color(0x60FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xC0111827);
  static const Color textMuted = Color(0x80111827);

  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const BoxShadow glowShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static BoxDecoration section() => BoxDecoration(
    color: surfaceThin,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: borderMid, width: 0.8),
    boxShadow: const [rowShadow],
  );
}

// =============================================================================
class AdminManageAccount extends StatefulWidget {
  final void Function(String newName)? onNameUpdated;
  const AdminManageAccount({super.key, this.onNameUpdated});

  @override
  State<AdminManageAccount> createState() => _AdminManageAccountState();
}

class _AdminManageAccountState extends State<AdminManageAccount> {
  // Personal info
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // read-only display
  bool _savingInfo = false;
  String? _infoMessage;
  String? _infoError;

  // Email change flow
  // States: 'idle' | 'confirming' | 'sent'
  String _emailChangeState = 'idle';
  final _newEmailCtrl = TextEditingController();
  final _emailPwCtrl = TextEditingController();
  bool _showEmailPw = false;
  bool _sendingEmail = false;
  String? _emailError;
  Timer? _emailPollTimer;
  bool _usedMigrationPath = false;
  final AuthService _authService = AuthService();

  // Password change
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _savingPassword = false;
  String? _pwMessage;
  String? _pwError;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _newEmailCtrl.dispose();
    _emailPwCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _emailPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() {
        _nameCtrl.text = doc.data()?['full_name'] ?? user.displayName ?? '';
        _emailCtrl.text = doc.data()?['email'] ?? user.email ?? '';
        _loading = false;
      });
    }
  }

  // ── Save name ──────────────────────────────────────────────────────────────
  Future<void> _savePersonalInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _infoError = 'Full name cannot be empty.';
        _infoMessage = null;
      });
      return;
    }
    setState(() {
      _savingInfo = true;
      _infoError = null;
      _infoMessage = null;
    });
    try {
      await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
        'full_name': name,
      });
      await user.updateDisplayName(name);
      await user.reload();
      if (mounted) {
        widget.onNameUpdated?.call(name);
        setState(() {
          _infoMessage = 'Personal information updated successfully.';
          _infoError = null;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _infoError = 'Failed to update: $e';
          _infoMessage = null;
        });
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  // ── Email change flow ──────────────────────────────────────────────────────
  /// Step 1: user clicks "Edit" → show the confirmation sub-form.
  void _beginEmailEdit() {
    setState(() {
      _emailChangeState = 'confirming';
      _newEmailCtrl.clear();
      _emailPwCtrl.clear();
      _emailError = null;
    });
  }

  void _cancelEmailEdit() {
    _emailPollTimer?.cancel();
    setState(() {
      _emailChangeState = 'idle';
      _emailError = null;
    });
  }

  /// Step 2: validate inputs then call addEmail (same service used in AddEmailScreen).
  Future<void> _sendEmailVerification() async {
    final newEmail = _newEmailCtrl.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email address.');
      return;
    }
    if (_emailPwCtrl.text.isEmpty) {
      setState(
        () => _emailError = 'Please enter your current password to confirm.',
      );
      return;
    }

    setState(() {
      _sendingEmail = true;
      _emailError = null;
    });

    final result = await _authService.addEmail(
      newEmail,
      currentPassword: _emailPwCtrl.text,
    );

    if (!mounted) return;
    setState(() => _sendingEmail = false);

    if (result == 'migration_sent' || result == 'verification_sent') {
      setState(() {
        _emailChangeState = 'sent';
        _usedMigrationPath = result == 'migration_sent';
      });
      _startEmailPolling(newEmail);
    } else {
      setState(
        () => _emailError = result ?? 'Failed to send verification email.',
      );
    }
  }

  void _startEmailPolling(String targetEmail) {
    _emailPollTimer?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _emailPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) {
        _emailPollTimer?.cancel();
        return;
      }
      try {
        if (_usedMigrationPath) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid ?? uid;
          final migratedEmail = await _authService.checkAndFinalizeMigration(
            currentUid,
          );
          if (migratedEmail != null) {
            _emailPollTimer?.cancel();
            if (mounted) _onEmailVerified(migratedEmail);
          }
        } else {
          await FirebaseAuth.instance.currentUser?.reload();
          final user = FirebaseAuth.instance.currentUser;
          if (user?.email == targetEmail) {
            _emailPollTimer?.cancel();
            await _authService.finalizeEmailUpdate(targetEmail);
            if (mounted) _onEmailVerified(targetEmail);
          }
        }
      } catch (_) {}
    });
  }

  void _onEmailVerified(String newEmail) {
    setState(() {
      _emailCtrl.text = newEmail;
      _emailChangeState = 'idle';
      _infoMessage = 'Email updated to $newEmail successfully.';
    });
  }

  // ── Change password ────────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _pwError = 'No user session found.';
        _pwMessage = null;
      });
      return;
    }
    final current = _currentPasswordCtrl.text;
    final newPw = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() {
        _pwError = 'Please fill in all password fields.';
        _pwMessage = null;
      });
      return;
    }
    if (newPw.length < 6) {
      setState(() {
        _pwError = 'New password must be at least 6 characters.';
        _pwMessage = null;
      });
      return;
    }
    if (newPw != confirm) {
      setState(() {
        _pwError = 'New passwords do not match.';
        _pwMessage = null;
      });
      return;
    }

    setState(() {
      _savingPassword = true;
      _pwError = null;
      _pwMessage = null;
    });
    String? errorMsg;
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPw);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          errorMsg = 'Current password is incorrect.';
          break;
        case 'weak-password':
          errorMsg = 'New password is too weak.';
          break;
        case 'requires-recent-login':
          errorMsg = 'Session expired. Please log out and back in.';
          break;
        default:
          errorMsg = 'Error (${e.code}): ${e.message ?? 'Try again.'}';
      }
    } catch (e) {
      errorMsg = 'Unexpected error: $e';
    }

    if (!mounted) return;
    if (errorMsg != null) {
      setState(() {
        _pwError = errorMsg;
        _pwMessage = null;
        _savingPassword = false;
      });
    } else {
      setState(() {
        _pwMessage = 'Password changed successfully.';
        _pwError = null;
        _savingPassword = false;
        _currentPasswordCtrl.clear();
        _newPasswordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _Glass.textMuted,
          strokeWidth: 2,
        ),
      );
    }
    // Wrap in an IntrinsicHeight + SizedBox.expand so the panel fills the card
    return SizedBox.expand(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _Glass.surfaceThin,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _Glass.borderMid, width: 0.8),
                    boxShadow: const [_Glass.rowShadow],
                  ),
                  child: const Icon(
                    Icons.manage_accounts_rounded,
                    size: 16,
                    color: _Glass.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Manage Account',
                  style: TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Personal Information ───────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _Glass.section(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    label: 'Personal Information',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  // Responsive row: wraps on narrow screens
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 520;
                      final nameField = _GlassField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                      );
                      final emailField = _buildEmailField();
                      final saveBtn = Padding(
                        padding: EdgeInsets.only(top: wide ? 20 : 0),
                        child: _GlassButton(
                          label: 'Save Changes',
                          isPrimary: true,
                          isLoading: _savingInfo,
                          onPressed: _savingInfo ? null : _savePersonalInfo,
                        ),
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: nameField),
                            const SizedBox(width: 14),
                            Expanded(child: emailField),
                            const SizedBox(width: 14),
                            saveBtn,
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          nameField,
                          const SizedBox(height: 14),
                          emailField,
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: saveBtn,
                          ),
                        ],
                      );
                    },
                  ),

                  if (_infoMessage != null) ...[
                    const SizedBox(height: 12),
                    _FeedbackBanner(message: _infoMessage!, isError: false),
                  ],
                  if (_infoError != null) ...[
                    const SizedBox(height: 12),
                    _FeedbackBanner(message: _infoError!, isError: true),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Change Password ────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _Glass.section(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    label: 'Change Password',
                    icon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _GlassPasswordField(
                    controller: _currentPasswordCtrl,
                    label: 'Current Password',
                    hint: 'Enter your current password',
                    visible: _showCurrent,
                    onToggle: () =>
                        setState(() => _showCurrent = !_showCurrent),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 400;
                      final newPwField = _GlassPasswordField(
                        controller: _newPasswordCtrl,
                        label: 'New Password',
                        hint: 'Enter your new password',
                        visible: _showNew,
                        onToggle: () => setState(() => _showNew = !_showNew),
                      );
                      final confirmField = _GlassPasswordField(
                        controller: _confirmPasswordCtrl,
                        label: 'Confirm New Password',
                        hint: 'Re-enter your new password',
                        visible: _showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      );
                      if (wide) {
                        return Row(
                          children: [
                            Expanded(child: newPwField),
                            const SizedBox(width: 14),
                            Expanded(child: confirmField),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          newPwField,
                          const SizedBox(height: 12),
                          confirmField,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        size: 10,
                        color: _Glass.textMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Minimum 8 characters recommended.',
                        style: TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  if (_pwMessage != null) ...[
                    const SizedBox(height: 12),
                    _FeedbackBanner(message: _pwMessage!, isError: false),
                  ],
                  if (_pwError != null) ...[
                    const SizedBox(height: 12),
                    _FeedbackBanner(message: _pwError!, isError: true),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _GlassButton(
                      label: 'Update Password',
                      isPrimary: true,
                      isLoading: _savingPassword,
                      onPressed: _savingPassword ? null : _changePassword,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Email field widget (handles all 3 states) ─────────────────────────────
  Widget _buildEmailField() {
    switch (_emailChangeState) {
      // ── idle: read-only display + Edit button ──────────────────────────
      case 'idle':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GlassField(
              controller: _emailCtrl,
              label: 'Email Address',
              icon: Icons.email_outlined,
              readOnly: true,
              suffixIcon: TextButton(
                onPressed: _beginEmailEdit,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppTheme.gold,
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              children: const [
                Icon(Icons.info_outline, size: 10, color: _Glass.textMuted),
                SizedBox(width: 4),
                Text(
                  'Click Edit to change your email.',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ],
        );

      // ── confirming: new email + password inputs ────────────────────────
      case 'confirming':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _Glass.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Glass.borderMid, width: 0.8),
            boxShadow: const [_Glass.rowShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your new email and current password.\nWe\'ll send a verification link.',
                style: TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              _GlassField(
                controller: _newEmailCtrl,
                label: 'New Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              _GlassPasswordField(
                controller: _emailPwCtrl,
                label: 'Current Password',
                hint: 'Confirm with your current password',
                visible: _showEmailPw,
                onToggle: () => setState(() => _showEmailPw = !_showEmailPw),
              ),
              if (_emailError != null) ...[
                const SizedBox(height: 10),
                _FeedbackBanner(message: _emailError!, isError: true),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _GlassButton(
                    label: 'Cancel',
                    isPrimary: false,
                    onPressed: _cancelEmailEdit,
                  ),
                  const SizedBox(width: 8),
                  _GlassButton(
                    label: 'Send Verification',
                    isPrimary: true,
                    isLoading: _sendingEmail,
                    onPressed: _sendingEmail ? null : _sendEmailVerification,
                  ),
                ],
              ),
            ],
          ),
        );

      // ── sent: waiting for the user to click the link ───────────────────
      case 'sent':
      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.mark_email_read_outlined,
                    color: Color(0xFF2E7D32),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Verification email sent!',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'We sent a link to ${_newEmailCtrl.text.trim()}.\n'
                'Click it to confirm — this screen will update automatically.',
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: _cancelEmailEdit,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: _Glass.textMuted,
                    ),
                    child: const Text(
                      'Cancel / use a different email',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}

// =============================================================================
// Shared glass widgets
// =============================================================================

class _GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GlassButton({
    required this.label,
    this.icon,
    required this.isPrimary,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xDD1A1A2E) : _Glass.surfaceThin,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isPrimary ? const Color(0x44FFFFFF) : _Glass.borderMid,
            width: 0.8,
          ),
          boxShadow: const [_Glass.rowShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? Colors.white : _Glass.textSecondary,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 13,
                color: isPrimary ? Colors.white : _Glass.textSecondary,
              ),
            if (icon != null || isLoading) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : _Glass.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool readOnly;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _GlassField({
    required this.controller,
    required this.label,
    this.icon,
    this.readOnly = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _Glass.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          validator: validator,
          keyboardType: keyboardType,
          style: TextStyle(
            color: readOnly ? _Glass.textMuted : _Glass.textPrimary,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, size: 15, color: _Glass.textMuted)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly
                ? _Glass.surfaceThin.withAlpha(80)
                : _Glass.surfaceThin,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _Glass.borderMid, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.gold.withValues(alpha: 0.7),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE53935),
                width: 0.8,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE53935)),
            ),
            errorStyle: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _GlassPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool visible;
  final VoidCallback onToggle;

  const _GlassPasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.visible,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _Glass.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 12.5),
            filled: true,
            fillColor: _Glass.surfaceThin,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: _Glass.textMuted,
                size: 17,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _Glass.borderMid, width: 0.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.gold.withValues(alpha: 0.7),
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section header with divider ───────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _Glass.surfaceThin,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _Glass.borderMid, width: 0.8),
        ),
        child: Icon(icon, size: 14, color: _Glass.textSecondary),
      ),
      const SizedBox(width: 9),
      Text(
        label,
        style: const TextStyle(
          color: _Glass.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: _Glass.borderMid, thickness: 0.8)),
    ],
  );
}

// ── Feedback banner ───────────────────────────────────────────────────────────
class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
