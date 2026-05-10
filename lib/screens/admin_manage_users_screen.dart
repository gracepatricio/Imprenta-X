import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  // Softer premium white glass
  static const Color surface = Color.fromARGB(109, 255, 255, 255);
  static const Color surfaceStrong = Color.fromARGB(125, 255, 255, 255);

  // Cleaner subtle borders
  static const Color border = Color(0x50FFFFFF);
  static const Color borderSubtle = Color(0x25FFFFFF);

  // Typography
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF3A3A52);
  static const Color textMuted = Color.fromARGB(255, 47, 47, 83);

  // Softer luxury gold
  static const Color gold = Color(0xFFD4A94D);
  static const Color goldGlow = Color(0x30D4A94D);
  static const Color goldBorder = Color(0x55D4A94D);
  static const Color goldBtnText = Color(0xFF1A1205);

  // Role palette
  static const Color adminFg = Color(0xFF5B21B6);
  static const Color adminBg = Color(0x157C3AED);
  static const Color adminBorder = Color(0x457C3AED);
  static const Color empFg = Color(0xFF0F766E);
  static const Color empBg = Color(0x150D9488);
  static const Color empBorder = Color(0x450D9488);
  static const Color cusFg = Color(0xFF1D4ED8);
  static const Color cusBg = Color(0x151D4ED8);
  static const Color cusBorder = Color(0x451D4ED8);

  // Status
  static const Color activeGreen = Color(0xFF22C55E);
  static const Color activeGreenFg = Color(0xFF166534);
  static const Color disabledAmber = Color(0xFFF59E0B);
  static const Color disabledAmberFg = Color(0xFF92400E);

  static BoxDecoration panelDecoration({
    double radius = 16,
    Color bg = surface,
    Color borderColor = border,
  }) {
    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x20FFFFFF),
          blurRadius: 1,
          offset: Offset(0, 1),
          spreadRadius: -1,
        ),
      ],
    );
  }
}

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final AuthService _authService = AuthService();
  bool _isCreating = false;

  String _searchQuery = '';
  String _roleFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  static const _roles = ['All', 'Admin', 'Employee', 'Customer'];

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtering & Sorting ───────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _filtered(List<QueryDocumentSnapshot> docs) {
    var result = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['is_deleted'] == true) return false;

      final name = (data['full_name'] as String? ?? '').toLowerCase();
      final email = (data['email'] as String? ?? '').toLowerCase();
      final role = (data['user_role'] as String? ?? '').toLowerCase();
      final cusId = (data['customer_id'] as String? ?? '').toLowerCase();
      final empId = (data['employee_id'] as String? ?? '').toLowerCase();
      final uid = doc.id.toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch =
          q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          cusId.contains(q) ||
          empId.contains(q) ||
          uid.contains(q);
      final matchesRole =
          _roleFilter == 'All' || role == _roleFilter.toLowerCase();
      return matchesSearch && matchesRole;
    }).toList();

    result.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      String aVal = '', bVal = '';
      switch (_sortColumnIndex) {
        case 0:
          aVal = (aData['full_name'] as String? ?? '').toLowerCase();
          bVal = (bData['full_name'] as String? ?? '').toLowerCase();
          break;
        case 1:
          aVal = (aData['user_role'] as String? ?? '').toLowerCase();
          bVal = (bData['user_role'] as String? ?? '').toLowerCase();
          break;
        case 2:
          aVal = _getDisplayIdFromData(aData).toLowerCase();
          bVal = _getDisplayIdFromData(bData).toLowerCase();
          break;
        case 3:
          aVal = (aData['email'] as String? ?? '').toLowerCase();
          bVal = (bData['email'] as String? ?? '').toLowerCase();
          break;
        case 4:
          aVal = (aData['is_disabled'] == true) ? 'disabled' : 'active';
          bVal = (bData['is_disabled'] == true) ? 'disabled' : 'active';
          break;
      }
      return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
    });

    return result;
  }

  // ── Create account helpers ────────────────────────────────────────────────

  Future<void> _createEmployee() async {
    setState(() => _isCreating = true);
    final result = await _authService.createEmployeeAccount();
    if (!mounted) return;
    setState(() => _isCreating = false);
    if (result.error != null) {
      _snack(result.error!, isError: true);
      return;
    }

    String employeeId = '';
    if (result.uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('User')
            .doc(result.uid)
            .get();
        employeeId = doc.data()?['employee_id'] as String? ?? '';
      } catch (_) {}
    }
    if (mounted)
      _showCredentialsDialog(
        role: 'Employee',
        idLabel: 'Employee ID',
        idValue: employeeId,
        password: result.password!,
      );
  }

  Future<void> _createAdmin() async {
    setState(() => _isCreating = true);
    final result = await _authService.createAdminAccount();
    if (!mounted) return;
    setState(() => _isCreating = false);
    if (result.error != null) {
      _snack(result.error!, isError: true);
      return;
    }
    if (mounted)
      _showCredentialsDialog(
        role: 'Admin',
        idLabel: 'UID',
        idValue: result.uid ?? '',
        password: result.password!,
      );
  }

  void _showCredentialsDialog({
    required String role,
    required String idLabel,
    required String idValue,
    required String password,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x801A1A2E),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        content: _dialogCard(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dialogHeader(
                Icons.check_circle_outline,
                const Color(0xFF166534),
                const Color(0x1522C55E),
                const Color(0x4522C55E),
                '$role Account Created',
              ),
              const Divider(height: 1, color: Color(0x18000000)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hand these credentials to the new user.\nThey will be required to change their password on first login.',
                      style: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _credentialRow(idLabel, idValue),
                    const SizedBox(height: 10),
                    _credentialRow('Temp Password', password),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _Glass.goldGlow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _Glass.goldBorder),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF92620A),
                            size: 14,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The password is also stored and can be retrieved from the user\'s record if needed.',
                              style: TextStyle(
                                color: Color(0xFF78350F),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _GoldButton(
                      label: 'Done',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogCard({required double width, required Widget child}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x70FFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _dialogHeader(
    IconData icon,
    Color fg,
    Color bg,
    Color bdr,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bdr),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: _Glass.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0x25FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x50FFFFFF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: _Glass.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Copy $label',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  _snack('$label copied');
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _Glass.goldGlow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _Glass.goldBorder),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    color: _Glass.gold,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── User actions ──────────────────────────────────────────────────────────

  Future<void> _showTempPassword(
    String uid,
    String role,
    String displayId,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(uid)
        .get();
    final tempPw = doc.data()?['temp_password'] as String?;
    if (!mounted) return;
    if (tempPw == null || tempPw.isEmpty) {
      _snack('No temporary password stored for this user.');
      return;
    }

    showDialog(
      context: context,
      barrierColor: const Color(0x801A1A2E),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        content: _dialogCard(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(
                Icons.key_rounded,
                _Glass.gold,
                _Glass.goldGlow,
                _Glass.goldBorder,
                'Temporary Password',
              ),
              const Divider(height: 1, color: Color(0x18000000)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Column(
                  children: [
                    _credentialRow('ID', displayId),
                    const SizedBox(height: 10),
                    _credentialRow('Temp Password', tempPw),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: _Glass.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(String uid, String name) async {
    final confirmed = await _showGlassConfirm(
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      title: 'Delete User',
      content: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: _Glass.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'Are you sure you want to delete '),
            TextSpan(
              text: '"$name"',
              style: const TextStyle(
                color: _Glass.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(
              text:
                  '?\n\nThis will soft-delete the account. The user will no longer be able to sign in.',
            ),
          ],
        ),
      ),
      confirmLabel: 'Delete',
      confirmColor: Colors.redAccent,
    );
    if (confirmed == true) {
      final err = await _authService.deleteUser(uid);
      if (mounted)
        _snack(
          err == 'success'
              ? 'User deleted.'
              : (err ?? 'Failed to delete user.'),
          isError: err != 'success',
        );
    }
  }

  Future<void> _confirmToggleDisable(
    String uid,
    String name,
    bool currentlyDisabled,
  ) async {
    final action = currentlyDisabled ? 'enable' : 'disable';
    final actionColor = currentlyDisabled
        ? const Color(0xFF166534)
        : Colors.orange.shade700;
    final confirmed = await _showGlassConfirm(
      icon: currentlyDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
      iconColor: actionColor,
      title: '${action[0].toUpperCase()}${action.substring(1)} User',
      content: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: _Glass.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
          children: [
            TextSpan(text: 'Are you sure you want to $action '),
            TextSpan(
              text: '"$name"',
              style: const TextStyle(
                color: _Glass.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const TextSpan(text: '?'),
          ],
        ),
      ),
      confirmLabel: '${action[0].toUpperCase()}${action.substring(1)}',
      confirmColor: actionColor,
    );
    if (confirmed == true) {
      final err = await _authService.toggleDisableUser(uid, !currentlyDisabled);
      if (mounted)
        _snack(
          err == 'success'
              ? 'User ${currentlyDisabled ? 'enabled' : 'disabled'}.'
              : (err ?? 'Action failed.'),
          isError: err != 'success',
        );
    }
  }

  Future<bool?> _showGlassConfirm({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget content,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: const Color(0x801A1A2E),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        content: _dialogCard(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogHeader(
                icon,
                iconColor,
                iconColor.withValues(alpha: 0.10),
                iconColor.withValues(alpha: 0.30),
                title,
              ),
              const Divider(height: 1, color: Color(0x18000000)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    content,
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: _Glass.textMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getDisplayIdFromData(Map<String, dynamic> data) {
    if (data['customer_id'] != null &&
        (data['customer_id'] as String).isNotEmpty)
      return data['customer_id'] as String;
    if (data['employee_id'] != null &&
        (data['employee_id'] as String).isNotEmpty)
      return data['employee_id'] as String;
    return data['uid'] as String? ?? '—';
  }

  String _getDisplayId(Map<String, dynamic> data) =>
      _getDisplayIdFromData(data);

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return _Glass.adminFg;
      case 'employee':
        return _Glass.empFg;
      default:
        return _Glass.cusFg;
    }
  }

  Color _roleBgColor(String role) {
    switch (role) {
      case 'admin':
        return _Glass.adminBg;
      case 'employee':
        return _Glass.empBg;
      default:
        return _Glass.cusBg;
    }
  }

  Color _roleBorderColor(String role) {
    switch (role) {
      case 'admin':
        return _Glass.adminBorder;
      case 'employee':
        return _Glass.empBorder;
      default:
        return _Glass.cusBorder;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'employee':
        return Icons.badge_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xCCB41E1E)
            : const Color(0xCC146B3A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No wrapping Container/background — this screen lives inside the parent's glass card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildToolbar(),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('User').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: CircularProgressIndicator(color: _Glass.gold),
                );
              if (snapshot.hasError) return _errorState('${snapshot.error}');
              final allDocs = snapshot.data?.docs ?? [];
              final filtered = _filtered(allDocs);
              if (allDocs.isEmpty) return _emptyState('No users found.');
              if (filtered.isEmpty)
                return _emptyState('No users match your search.');
              return _buildTable(filtered, allDocs.length);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: _Glass.panelDecoration(radius: 12),
          child: const Icon(
            Icons.people_alt_rounded,
            color: _Glass.gold,
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Users',
              style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'User accounts & access control',
              style: TextStyle(color: _Glass.textPrimary, fontSize: 11),
            ),
          ],
        ),
        const Spacer(),
        if (_isCreating)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _Glass.gold,
              ),
            ),
          ),
        _CreateButton(
          isCreating: _isCreating,
          onCreateEmployee: _createEmployee,
          onCreateAdmin: _createAdmin,
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name, email or ID…',
                hintStyle: const TextStyle(
                  color: _Glass.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _Glass.textMuted,
                  size: 18,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _Glass.textMuted,
                          size: 16,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: _Glass.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _Glass.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _Glass.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: _Glass.gold, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _RoleDropdown(
          value: _roleFilter,
          roles: _roles,
          onChanged: (v) => setState(() => _roleFilter = v),
        ),
      ],
    );
  }

  Widget _buildTable(List<QueryDocumentSnapshot> docs, int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                '${docs.length} user${docs.length == 1 ? '' : 's'}',
                style: const TextStyle(color: _Glass.textMuted, fontSize: 12),
              ),
              if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
                Text(
                  ' of $totalCount total',
                  style: const TextStyle(color: _Glass.textMuted, fontSize: 12),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _roleFilter = 'All';
                    });
                  },
                  child: const Text(
                    'Clear filters',
                    style: TextStyle(
                      color: _Glass.gold,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: _Glass.gold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: _Glass.panelDecoration(
              radius: 18,
              bg: _Glass.surfaceStrong,
              borderColor: _Glass.border,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  _buildTableHeader(),
                  Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.40),
                  ),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = Map<String, dynamic>.from(
                          doc.data() as Map<String, dynamic>,
                        );
                        data['uid'] = doc.id;
                        return _buildTableRow(doc.id, data, index.isEven);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    Widget sortHeader(String label, int colIndex, {int flex = 1}) {
      final isActive = _sortColumnIndex == colIndex;
      return Expanded(
        flex: flex,
        child: GestureDetector(
          onTap: () => setState(() {
            if (_sortColumnIndex == colIndex)
              _sortAscending = !_sortAscending;
            else {
              _sortColumnIndex = colIndex;
              _sortAscending = true;
            }
          }),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isActive ? _Glass.gold : _Glass.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                isActive
                    ? (_sortAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 12,
                color: isActive ? _Glass.gold : _Glass.textMuted,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0x14FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const SizedBox(width: 12),
          sortHeader('Name', 0, flex: 3),
          sortHeader('Role', 1, flex: 2),
          sortHeader('ID', 2, flex: 2),
          sortHeader('Email', 3, flex: 3),
          sortHeader('Status', 4, flex: 2),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(String uid, Map<String, dynamic> data, bool isEven) {
    final displayId = _getDisplayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String?)?.isNotEmpty == true
        ? data['email'] as String
        : '(not set)';
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;
    final roleColor = _roleColor(role);
    final roleBg = _roleBgColor(role);
    final roleBorder = _roleBorderColor(role);
    final initials = _getInitials(name);

    return Container(
      color: isEven ? const Color(0x0AFFFFFF) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: roleBorder, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                color: roleColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + pending badge
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: _Glass.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mustChange) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _Glass.goldGlow,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _Glass.goldBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: const Color.fromARGB(255, 194, 124, 2),
                          size: 9,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: const Color.fromARGB(255, 193, 110, 2),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Role badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: roleBorder, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcon(role), color: roleColor, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      role.isNotEmpty
                          ? role[0].toUpperCase() + role.substring(1)
                          : '—',
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ID — slate, not gold
          Expanded(
            flex: 2,
            child: Text(
              displayId,
              style: const TextStyle(
                color: _Glass.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Email
          Expanded(
            flex: 3,
            child: Text(
              email,
              style: TextStyle(
                color: email == '(not set)'
                    ? _Glass.textMuted
                    : _Glass.textSecondary,
                fontSize: 12,
                fontStyle: email == '(not set)'
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? _Glass.disabledAmber
                        : _Glass.activeGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isDisabled ? 'Disabled' : 'Active',
                  style: TextStyle(
                    color: isDisabled
                        ? _Glass.disabledAmberFg
                        : _Glass.activeGreenFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildActionMenu(uid, data, displayId, name, isDisabled),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(
    String uid,
    Map<String, dynamic> data,
    String displayId,
    String name,
    bool isDisabled,
  ) {
    final mustChange = data['must_change_password'] == true;
    final role = data['user_role'] as String? ?? '';

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: _Glass.textMuted, size: 18),
      color: const Color(0xEEFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0x50FFFFFF)),
      ),
      elevation: 16,
      offset: const Offset(0, 4),
      itemBuilder: (_) => [
        if (mustChange && (role == 'employee' || role == 'admin'))
          PopupMenuItem(
            value: 'show_password',
            child: _menuItem(
              Icons.key_rounded,
              'View Temp Password',
              _Glass.gold,
            ),
          ),
        PopupMenuItem(
          value: 'toggle_disable',
          child: _menuItem(
            isDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
            isDisabled ? 'Enable User' : 'Disable User',
            isDisabled ? _Glass.activeGreenFg : _Glass.disabledAmberFg,
          ),
        ),
        PopupMenuItem(
          value: 'copy_id',
          child: _menuItem(Icons.copy_rounded, 'Copy ID', _Glass.textSecondary),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(
            Icons.delete_outline_rounded,
            'Delete User',
            Colors.redAccent,
          ),
        ),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'show_password':
            await _showTempPassword(uid, role, displayId);
            break;
          case 'toggle_disable':
            await _confirmToggleDisable(uid, name, isDisabled);
            break;
          case 'copy_id':
            await Clipboard.setData(ClipboardData(text: displayId));
            _snack('ID copied to clipboard');
            break;
          case 'delete':
            await _confirmDeleteUser(uid, name);
            break;
        }
      },
    );
  }

  Widget _menuItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _Glass.panelDecoration(radius: 100),
            child: const Icon(
              Icons.people_outline_rounded,
              color: _Glass.textMuted,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(color: _Glass.textSecondary, fontSize: 14),
          ),
          if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _roleFilter = 'All';
                });
              },
              icon: const Icon(
                Icons.refresh_rounded,
                size: 15,
                color: _Glass.gold,
              ),
              label: const Text(
                'Clear filters',
                style: TextStyle(color: _Glass.gold, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState(String error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Error: $error',
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Gold Button — primary CTA only ────────────────────────────────────────────

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GoldButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style:
          ElevatedButton.styleFrom(
            backgroundColor: _Glass.gold,
            foregroundColor: _Glass.goldBtnText,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(const Color(0x22000000)),
          ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

// ── Role Dropdown ─────────────────────────────────────────────────────────────

class _RoleDropdown extends StatelessWidget {
  final String value;
  final List<String> roles;
  final ValueChanged<String> onChanged;
  const _RoleDropdown({
    required this.value,
    required this.roles,
    required this.onChanged,
  });

  Color _dotColor(String role) {
    switch (role) {
      case 'Admin':
        return _Glass.adminFg;
      case 'Employee':
        return _Glass.empFg;
      case 'Customer':
        return _Glass.cusFg;
      default:
        return _Glass.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _Glass.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _Glass.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xEEFFFFFF),
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: _Glass.textMuted,
            size: 18,
          ),
          isDense: true,
          items: roles.map((role) {
            return DropdownMenuItem<String>(
              value: role,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (role != 'All') ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _dotColor(role),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Icon(
                      Icons.people_outline_rounded,
                      color: _Glass.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    role == 'All' ? 'All Roles' : role,
                    style: TextStyle(
                      color: role == 'All'
                          ? _Glass.textSecondary
                          : _dotColor(role),
                      fontWeight: role == value
                          ? FontWeight.w700
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Create button with expandable sub-options ─────────────────────────────────

class _CreateButton extends StatefulWidget {
  final bool isCreating;
  final VoidCallback onCreateEmployee;
  final VoidCallback onCreateAdmin;
  const _CreateButton({
    required this.isCreating,
    required this.onCreateEmployee,
    required this.onCreateAdmin,
  });

  @override
  State<_CreateButton> createState() => _CreateButtonState();
}

class _CreateButtonState extends State<_CreateButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _removeOverlay();
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() => _overlay != null ? _removeOverlay() : _showOverlay();

  void _showOverlay() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            right: MediaQuery.of(context).size.width - pos.dx - size.width,
            top: pos.dy + size.height + 8,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 218,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xEEFFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x60FFFFFF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x20000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuOption(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Create Admin',
                        subtitle: 'Full system access',
                        color: _Glass.adminFg,
                        bgColor: _Glass.adminBg,
                        onTap: () {
                          _removeOverlay();
                          widget.onCreateAdmin();
                        },
                      ),
                      const SizedBox(height: 4),
                      _menuOption(
                        icon: Icons.badge_rounded,
                        label: 'Create Employee',
                        subtitle: 'Staff-level access',
                        color: _Glass.empFg,
                        bgColor: _Glass.empBg,
                        onTap: () {
                          _removeOverlay();
                          widget.onCreateEmployee();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlay!);
    _ctrl.forward(from: 0);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _overlay != null;
    return ElevatedButton.icon(
      key: _key,
      onPressed: widget.isCreating ? null : _toggle,
      style:
          ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 235, 188, 86),
            foregroundColor: _Glass.goldBtnText,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(const Color(0x22000000)),
          ),
      icon: AnimatedRotation(
        turns: isOpen ? 0.125 : 0,
        duration: const Duration(milliseconds: 180),
        child: const Icon(Icons.add_rounded, size: 18),
      ),
      label: const Text(
        'Create User',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _menuOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _Glass.textMuted,
                      fontSize: 10,
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
}
