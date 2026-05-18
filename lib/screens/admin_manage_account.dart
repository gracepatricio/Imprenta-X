import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class AdminManageAccount extends StatefulWidget {
  final void Function(String newName)? onNameUpdated;
  final void Function(String newEmail)? onEmailUpdated;
  const AdminManageAccount({super.key, this.onNameUpdated, this.onEmailUpdated});

  @override
  State<AdminManageAccount> createState() => _AdminManageAccountState();
}

class _AdminManageAccountState extends State<AdminManageAccount> {
  // ── Personal Info ──────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _savingInfo = false;

  // ── Email change ───────────────────────────────────────────────
  bool _editingEmail       = false;
  bool _savingEmail        = false;
  String _originalEmail    = ''; // Firestore baseline — used for duplicate check
  final _emailPasswordCtrl = TextEditingController();
  bool _showEmailPassword  = false;
  String? _emailMessage;
  String? _emailError;

  // ── Password ───────────────────────────────────────────────────
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _savingPassword = false;

  // ── State ──────────────────────────────────────────────────────
  bool _loading = true;
  String? _infoMessage;
  String? _infoError;
  String? _pwMessage;
  String? _pwError;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _emailPasswordCtrl.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
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
        _nameController.text  = doc.data()?['full_name'] ?? user.displayName ?? '';
        _emailController.text = doc.data()?['email'] ?? user.email ?? '';
        _originalEmail        = _emailController.text;
        _loading = false;
      });
    }
  }

  Future<void> _savePersonalInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameController.text.trim();
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
      await Future.microtask(() async {
        await FirebaseFirestore.instance
            .collection('User')
            .doc(user.uid)
            .update({'full_name': name});
        await user.updateDisplayName(name);
        await user.reload();
      });
      if (mounted) {
        widget.onNameUpdated?.call(name);
        setState(() {
          _infoMessage = 'Personal information updated successfully.';
          _infoError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _infoError = 'Failed to update: ${e.toString()}';
          _infoMessage = null;
        });
      }
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newEmail = _emailController.text.trim();
    final password = _emailPasswordCtrl.text;

    if (newEmail.isEmpty) {
      setState(() { _emailError = 'Email cannot be empty.'; _emailMessage = null; });
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(newEmail)) {
      setState(() { _emailError = 'Enter a valid email address.'; _emailMessage = null; });
      return;
    }
    if (newEmail == _originalEmail) {
      setState(() { _emailError = 'This is already your current email.'; _emailMessage = null; });
      return;
    }
    if (password.isEmpty) {
      setState(() { _emailError = 'Enter your current password to confirm.'; _emailMessage = null; });
      return;
    }

    setState(() { _savingEmail = true; _emailError = null; _emailMessage = null; });

    try {
      final db = FirebaseFirestore.instance;

      // Reauthenticate using the real Firebase Auth email (placeholder)
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Check if new email is already taken by a different account
      final existing = await db
          .collection('User')
          .where('email', isEqualTo: newEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != user.uid) {
        setState(() { _emailError = 'That email is already linked to another account.'; _savingEmail = false; });
        return;
      }

      // Snapshot the old email BEFORE any writes.
      final emailToDelete = _originalEmail;

      final batch = db.batch();

      // 1. Update User doc
      batch.update(db.collection('User').doc(user.uid), {'email': newEmail});

      // 2. Hard-delete the old email_index entry so AuthService.login()
      //    cannot resolve the old email to this uid.
      if (emailToDelete.isNotEmpty && emailToDelete != newEmail) {
        batch.delete(db.collection('email_index').doc(emailToDelete));
      }

      // 3. Write new email to email_index so login-by-email works
      batch.set(db.collection('email_index').doc(newEmail), {
        'uid':    user.uid,
        'status': 'active',
      });

      await batch.commit();

      // 4. Sweep: delete any other stale email_index docs pointing to this uid
      //    (leftover from previous partial updates).
      try {
        final staleIndexDocs = await db
            .collection('email_index')
            .where('uid', isEqualTo: user.uid)
            .get();
        for (final doc in staleIndexDocs.docs) {
          if (doc.id != newEmail) {
            await doc.reference.delete();
          }
        }
      } catch (_) {
        // Non-fatal — stale entries don't break login, they just leave orphan docs.
      }

      if (!mounted) return;
      _originalEmail = newEmail;
      widget.onEmailUpdated?.call(newEmail);
      setState(() {
        _emailMessage      = 'Email updated successfully.';
        _emailError        = null;
        _editingEmail      = false;
        _savingEmail       = false;
        _emailPasswordCtrl.clear();
        _showEmailPassword = false;
      });
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect password.';
          break;
        case 'requires-recent-login':
          msg = 'Session expired. Please log out and log back in.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait and try again.';
          break;
        default:
          msg = 'Error (${e.code}): ${e.message ?? 'Please try again.'}';
      }
      if (mounted) setState(() { _emailError = msg; _savingEmail = false; });
    } catch (e) {
      if (mounted) setState(() { _emailError = 'Unexpected error: $e'; _savingEmail = false; });
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _pwError = 'No user session found. Please log in again.';
        _pwMessage = null;
      });
      return;
    }

    final current = _currentPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

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
      debugPrint('[PW] Step 1: reauthenticating ${user.email}');
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      debugPrint('[PW] Step 2: updating password');
      await user.updatePassword(newPw);
      debugPrint('[PW] Step 3: reloading user');
      await user.reload();
      debugPrint('[PW] Done!');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[PW] FirebaseAuthException — code: ${e.code}, message: ${e.message}',
      );
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-password':
          errorMsg = 'Current password is incorrect.';
          break;
        case 'weak-password':
          errorMsg = 'New password is too weak. Use at least 8 characters.';
          break;
        case 'requires-recent-login':
          errorMsg = 'Session expired. Please log out and log back in.';
          break;
        case 'too-many-requests':
          errorMsg = 'Too many attempts. Please wait and try again.';
          break;
        case 'network-request-failed':
          errorMsg = 'Network error. Please check your connection.';
          break;
        default:
          errorMsg = 'Error (${e.code}): ${e.message ?? 'Please try again.'}';
      }
    } catch (e) {
      debugPrint('[PW] Unknown error: $e');
      errorMsg = 'Unexpected error: ${e.toString()}';
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
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    }
  }

  // Consistent section card decoration
  BoxDecoration get _sectionCard => BoxDecoration(
    color: Colors.white.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.white.withValues(alpha: 0.75),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Title ───────────────────────────────────────────
          Row(
            children: [
              Icon(
                Icons.manage_accounts_rounded,
                color: Colors.white.withValues(alpha: 0.88),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Manage Account',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Personal Information ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: _sectionCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  label: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildField(
                        label: 'Full Name',
                        controller: _nameController,
                        hint: 'Edit your full name',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField(
                            label: 'Email Address',
                            controller: _emailController,
                            hint: 'Enter new email',
                            readOnly: !_editingEmail,
                          ),
                          const SizedBox(height: 6),
                          if (!_editingEmail)
                            GestureDetector(
                              onTap: () => setState(() {
                                _editingEmail = true;
                                _emailError   = null;
                                _emailMessage = null;
                              }),
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined,
                                      size: 11,
                                      color: AppTheme.gold.withValues(alpha: 0.8)),
                                  const SizedBox(width: 5),
                                  Text('Change email',
                                      style: TextStyle(
                                          color: AppTheme.gold.withValues(alpha: 0.8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          if (_editingEmail) ...[
                            const SizedBox(height: 10),
                            _buildPasswordField(
                              label: 'Confirm with current password',
                              controller: _emailPasswordCtrl,
                              hint: 'Enter your password',
                              visible: _showEmailPassword,
                              onToggle: () => setState(
                                      () => _showEmailPassword = !_showEmailPassword),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: ElevatedButton(
                                      onPressed: _savingEmail ? null : _changeEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.gold,
                                        foregroundColor: Colors.black,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: _savingEmail
                                          ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.black54))
                                          : const Text('Update Email',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: _savingEmail
                                        ? null
                                        : () {
                                      setState(() {
                                        _editingEmail = false;
                                        _emailError   = null;
                                        _emailMessage = null;
                                        _emailPasswordCtrl.clear();
                                        _showEmailPassword = false;
                                        _emailController.text = _originalEmail;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white54,
                                      side: BorderSide(
                                          color: Colors.white.withValues(
                                              alpha: 0.2)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(10)),
                                    ),
                                    child: const Text('Cancel',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            ),
                            if (_emailError != null) ...[
                              const SizedBox(height: 8),
                              _FeedbackBanner(
                                  message: _emailError!, isError: true),
                            ],
                          ],
                          // Success banner is outside _editingEmail so it
                          // stays visible after the form closes on success.
                          if (_emailMessage != null) ...[
                            const SizedBox(height: 8),
                            _FeedbackBanner(
                                message: _emailMessage!, isError: false),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _savingInfo ? null : _savePersonalInfo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                          ),
                          child: _savingInfo
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                              : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_infoMessage != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(message: _infoMessage!, isError: false),
                ],
                if (_infoError != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(message: _infoError!, isError: true),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Change Password ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(22),
            decoration: _sectionCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  label: 'Change Password',
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 18),
                _buildPasswordField(
                  label: 'Current Password',
                  controller: _currentPasswordController,
                  hint: 'Enter your current password',
                  visible: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildPasswordField(
                        label: 'New Password',
                        controller: _newPasswordController,
                        hint: 'Enter your new password',
                        visible: _showNew,
                        onToggle: () => setState(() => _showNew = !_showNew),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildPasswordField(
                        label: 'Confirm New Password',
                        controller: _confirmPasswordController,
                        hint: 'Re-enter your new password',
                        visible: _showConfirm,
                        onToggle: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Minimum 8 characters recommended.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                if (_pwMessage != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(message: _pwMessage!, isError: false),
                ],
                if (_pwError != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(message: _pwError!, isError: true),
                ],
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _savingPassword ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gold,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: _savingPassword
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                          : const Text(
                        'Update Password',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly
                ? Colors.white.withValues(alpha: 0.70)
                : Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: readOnly
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.09),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.gold.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.09),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.white.withValues(alpha: 0.65),
                size: 19,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: AppTheme.gold.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 17),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Divider(
            color: Colors.white.withValues(alpha: 0.1),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _FeedbackBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.redAccent : Colors.greenAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 16,
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