import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// ── AdminProfile ───────────────────────────────────────────────────────────────
class AdminProfile extends StatefulWidget {
  final void Function(String newName)? onNameUpdated;
  final void Function(String newEmail)? onEmailUpdated;
  const AdminProfile({super.key, this.onNameUpdated, this.onEmailUpdated});

  @override
  State<AdminProfile> createState() => _AdminProfileState();
}

class _AdminProfileState extends State<AdminProfile> {
  // ── Personal Info ──────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _savingInfo = false;

  // ── Email change ───────────────────────────────────────────────
  bool _editingEmail = false;
  bool _savingEmail = false;
  String _originalEmail = '';
  final _emailPasswordCtrl = TextEditingController();
  bool _showEmailPassword = false;
  String? _emailMessage;
  String? _emailError;

  bool _verificationPending = false;
  String _pendingNewEmail = '';
  String _pendingPassword = '';
  bool _checkingVerification = false;

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
        _nameController.text =
            doc.data()?['full_name'] ?? user.displayName ?? '';
        _emailController.text = doc.data()?['email'] ?? user.email ?? '';
        _originalEmail = _emailController.text;
        _loading = false;
      });
    }
  }

  // ── Save only the full name ──────────────────────────────────────
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
          _infoMessage = 'Name updated successfully.';
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
      setState(() {
        _emailError = 'Email cannot be empty.';
        _emailMessage = null;
      });
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(newEmail)) {
      setState(() {
        _emailError = 'Enter a valid email address.';
        _emailMessage = null;
      });
      return;
    }
    if (newEmail == _originalEmail) {
      setState(() {
        _emailError = 'This is already your current email.';
        _emailMessage = null;
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _emailError = 'Enter your current password to confirm.';
        _emailMessage = null;
      });
      return;
    }

    setState(() {
      _savingEmail = true;
      _emailError = null;
      _emailMessage = null;
    });

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
        setState(() {
          _emailError = 'That email is already linked to another account.';
          _savingEmail = false;
        });
        return;
      }

      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      final savedPassword = _emailPasswordCtrl.text;
      setState(() {
        _verificationPending = true;
        _pendingNewEmail = newEmail;
        _pendingPassword = savedPassword;
        _savingEmail = false;
        _editingEmail = false;
        _emailError = null;
        _emailMessage = null;
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
      if (mounted)
        setState(() {
          _emailError = msg;
          _savingEmail = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _emailError = 'Unexpected error: $e';
          _savingEmail = false;
        });
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _checkingVerification = true;
      _emailError = null;
    });

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
        if (mounted)
          setState(() {
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
            _emailError =
                'Email not verified yet. Please check your inbox and click the link, then try again.';
            _checkingVerification = false;
          });
        }
        return;
      }

      await _finalizeEmailChange(_pendingNewEmail);
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
          if (mounted)
            setState(() {
              _emailError = 'Could not re-authenticate: $reAuthErr';
              _checkingVerification = false;
            });
          return;
        }
      }
      if (mounted)
        setState(() {
          _emailError = 'Verification check failed: ${e.message ?? e.code}';
          _checkingVerification = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'Verification check failed: $e';
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
        'uid': user.uid,
        'status': 'active',
      });

      batch.set(db.collection('AuthIndex').doc(user.uid), {
        'placeholder_email': newEmail,
      });

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
        _verificationPending = false;
        _pendingNewEmail = '';
        _pendingPassword = '';
        _checkingVerification = false;
        _emailController.text = newEmail;
        _emailMessage = 'Email changed successfully.';
        _emailError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'Failed to save email change: $e';
          _checkingVerification = false;
        });
      }
    }
  }

  // ── Password validation ──────────────────────────────────────────────────────
  String? _validateNewPassword(String pw) {
    if (pw.length < 8) return 'Password must be at least 8 characters.';
    if (!pw.contains(RegExp(r'[A-Z]')))
      return 'Password must contain at least one uppercase letter.';
    if (!pw.contains(RegExp(r'[a-z]')))
      return 'Password must contain at least one lowercase letter.';
    if (!pw.contains(RegExp(r'[0-9]')))
      return 'Password must contain at least one number.';
    if (!pw.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~;]')))
      return 'Password must contain at least one special character.';
    return null;
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

    final validationError = _validateNewPassword(newPw);
    if (validationError != null) {
      setState(() {
        _pwError = validationError;
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
          errorMsg = 'New password is too weak. Please meet all requirements.';
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

  // ── Card decoration ──────────────────────────────────────────────────────────
  BoxDecoration get _sectionCard => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE8E0D0), width: 1),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 2)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4A94D)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page title ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5EDD8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFFD4A94D),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // ── Personal Information card ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _sectionCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  label: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 20),

                // Full Name field + Save Changes button inline (responsive)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 480;
                    if (wide) {
                      // Wide: input and button side by side
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _buildField(
                              label: 'Full Name',
                              controller: _nameController,
                              hint: 'Enter your full name',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Spacer to align with input (label height ~18 + gap 8)
                                const SizedBox(height: 26),
                                _PrimaryButton(
                                  label: 'Save Changes',
                                  loading: _savingInfo,
                                  onPressed: _savingInfo
                                      ? null
                                      : _savePersonalInfo,
                                  icon: Icons.save_outlined,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Narrow: stack vertically
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildField(
                            label: 'Full Name',
                            controller: _nameController,
                            hint: 'Enter your full name',
                          ),
                          const SizedBox(height: 12),
                          _PrimaryButton(
                            label: 'Save Changes',
                            loading: _savingInfo,
                            onPressed: _savingInfo ? null : _savePersonalInfo,
                            icon: Icons.save_outlined,
                          ),
                        ],
                      );
                    }
                  },
                ),

                // Feedback banners for name
                if (_infoMessage != null) ...[
                  const SizedBox(height: 12),
                  _FeedbackBanner(message: _infoMessage!, isError: false),
                ],
                if (_infoError != null) ...[
                  const SizedBox(height: 12),
                  _FeedbackBanner(message: _infoError!, isError: true),
                ],

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFEEE8DC), thickness: 1),
                const SizedBox(height: 20),

                // Email sub-section
                _buildEmailColumn(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Change Password card ─────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _sectionCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  label: 'Change Password',
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 20),

                // Current Password
                _buildPasswordField(
                  label: 'Current Password',
                  controller: _currentPasswordController,
                  hint: 'Enter your current password',
                  visible: _showCurrent,
                  onToggle: () => setState(() => _showCurrent = !_showCurrent),
                ),
                const SizedBox(height: 16),

                // New Password + Confirm — responsive row/column
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 480;
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildPasswordField(
                              label: 'New Password',
                              controller: _newPasswordController,
                              hint: 'Enter new password',
                              visible: _showNew,
                              onToggle: () =>
                                  setState(() => _showNew = !_showNew),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildPasswordField(
                              label: 'Re-Enter Password',
                              controller: _confirmPasswordController,
                              hint: 'Re-enter new password',
                              visible: _showConfirm,
                              onToggle: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildPasswordField(
                            label: 'New Password',
                            controller: _newPasswordController,
                            hint: 'Enter new password',
                            visible: _showNew,
                            onToggle: () =>
                                setState(() => _showNew = !_showNew),
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            label: 'Re-Enter Password',
                            controller: _confirmPasswordController,
                            hint: 'Re-enter new password',
                            visible: _showConfirm,
                            onToggle: () =>
                                setState(() => _showConfirm = !_showConfirm),
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Password requirements hint
                _PasswordRequirementsHint(),

                // Feedback banners for password
                if (_pwMessage != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(message: _pwMessage!, isError: false),
                ],
                if (_pwError != null) ...[
                  const SizedBox(height: 14),
                  _FeedbackBanner(message: _pwError!, isError: true),
                ],

                const SizedBox(height: 20),

                // Change Password button — right-aligned
                Align(
                  alignment: Alignment.centerRight,
                  child: _PrimaryButton(
                    label: 'Change Password',
                    loading: _savingPassword,
                    onPressed: _savingPassword ? null : _changePassword,
                    icon: Icons.lock_reset_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Email sub-section ────────────────────────────────────────────────────────
  Widget _buildEmailColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(label: 'Email Address', icon: Icons.email_outlined),
        const SizedBox(height: 14),

        // Email display field
        _buildField(
          label: 'Email',
          controller: _emailController,
          hint: 'Enter new email address',
          readOnly: !_editingEmail || _verificationPending,
        ),
        const SizedBox(height: 8),

        // ── Idle: show "Change Email" link ──────────────────────────
        if (!_editingEmail && !_verificationPending)
          GestureDetector(
            onTap: () => setState(() {
              _editingEmail = true;
              _emailError = null;
              _emailMessage = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EDD8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8D9B0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.edit_outlined, size: 13, color: Color(0xFFB8882A)),
                  SizedBox(width: 6),
                  Text(
                    'Click to Edit',
                    style: TextStyle(
                      color: Color(0xFFB8882A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Editing: show password confirm + Send Verification / Cancel ──
        if (_editingEmail && !_verificationPending) ...[
          const SizedBox(height: 14),
          _buildPasswordField(
            label: 'Current Password',
            controller: _emailPasswordCtrl,
            hint: 'Enter your password to confirm',
            visible: _showEmailPassword,
            onToggle: () =>
                setState(() => _showEmailPassword = !_showEmailPassword),
          ),
          if (_emailError != null) ...[
            const SizedBox(height: 10),
            _FeedbackBanner(message: _emailError!, isError: true),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  label: 'Send Verification',
                  loading: _savingEmail,
                  onPressed: _savingEmail ? null : _changeEmail,
                  icon: Icons.send_outlined,
                ),
              ),
              const SizedBox(width: 10),
              _SecondaryButton(
                label: 'Cancel',
                onPressed: _savingEmail
                    ? null
                    : () => setState(() {
                        _editingEmail = false;
                        _emailError = null;
                        _emailMessage = null;
                        _emailPasswordCtrl.clear();
                        _showEmailPassword = false;
                        _emailController.text = _originalEmail;
                      }),
              ),
            ],
          ),
        ],

        // ── Pending verification ──────────────────────────────────────
        if (_verificationPending) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4A94D), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A94D).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Color(0xFF92400E),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verification Email Sent',
                            style: TextStyle(
                              color: Color(0xFF78350F),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A verification link was sent to $_pendingNewEmail. Click the link in your inbox, then tap "I\'ve Verified" below.',
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_emailError != null) ...[
                  const SizedBox(height: 10),
                  _FeedbackBanner(message: _emailError!, isError: true),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryButton(
                        label: _checkingVerification
                            ? 'Checking...'
                            : "I've Verified",
                        loading: _checkingVerification,
                        onPressed: _checkingVerification
                            ? null
                            : _checkVerification,
                        icon: Icons.verified_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _SecondaryButton(
                      label: 'Cancel',
                      onPressed: _checkingVerification
                          ? null
                          : () => setState(() {
                              _verificationPending = false;
                              _pendingNewEmail = '';
                              _pendingPassword = '';
                              _emailError = null;
                              _emailController.text = _originalEmail;
                            }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        // ── Success banner ──────────────────────────────────────────────
        if (_emailMessage != null) ...[
          const SizedBox(height: 10),
          _FeedbackBanner(message: _emailMessage!, isError: false),
        ],
      ],
    );
  }

  // ── Text field ───────────────────────────────────────────────────────────────
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
            color: Color(0xFF4A4A6A),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? const Color(0xFF7A7A9A) : const Color(0xFF1A1A2E),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFAAAAAC),
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: readOnly
                ? const Color(0xFFF8F6F2)
                : const Color(0xFFFDFBF8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDED8CC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDED8CC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFD4A94D),
                width: 1.8,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEEEAE2)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Password field ───────────────────────────────────────────────────────────
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
            color: Color(0xFF4A4A6A),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFAAAAAC),
              fontSize: 13.5,
            ),
            filled: true,
            fillColor: const Color(0xFFFDFBF8),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                visible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: const Color(0xFF9A9AB0),
                size: 18,
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDED8CC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDED8CC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFD4A94D),
                width: 1.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Password requirements hint ─────────────────────────────────────────────────
class _PasswordRequirementsHint extends StatelessWidget {
  const _PasswordRequirementsHint();

  @override
  Widget build(BuildContext context) {
    const reqs = [
      'At least 8 characters',
      'Uppercase and lowercase letters (A–Z, a–z)',
      'At least one number (0–9)',
      'At least one special character (!@#\$%^&* …)',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E0D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: Color(0xFF7A7A9A),
              ),
              SizedBox(width: 6),
              Text(
                'Password requirements',
                style: TextStyle(
                  color: Color(0xFF4A4A6A),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...reqs.map(
            (req) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 8, left: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD4A94D),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      req,
                      style: const TextStyle(
                        color: Color(0xFF6A6A8A),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary action button ──────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A94D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE8D09A),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Secondary (outline) button ─────────────────────────────────────────────────
class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4A4A6A),
          side: const BorderSide(color: Color(0xFFCCC8BE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
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
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5EDD8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFFD4A94D), size: 15),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(child: Divider(color: Color(0xFFEEE8DC), thickness: 1)),
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
    final color = isError ? const Color(0xFFDC2626) : const Color(0xFF166534);
    final bgColor = isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4);
    final borderColor = isError
        ? const Color(0xFFFECACA)
        : const Color(0xFFBBF7D0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
