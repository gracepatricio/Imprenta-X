import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class EmployeeManageAccount extends StatefulWidget {
  final void Function(String newName)? onNameUpdated;
  const EmployeeManageAccount({super.key, this.onNameUpdated});

  @override
  State<EmployeeManageAccount> createState() => _EmployeeManageAccountState();
}

class _EmployeeManageAccountState extends State<EmployeeManageAccount> {
  // ── Personal Info ──────────────────────────────────────────────
  final _nameController  = TextEditingController();
  final _emailController = TextEditingController();
  bool _savingInfo = false;

  // ── Password ───────────────────────────────────────────────────
  final _currentPasswordController = TextEditingController();
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrent = false;
  bool _showNew     = false;
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
        _infoError   = 'Full name cannot be empty.';
        _infoMessage = null;
      });
      return;
    }
    setState(() {
      _savingInfo  = true;
      _infoError   = null;
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
          _infoError   = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _infoError   = 'Failed to update: ${e.toString()}';
          _infoMessage = null;
        });
      }
    } finally {
      if (mounted) setState(() => _savingInfo = false);
    }
  }

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _pwError   = 'No user session found. Please log in again.';
        _pwMessage = null;
      });
      return;
    }

    final current = _currentPasswordController.text;
    final newPw   = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      setState(() {
        _pwError   = 'Please fill in all password fields.';
        _pwMessage = null;
      });
      return;
    }
    if (newPw.length < 6) {
      setState(() {
        _pwError   = 'New password must be at least 6 characters.';
        _pwMessage = null;
      });
      return;
    }
    if (newPw != confirm) {
      setState(() {
        _pwError   = 'New passwords do not match.';
        _pwMessage = null;
      });
      return;
    }

    setState(() {
      _savingPassword = true;
      _pwError        = null;
      _pwMessage      = null;
    });

    String? errorMsg;

    try {
      debugPrint('[PW] Step 1: reauthenticating ${user.email}');
      final credential = EmailAuthProvider.credential(
        email:    user.email!,
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
        _pwError        = errorMsg;
        _pwMessage      = null;
        _savingPassword = false;
      });
    } else {
      setState(() {
        _pwMessage      = 'Password changed successfully.';
        _pwError        = null;
        _savingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white54));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage Account',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _buildPhotoRow(),
          const SizedBox(height: 28),

          // ── Personal Information ───────────────────────────────
          _sectionTitle('Personal Information'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildField(
                  label:      'Full Name',
                  controller: _nameController,
                  hint:       'Enter your full name',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildField(
                  label:      'Email Address',
                  controller: _emailController,
                  hint:       'Email address',
                  readOnly:   true,
                ),
              ),
            ],
          ),
          if (_infoMessage != null) ...[
            const SizedBox(height: 10),
            _feedbackBanner(message: _infoMessage!, isError: false),
          ],
          if (_infoError != null) ...[
            const SizedBox(height: 10),
            _feedbackBanner(message: _infoError!, isError: true),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _savingInfo ? null : _savePersonalInfo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: _savingInfo
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black54))
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Change Password ────────────────────────────────────
          _sectionTitle('Change Password'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPasswordField(
                  label:      'Current Password',
                  controller: _currentPasswordController,
                  hint:       'Enter your current password',
                  visible:    _showCurrent,
                  onToggle:   () =>
                      setState(() => _showCurrent = !_showCurrent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPasswordField(
                  label:      'New Password',
                  controller: _newPasswordController,
                  hint:       'Enter your new password',
                  visible:    _showNew,
                  onToggle:   () => setState(() => _showNew = !_showNew),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildPasswordField(
                  label:      'Confirm New Password',
                  controller: _confirmPasswordController,
                  hint:       'Re-enter your new password',
                  visible:    _showConfirm,
                  onToggle:   () =>
                      setState(() => _showConfirm = !_showConfirm),
                ),
              ),
              // Empty right column to keep layout consistent
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Min. 8 Characters',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
          if (_pwMessage != null) ...[
            const SizedBox(height: 10),
            _feedbackBanner(message: _pwMessage!, isError: false),
          ],
          if (_pwError != null) ...[
            const SizedBox(height: 10),
            _feedbackBanner(message: _pwError!, isError: true),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _savingPassword ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                ),
                child: _savingPassword
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black54))
                    : const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────

  Widget _buildPhotoRow() {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white30, width: 1.5),
          ),
          child: const Icon(Icons.person, size: 32, color: Colors.white70),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload a new profile photo',
                style: TextStyle(color: Colors.white, fontSize: 13)),
            const Text('Accepted formats: JPG and PNG (max 5MB)',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo upload coming soon.'),
                    backgroundColor: Colors.black54,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: const Text('Choose a Photo',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1),
        ),
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
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          style: TextStyle(
              color: readOnly ? Colors.white60 : Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
            filled: true,
            fillColor: readOnly
                ? Colors.white.withOpacity(0.08)
                : Colors.white.withOpacity(0.15),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white54),
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
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !visible,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54, fontSize: 14),
            filled: true,
            fillColor: Colors.white.withOpacity(0.15),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(visible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white60, size: 20),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedbackBanner({required String message, required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withOpacity(0.15)
            : Colors.green.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? Colors.red.withOpacity(0.4)
              : Colors.green.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.redAccent : Colors.greenAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: isError ? Colors.redAccent : Colors.greenAccent,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
