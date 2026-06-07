import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// =============================================================================
// Design Tokens (mirrors AdminProfile _G)
// =============================================================================
class _G {
  static const Color navyBlue = Color(0xFF0F1A2E);
  static const Color surface = Color(0xFFF7F8FA);
  static const Color surfaceMid = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);
  static const Color borderTop = Color(0xE0FFFFFF);
  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);
  static const Color inputBorder = Color(0xFFD8DCE4);
  static const Color stepHeader = Color(0xFFECEEF2);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted = Color(0x880F172A);

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFEF4444);

  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static BoxDecoration card({
    Color? color,
    double radius = 16,
    bool elevated = false,
    Color? tintBorder,
  }) => BoxDecoration(
    color: color ?? surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: tintBorder ?? borderMid, width: 0.9),
    boxShadow: [
      elevated
          ? const BoxShadow(
              color: Color(0x22000000),
              blurRadius: 32,
              spreadRadius: -4,
              offset: Offset(0, 8),
            )
          : rowShadow,
    ],
  );

  static BoxDecoration pill({Color? tint}) => BoxDecoration(
    color: tint != null ? tint.withValues(alpha: 0.15) : surfaceThin,
    borderRadius: BorderRadius.circular(99),
    border: Border.all(
      color: tint != null ? tint.withValues(alpha: 0.50) : borderMid,
      width: 0.9,
    ),
  );
}

// =============================================================================
// Unified Input Decoration helper
// =============================================================================
InputDecoration _inputDec({
  required String label,
  IconData? prefixIcon,
  Widget? suffix,
  Color? accentColor,
}) {
  final accent = accentColor ?? _G.navyBlue;
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _G.textMuted, fontSize: 13),
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: accent.withValues(alpha: 0.55), size: 17)
        : null,
    suffixIcon: suffix,
    filled: true,
    fillColor: _G.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _G.inputBorder, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: accent, width: 1.8),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _G.inputBorder, width: 1.0),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _G.accentRose, width: 1.2),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _G.accentRose, width: 1.8),
    ),
  );
}

// =============================================================================
// EmployeeManageAccount  (mirrors AdminProfile logic exactly)
// =============================================================================
class EmployeeManageAccount extends StatefulWidget {
  final void Function(String newName)? onNameUpdated;
  final void Function(String newEmail)? onEmailUpdated;
  const EmployeeManageAccount({
    super.key,
    this.onNameUpdated,
    this.onEmailUpdated,
  });

  @override
  State<EmployeeManageAccount> createState() => _EmployeeManageAccountState();
}

class _EmployeeManageAccountState extends State<EmployeeManageAccount>
    with SingleTickerProviderStateMixin {
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

  // ── Password (two-step) ────────────────────────────────────────
  int _pwStep = 0;
  bool _verifyingCurrent = false;
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

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _loadUser();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _emailPasswordCtrl.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Load ───────────────────────────────────────────────────────
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

  // ── Save name ──────────────────────────────────────────────────
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
      await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
        'full_name': name,
      });
      await user.updateDisplayName(name);
      await user.reload();
      if (mounted) {
        widget.onNameUpdated?.call(name);
        setState(() {
          _infoMessage = 'Name updated successfully.';
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

  // ── Email change ───────────────────────────────────────────────
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
      final isVerified = (user.email ?? '') == _pendingNewEmail;
      if (!isVerified) {
        if (mounted)
          setState(() {
            _emailError =
                'Email not verified yet. Please check your inbox and click the link, then try again.';
            _checkingVerification = false;
          });
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
          final u = cred.user;
          if (u != null && u.email == _pendingNewEmail) {
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
      if (mounted)
        setState(() {
          _emailError = 'Verification check failed: $e';
          _checkingVerification = false;
        });
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
      if (emailToDelete.isNotEmpty && emailToDelete != newEmail)
        batch.delete(db.collection('email_index').doc(emailToDelete));
      batch.set(db.collection('email_index').doc(newEmail), {
        'uid': user.uid,
        'status': 'active',
      });
      batch.set(db.collection('AuthIndex').doc(user.uid), {
        'placeholder_email': newEmail,
      });
      await batch.commit();
      try {
        final stale = await db
            .collection('email_index')
            .where('uid', isEqualTo: user.uid)
            .get();
        for (final doc in stale.docs)
          if (doc.id != newEmail) await doc.reference.delete();
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
      if (mounted)
        setState(() {
          _emailError = 'Failed to save email change: $e';
          _checkingVerification = false;
        });
    }
  }

  // ── PASSWORD: Two-step ─────────────────────────────────────────
  Future<void> _verifyCurrentPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final current = _currentPasswordController.text;
    if (current.isEmpty) {
      setState(() {
        _pwError = 'Please enter your current password.';
        _pwMessage = null;
      });
      return;
    }
    setState(() {
      _verifyingCurrent = true;
      _pwError = null;
      _pwMessage = null;
    });
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: current,
      );
      await user.reauthenticateWithCredential(credential);
      if (mounted) {
        _slideCtrl.reset();
        setState(() {
          _verifyingCurrent = false;
          _pwStep = 1;
          _pwError = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _slideCtrl.forward();
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-password':
          msg = 'Incorrect password. Please try again.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait and try again.';
          break;
        default:
          msg = 'Error (${e.code}): ${e.message ?? 'Please try again.'}';
      }
      if (mounted)
        setState(() {
          _pwError = msg;
          _verifyingCurrent = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _pwError = 'Unexpected error: $e';
          _verifyingCurrent = false;
        });
    }
  }

  String? _validateNewPassword(String pw) {
    if (pw.length < 8) return 'Password must be at least 8 characters.';
    if (!pw.contains(RegExp(r'[A-Z]')))
      return 'Must contain at least one uppercase letter.';
    if (!pw.contains(RegExp(r'[a-z]')))
      return 'Must contain at least one lowercase letter.';
    if (!pw.contains(RegExp(r'[0-9]')))
      return 'Must contain at least one number.';
    if (!pw.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~;]')))
      return 'Must contain at least one special character.';
    return null;
  }

  Future<void> _setNewPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newPw = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPw.isEmpty || confirm.isEmpty) {
      setState(() {
        _pwError = 'Please fill in all fields.';
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
      await user.updatePassword(newPw);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          errorMsg = 'New password is too weak.';
          break;
        case 'requires-recent-login':
          errorMsg = 'Session expired. Please log out and log back in.';
          break;
        case 'network-request-failed':
          errorMsg = 'Network error. Please check your connection.';
          break;
        default:
          errorMsg = 'Error (${e.code}): ${e.message ?? 'Please try again.'}';
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
        _pwStep = 0;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    }
  }

  void _resetPwFlow() {
    setState(() {
      _pwStep = 0;
      _pwError = null;
      _pwMessage = null;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  // ── UI Helpers ─────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1.0,
              ),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: _G.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1.2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.22), Colors.transparent],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool loading = false,
    Color? color,
  }) {
    final c = color ?? _G.navyBlue;
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: c,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.withValues(alpha: 0.55),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        ),
        icon: loading
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _outlinedBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final c = color ?? _G.accentViolet;
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.55), width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          backgroundColor: c.withValues(alpha: 0.05),
        ),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  Widget _glassField({
    required String label,
    required TextEditingController ctrl,
    bool readOnly = false,
    IconData? prefixIcon,
    Color? accentColor,
  }) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? _G.textMuted : _G.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDec(
        label: label,
        prefixIcon: prefixIcon,
        accentColor: accentColor,
      ),
    );
  }

  Widget _pwField({
    required String label,
    required TextEditingController ctrl,
    required bool show,
    required VoidCallback toggle,
    Color? accentColor,
  }) => TextField(
    controller: ctrl,
    obscureText: !show,
    style: const TextStyle(
      color: _G.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    ),
    decoration: _inputDec(
      label: label,
      prefixIcon: Icons.lock_outline_rounded,
      accentColor: accentColor,
      suffix: IconButton(
        icon: Icon(
          show ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          color: _G.textMuted,
          size: 17,
        ),
        onPressed: toggle,
      ),
    ),
  );

  Widget _banner(String msg, bool isError) {
    final color = isError ? _G.accentRose : _G.accentEmerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.9),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
              size: 13,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _requirementsHint() {
    const reqs = [
      'At least 8 characters',
      'Uppercase & lowercase letters',
      'At least one number (0–9)',
      'At least one special character (!@#\$%…)',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _G.navyBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _G.navyBlue.withValues(alpha: 0.10),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, size: 12, color: _G.navyBlue),
              SizedBox(width: 6),
              Text(
                'Password requirements',
                style: TextStyle(
                  color: _G.navyBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...reqs.map(
            (req) => Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(right: 8, left: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _G.navyBlue.withValues(alpha: 0.35),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      req,
                      style: const TextStyle(
                        color: _G.textSecondary,
                        fontSize: 11,
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

  Widget _passwordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _G.inputBorder, width: 1.0),
        boxShadow: const [_G.rowShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step track header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: const BoxDecoration(
              color: _G.stepHeader,
              border: Border(
                bottom: BorderSide(color: Color(0xFFD0D5DD), width: 0.9),
              ),
            ),
            child: Row(
              children: [
                _StepChip(
                  number: 1,
                  label: 'Verify Identity',
                  isActive: _pwStep == 0,
                  isDone: _pwStep > 0,
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(height: 2, color: const Color(0xFFD0D5DD)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        height: 2,
                        width: _pwStep >= 1 ? double.infinity : 0,
                        color: _G.accentEmerald,
                      ),
                    ],
                  ),
                ),
                _StepChip(
                  number: 2,
                  label: 'New Password',
                  isActive: _pwStep == 1,
                  isDone: false,
                ),
              ],
            ),
          ),
          // Step content
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _pwStep == 0 ? _step0() : _step1(),
          ),
        ],
      ),
    );
  }

  Widget _step0() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Enter your current password to proceed',
        style: TextStyle(color: _G.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 10),
      _pwField(
        label: 'Current Password',
        ctrl: _currentPasswordController,
        show: _showCurrent,
        toggle: () => setState(() => _showCurrent = !_showCurrent),
        accentColor: _G.navyBlue,
      ),
      if (_pwError != null) ...[
        const SizedBox(height: 8),
        _banner(_pwError!, true),
      ],
      if (_pwMessage != null) ...[
        const SizedBox(height: 8),
        _banner(_pwMessage!, false),
      ],
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _primaryBtn(
            label: 'Verify & Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: _verifyingCurrent ? null : _verifyCurrentPassword,
            loading: _verifyingCurrent,
          ),
        ],
      ),
    ],
  );

  Widget _step1() => SlideTransition(
    position: _slideAnim,
    child: FadeTransition(
      opacity: _slideCtrl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose a strong new password',
            style: TextStyle(color: _G.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'New Password',
            ctrl: _newPasswordController,
            show: _showNew,
            toggle: () => setState(() => _showNew = !_showNew),
            accentColor: _G.accentEmerald,
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'Confirm New Password',
            ctrl: _confirmPasswordController,
            show: _showConfirm,
            toggle: () => setState(() => _showConfirm = !_showConfirm),
            accentColor: _G.accentEmerald,
          ),
          const SizedBox(height: 12),
          _requirementsHint(),
          if (_pwError != null) ...[
            const SizedBox(height: 8),
            _banner(_pwError!, true),
          ],
          if (_pwMessage != null) ...[
            const SizedBox(height: 8),
            _banner(_pwMessage!, false),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _resetPwFlow,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: _G.textMuted,
                ),
                label: const Text(
                  'Back',
                  style: TextStyle(
                    color: _G.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _primaryBtn(
                label: 'Change Password',
                icon: Icons.check_rounded,
                onPressed: _savingPassword ? null : _setNewPassword,
                loading: _savingPassword,
                color: _G.accentEmerald,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(child: CircularProgressIndicator(color: _G.navyBlue));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Title ─────────────────────────────────────────
          const Text(
            'Profile',
            style: TextStyle(
              color: _G.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // ── Personal Information ───────────────────────────────
          _sectionHeader(
            'Personal Information',
            Icons.person_outline_rounded,
            _G.navyBlue,
          ),
          _glassField(
            label: 'Full Name',
            ctrl: _nameController,
            prefixIcon: Icons.person_outline_rounded,
            accentColor: _G.navyBlue,
          ),
          if (_infoError != null) ...[
            const SizedBox(height: 8),
            _banner(_infoError!, true),
          ],
          if (_infoMessage != null) ...[
            const SizedBox(height: 8),
            _banner(_infoMessage!, false),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _primaryBtn(
                label: 'Save Name',
                icon: Icons.save_rounded,
                onPressed: _savingInfo ? null : _savePersonalInfo,
                loading: _savingInfo,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── Email Address ──────────────────────────────────────
          _sectionHeader(
            'Email Address',
            Icons.email_outlined,
            _G.accentViolet,
          ),
          _glassField(
            label: 'Email',
            ctrl: _emailController,
            readOnly: !_editingEmail && !_verificationPending,
            prefixIcon: Icons.email_outlined,
            accentColor: _G.accentViolet,
          ),

          if (!_editingEmail && !_verificationPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _outlinedBtn(
                  label: 'Change Email',
                  icon: Icons.edit_outlined,
                  color: _G.accentViolet,
                  onPressed: () => setState(() {
                    _editingEmail = true;
                    _emailError = null;
                    _emailMessage = null;
                    _emailPasswordCtrl.clear();
                  }),
                ),
              ],
            ),
          ] else if (_editingEmail && !_verificationPending) ...[
            const SizedBox(height: 10),
            _pwField(
              label: 'Current Password (to confirm)',
              ctrl: _emailPasswordCtrl,
              show: _showEmailPassword,
              toggle: () =>
                  setState(() => _showEmailPassword = !_showEmailPassword),
              accentColor: _G.accentViolet,
            ),
            if (_emailError != null) ...[
              const SizedBox(height: 8),
              _banner(_emailError!, true),
            ],
            const SizedBox(height: 12),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: _G.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _primaryBtn(
                  label: 'Send Verification',
                  icon: Icons.send_rounded,
                  color: _G.accentViolet,
                  onPressed: _savingEmail ? null : _changeEmail,
                  loading: _savingEmail,
                ),
              ],
            ),
          ] else if (_verificationPending) ...[
            const SizedBox(height: 10),
            _banner(
              'Verification email sent to $_pendingNewEmail.\nClick the link in your inbox, then tap "I\'ve Verified" below.',
              false,
            ),
            if (_emailError != null) ...[
              const SizedBox(height: 8),
              _banner(_emailError!, true),
            ],
            const SizedBox(height: 10),
            Row(
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _G.accentViolet,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  'Waiting for verification…',
                  style: TextStyle(color: _G.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: _G.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _primaryBtn(
                  label: "I've Verified",
                  icon: Icons.verified_rounded,
                  color: _G.accentViolet,
                  onPressed: _checkingVerification ? null : _checkVerification,
                  loading: _checkingVerification,
                ),
              ],
            ),
          ],

          if (_emailMessage != null) ...[
            const SizedBox(height: 8),
            _banner(_emailMessage!, false),
          ],

          const SizedBox(height: 22),

          // ── Change Password ────────────────────────────────────
          _sectionHeader(
            'Change Password',
            Icons.lock_outline_rounded,
            _G.accentEmerald,
          ),
          _passwordSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// =============================================================================
// Step Chip (identical to AdminProfile's)
// =============================================================================
class _StepChip extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepChip({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    Color dotBg, dotFg, labelColor;
    if (isDone) {
      dotBg = _G.accentEmerald;
      dotFg = Colors.white;
      labelColor = _G.accentEmerald;
    } else if (isActive) {
      dotBg = _G.navyBlue;
      dotFg = Colors.white;
      labelColor = _G.navyBlue;
    } else {
      dotBg = Colors.transparent;
      dotFg = _G.textMuted;
      labelColor = _G.textMuted;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotBg,
            border: Border.all(
              color: isDone
                  ? _G.accentEmerald
                  : isActive
                  ? _G.navyBlue
                  : const Color(0xFFD0D5DD),
              width: 1.8,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _G.navyBlue.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: dotFg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
