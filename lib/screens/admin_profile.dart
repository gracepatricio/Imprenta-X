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

  // ── Section divider ──────────────────────────────────────────────────────────
  Widget _section(String title) => Row(children: [
    Text(title,
        style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
  ]);


  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white38),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage Account',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // ── Personal Information ─────────────────────────────────────────
          _section('Personal Information'),
          const SizedBox(height: 12),
          _field(label: 'Full Name', ctrl: _nameController),
          const SizedBox(height: 10),

          // ── Email (changeable) ───────────────────────────────────────────
          if (!_editingEmail && !_verificationPending) ...[
            Row(
              children: [
                Expanded(child: _field(label: 'Email', ctrl: _emailController, readOnly: true)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _editingEmail = true;
                    _emailError = null;
                    _emailMessage = null;
                    _emailPasswordCtrl.clear();
                  }),
                  icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.gold),
                  label: const Text('Change', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                ),
              ],
            ),
          ] else if (_editingEmail && !_verificationPending) ...[
            _field(label: 'New Email Address', ctrl: _emailController),
            const SizedBox(height: 10),
            _pwField(
              label: 'Current Password (to confirm)',
              ctrl: _emailPasswordCtrl,
              show: _showEmailPassword,
              toggle: () => setState(() => _showEmailPassword = !_showEmailPassword),
            ),
            if (_emailError != null) ...[
              const SizedBox(height: 8),
              _banner(_emailError!, true),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
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
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savingEmail ? null : _changeEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: _savingEmail
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                      : const Text('Send Verification', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ] else if (_verificationPending) ...[
            _field(label: 'Email', ctrl: _emailController, readOnly: true),
            const SizedBox(height: 10),
            _banner(
              'Verification email sent to $_pendingNewEmail.\nClick the link in your inbox, then tap "I\'ve Verified" below.',
              false,
            ),
            if (_emailError != null) ...[
              const SizedBox(height: 8),
              _banner(_emailError!, true),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold)),
                const SizedBox(width: 10),
                const Text('Waiting for verification…',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _checkingVerification
                      ? null
                      : () => setState(() {
                    _verificationPending = false;
                    _pendingNewEmail = '';
                    _pendingPassword = '';
                    _emailError = null;
                    _emailController.text = _originalEmail;
                  }),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _checkingVerification ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: _checkingVerification
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                      : const Text("I've Verified", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ],

          if (_emailMessage != null) ...[
            const SizedBox(height: 8),
            _banner(_emailMessage!, false),
          ],

          if (_infoMessage != null) ...[
            const SizedBox(height: 8),
            _banner(_infoMessage!, false),
          ],
          if (_infoError != null) ...[
            const SizedBox(height: 8),
            _banner(_infoError!, true),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingInfo ? null : _savePersonalInfo,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: _savingInfo
                  ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                  : const Text('Save Name', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 24),

          // ── Change Password ──────────────────────────────────────────────
          _section('Change Password'),
          const SizedBox(height: 12),
          _pwField(
            label: 'Current Password',
            ctrl: _currentPasswordController,
            show: _showCurrent,
            toggle: () => setState(() => _showCurrent = !_showCurrent),
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'New Password',
            ctrl: _newPasswordController,
            show: _showNew,
            toggle: () => setState(() => _showNew = !_showNew),
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'Confirm New Password',
            ctrl: _confirmPasswordController,
            show: _showConfirm,
            toggle: () => setState(() => _showConfirm = !_showConfirm),
          ),
          const SizedBox(height: 10),
          _passwordRequirementsHint(),
          if (_pwMessage != null) ...[
            const SizedBox(height: 8),
            _banner(_pwMessage!, false),
          ],
          if (_pwError != null) ...[
            const SizedBox(height: 8),
            _banner(_pwError!, true),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingPassword ? null : _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: _savingPassword
                  ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                  : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Input helpers ─────────────────────────────────────────────────────────────

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    bool readOnly = false,
  }) =>
      TextField(
        controller: ctrl,
        readOnly: readOnly,
        style: TextStyle(
          color: readOnly ? Colors.white54 : Colors.white,
          fontSize: 14,
        ),
        decoration: AppTheme.inputDecoration(label),
      );

  Widget _pwField({
    required String label,
    required TextEditingController ctrl,
    required bool show,
    required VoidCallback toggle,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: !show,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: AppTheme.inputDecoration(
          label,
          icon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(
              show ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54,
              size: 18,
            ),
            onPressed: toggle,
          ),
        ),
      );

  Widget _banner(String msg, bool isError) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.35),
      ),
    ),
    child: Row(children: [
      Icon(
        isError ? Icons.error_outline : Icons.check_circle_outline,
        color: isError ? Colors.redAccent : Colors.greenAccent,
        size: 15,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          msg,
          style: TextStyle(
            color: isError ? Colors.redAccent : Colors.greenAccent,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ),
    ]),
  );

  Widget _passwordRequirementsHint() {
    const reqs = [
      'At least 8 characters',
      'Uppercase and lowercase letters (A–Z, a–z)',
      'At least one number (0–9)',
      'At least one special character (!@#\$%^&* …)',
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, size: 13, color: Colors.white38),
            SizedBox(width: 6),
            Text('Password requirements',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ...reqs.map((req) => Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(right: 8, left: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gold,
                ),
              ),
              Expanded(
                child: Text(req,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11.5,
                        height: 1.4)),
              ),
            ]),
          )),
        ],
      ),
    );
  }
}