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
  bool _editingEmail        = false;
  bool _savingEmail         = false;
  String _originalEmail     = '';
  final _emailPasswordCtrl  = TextEditingController();
  bool _showEmailPassword   = false;
  String? _emailMessage;
  String? _emailError;

  bool   _verificationPending  = false;
  String _pendingNewEmail      = '';
  String _pendingPassword      = '';
  bool   _checkingVerification = false;

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

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      final existing = await db
          .collection('User')
          .where('email', isEqualTo: newEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != user.uid) {
        setState(() { _emailError = 'That email is already linked to another account.'; _savingEmail = false; });
        return;
      }

      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      final savedPassword = _emailPasswordCtrl.text;
      setState(() {
        _verificationPending = true;
        _pendingNewEmail     = newEmail;
        _pendingPassword     = savedPassword;
        _savingEmail         = false;
        _editingEmail        = false;
        _emailError          = null;
        _emailMessage        = null;
        _emailPasswordCtrl.clear();
        _showEmailPassword   = false;
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

  Future<void> _checkVerification() async {
    setState(() { _checkingVerification = true; _emailError = null; });

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null || user.email == _pendingNewEmail) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _pendingNewEmail,
          password: _pendingPassword,
        );
        user = cred.user;
      } else {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      }

      if (user == null) {
        if (mounted) setState(() {
          _emailError = 'Session lost. Please log in again.';
          _checkingVerification = false;
        });
        return;
      }

      final authEmailNow = user.email ?? '';
      final isVerified = authEmailNow == _pendingNewEmail;

      if (!isVerified) {
        if (mounted) {
          setState(() {
            _emailError           = 'Email not verified yet. Please check your inbox and click the link, then try again.';
            _checkingVerification = false;
          });
        }
        return;
      }

      // Capture pending email before any state changes wipe it
      final emailToFinalize = _pendingNewEmail;

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (ctx) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              title: Row(
                children: const [
                  Icon(Icons.verified_outlined, color: Color(0xFF166534), size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Email Verified',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Your email has been changed successfully. Tap "Log Out Now" to sign back in with your new email address.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF3A3A52),
                  height: 1.5,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx, rootNavigator: true).pop();
                    await _finalizeEmailChange(emailToFinalize);
                    await FirebaseAuth.instance.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4A94D),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text(
                    'Log Out Now',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token' ||
          e.code == 'user-not-found') {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _pendingNewEmail,
            password: _pendingPassword,
          );
          final user = cred.user;
          if (user != null && user.email == _pendingNewEmail) {
            await _finalizeEmailChange(_pendingNewEmail);
            return;
          }
        } catch (reAuthErr) {
          if (mounted) setState(() {
            _emailError = 'Could not re-authenticate: $reAuthErr';
            _checkingVerification = false;
          });
          return;
        }
      }
      if (mounted) setState(() {
        _emailError = 'Verification check failed: ${e.message ?? e.code}';
        _checkingVerification = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError           = 'Verification check failed: $e';
          _checkingVerification = false;
        });
      }
    }
  }

  Future<void> _finalizeEmailChange(String newEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final db = FirebaseFirestore.instance;
    final emailToDelete = _originalEmail;

    try {
      final batch = db.batch();

      batch.update(db.collection('User').doc(user.uid), {'email': newEmail});

      if (emailToDelete.isNotEmpty && emailToDelete != newEmail) {
        batch.delete(db.collection('email_index').doc(emailToDelete));
      }

      batch.set(db.collection('email_index').doc(newEmail), {
        'uid':    user.uid,
        'status': 'active',
      });

      batch.set(
        db.collection('AuthIndex').doc(user.uid),
        {'placeholder_email': newEmail},
      );

      await batch.commit();

      try {
        final staleIndexDocs = await db
            .collection('email_index')
            .where('uid', isEqualTo: user.uid)
            .get();
        for (final doc in staleIndexDocs.docs) {
          if (doc.id != newEmail) await doc.reference.delete();
        }
      } catch (_) {}

      if (!mounted) return;
      _originalEmail = newEmail;
      widget.onEmailUpdated?.call(newEmail);
      setState(() {
        _verificationPending  = false;
        _pendingNewEmail      = '';
        _pendingPassword      = '';
        _checkingVerification = false;
        _emailController.text = newEmail;
        _emailMessage         = 'Email updated successfully.';
        _emailError           = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError           = 'Failed to save email change: $e';
          _checkingVerification = false;
        });
      }
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
      debugPrint('[PW] FirebaseAuthException — code: ${e.code}, message: ${e.message}');
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

  BoxDecoration get _sectionCard => BoxDecoration(
    color: const Color.fromARGB(109, 255, 255, 255),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0x50FFFFFF)),
    boxShadow: const [
      BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD4A94D),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.manage_accounts_rounded,
                color: const Color(0xFFD4A94D),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Manage Profile',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
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
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 520;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      wide
                          ? Row(
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
                          Expanded(child: _buildEmailColumn()),
                        ],
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildField(
                            label: 'Full Name',
                            controller: _nameController,
                            hint: 'Edit your full name',
                          ),
                          const SizedBox(height: 14),
                          _buildEmailColumn(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _savingInfo ? null : _savePersonalInfo,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4A94D),
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
                  );
                }),
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
                        onToggle: () => setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 11,
                      color: Color.fromARGB(255, 47, 47, 83),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Minimum 8 characters recommended.',
                      style: TextStyle(
                        color: Color.fromARGB(255, 47, 47, 83),
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

  Widget _buildEmailColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildField(
          label: 'Email Address',
          controller: _emailController,
          hint: 'Enter new email',
          readOnly: !_editingEmail || _verificationPending,
        ),
        const SizedBox(height: 6),

        // ── idle ──────────────────────────────────────────────────
        if (!_editingEmail && !_verificationPending)
          GestureDetector(
            onTap: () => setState(() {
              _editingEmail = true;
              _emailError   = null;
              _emailMessage = null;
            }),
            child: const Row(
              children: [
                Icon(Icons.edit_outlined, size: 11, color: Color(0xFFD4A94D)),
                SizedBox(width: 5),
                Text(
                  'Change email',
                  style: TextStyle(
                    color: Color(0xFFD4A94D),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // ── editing ───────────────────────────────────────────────
        if (_editingEmail && !_verificationPending) ...[
          const SizedBox(height: 10),
          _buildPasswordField(
            label: 'Confirm with current password',
            controller: _emailPasswordCtrl,
            hint: 'Enter your password',
            visible: _showEmailPassword,
            onToggle: () => setState(() => _showEmailPassword = !_showEmailPassword),
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
                      backgroundColor: const Color(0xFFD4A94D),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _savingEmail
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black54,
                      ),
                    )
                        : const Text(
                      'Send Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  onPressed: _savingEmail
                      ? null
                      : () => setState(() {
                    _editingEmail      = false;
                    _emailError        = null;
                    _emailMessage      = null;
                    _emailPasswordCtrl.clear();
                    _showEmailPassword = false;
                    _emailController.text = _originalEmail;
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3A3A52),
                    side: const BorderSide(color: Color(0x40000000)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (_emailError != null) ...[
            const SizedBox(height: 8),
            _FeedbackBanner(message: _emailError!, isError: true),
          ],
        ],

        // ── pending verification ───────────────────────────────────
        if (_verificationPending) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x12B45309),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x40B45309)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.mark_email_unread_outlined,
                        color: Color(0xFF92400E),
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verification email sent to $_pendingNewEmail',
                        style: const TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Click the link in the email, then tap \"I've verified\" to complete the change.",
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _checkingVerification ? null : _checkVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4A94D),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _checkingVerification
                              ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black54,
                            ),
                          )
                              : const Icon(Icons.verified_outlined, size: 14),
                          label: Text(
                            _checkingVerification ? 'Checking...' : "I've verified",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: _checkingVerification
                            ? null
                            : () => setState(() {
                          _verificationPending  = false;
                          _pendingNewEmail      = '';
                          _pendingPassword      = '';
                          _emailError           = null;
                          _emailController.text = _originalEmail;
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3A3A52),
                          side: const BorderSide(color: Color(0x40000000)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                if (_emailError != null) ...[
                  const SizedBox(height: 8),
                  _FeedbackBanner(message: _emailError!, isError: true),
                ],
              ],
            ),
          ),
        ],

        // ── success banner ─────────────────────────────────────────
        if (_emailMessage != null) ...[
          const SizedBox(height: 8),
          _FeedbackBanner(message: _emailMessage!, isError: false),
        ],
      ],
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
          style: const TextStyle(
            color: Color(0xFF3A3A52),
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
            color: readOnly ? const Color(0xFF3A3A52) : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color.fromARGB(255, 47, 47, 83),
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: readOnly ? const Color(0x18000000) : const Color(0x0F000000),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x40000000)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x30000000)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD4A94D), width: 1.5),
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
          style: const TextStyle(
            color: Color(0xFF3A3A52),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color.fromARGB(255, 47, 47, 83),
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: const Color(0x0F000000),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: const Color(0xFF3A3A52),
                size: 19,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x40000000)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0x30000000)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFD4A94D), width: 1.5),
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
        Icon(icon, color: const Color(0xFFD4A94D), size: 17),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Divider(color: Color(0x25000000), thickness: 1),
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
    final color       = isError ? const Color(0xFFDC2626) : const Color(0xFF166534);
    final bgColor     = isError ? const Color(0x10DC2626) : const Color(0x10166534);
    final borderColor = isError ? const Color(0x40DC2626) : const Color(0x40166534);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
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