import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

// =============================================================================
// Design Tokens — kept in sync
// =============================================================================
class _G {
  static const Color navyBlue = Color(0xFF0F1A2E);
  static const Color surface = Color(0xF8FFFFFF);
  static const Color surfaceMid = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);
  static const Color borderTop = Color(0xE0FFFFFF);
  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted = Color(0x880F172A);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
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

BoxDecoration _glassDialog() => BoxDecoration(
  color: _G.surface,
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: _G.borderMid, width: 0.9),
  boxShadow: const [
    BoxShadow(
      color: Color(0x22000000),
      blurRadius: 32,
      spreadRadius: -4,
      offset: Offset(0, 8),
    ),
  ],
);

// =============================================================================
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
  final _searchController = TextEditingController();
  static const _roles = ['All', 'Admin', 'Employee', 'Customer'];

  int _sortColumnIndex = 0;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filter & Sort ──────────────────────────────────────────────────────────
  List<QueryDocumentSnapshot> _filtered(List<QueryDocumentSnapshot> docs) {
    var result = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['is_deleted'] == true) return false;
      final name = (data['full_name'] as String? ?? '').toLowerCase();
      final email = (data['email'] as String? ?? '').toLowerCase();
      final role = (data['user_role'] as String? ?? '').toLowerCase();
      final cusId = (data['customer_id'] as String? ?? '').toLowerCase();
      final empId = (data['employee_id'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          q.isEmpty ||
          name.contains(q) ||
          email.contains(q) ||
          cusId.contains(q) ||
          empId.contains(q);
      final matchesRole =
          _roleFilter == 'All' || role == _roleFilter.toLowerCase();
      return matchesSearch && matchesRole;
    }).toList();

    result.sort((a, b) {
      final aD = a.data() as Map<String, dynamic>;
      final bD = b.data() as Map<String, dynamic>;
      String aVal = '', bVal = '';
      switch (_sortColumnIndex) {
        case 0:
          aVal = (aD['full_name'] as String? ?? '').toLowerCase();
          bVal = (bD['full_name'] as String? ?? '').toLowerCase();
          break;
        case 1:
          aVal = (aD['user_role'] as String? ?? '').toLowerCase();
          bVal = (bD['user_role'] as String? ?? '').toLowerCase();
          break;
        case 2:
          aVal = _displayId(aD).toLowerCase();
          bVal = _displayId(bD).toLowerCase();
          break;
        case 3:
          aVal = (aD['email'] as String? ?? '').toLowerCase();
          bVal = (bD['email'] as String? ?? '').toLowerCase();
          break;
        case 4:
          aVal = (aD['is_disabled'] == true) ? 'disabled' : 'active';
          bVal = (bD['is_disabled'] == true) ? 'disabled' : 'active';
          break;
      }
      return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
    });
    return result;
  }

  // ── Create ─────────────────────────────────────────────────────────────────
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
        idLabel: 'Admin ID',
        idValue: result.adminId ?? '',
        password: result.password!,
      );
  }

  Future<void> _createCustomer() async {
    // Show form dialog to collect name, email, password
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => const _CreateCustomerDialog(),
    );
    if (result == null) return;

    setState(() => _isCreating = true);
    final res = await _authService.createCustomerAccountManually(
      email: result['email']!,
      fullName: result['fullName']!,
      password: result['password']!,
    );
    if (!mounted) return;
    setState(() => _isCreating = false);

    if (res.error != null) {
      _snack(res.error!, isError: true);
      return;
    }

    if (mounted) {
      _showCredentialsDialog(
        role: 'Customer',
        idLabel: 'Customer ID',
        idValue: res.customerId ?? '',
        password: result['password']!,
      );
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showCredentialsDialog({
    required String role,
    required String idLabel,
    required String idValue,
    required String password,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 420,
              decoration: _glassDialog(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassDialogHeader(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: _G.accentEmerald,
                    title: '$role Account Created',
                  ),
                  Divider(height: 1, color: _G.borderMid),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _G.navyBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _G.navyBlue.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: _G.navyBlue,
                                size: 14,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hand these credentials to the new user. They must change their password on first login.',
                                  style: TextStyle(
                                    color: _G.textSecondary,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassCredentialRow(
                          label: idLabel,
                          value: idValue,
                          onCopy: () => _snack('$idLabel copied'),
                        ),
                        const SizedBox(height: 10),
                        _GlassCredentialRow(
                          label: 'Temp Password',
                          value: password,
                          onCopy: () => _snack('Password copied'),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _G.navyBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
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
        ),
      ),
    );
  }

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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 380,
              decoration: _glassDialog(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassDialogHeader(
                    icon: Icons.key_rounded,
                    iconColor: _G.accentViolet,
                    title: 'Temporary Password',
                  ),
                  Divider(height: 1, color: _G.borderMid),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                    child: Column(
                      children: [
                        _GlassCredentialRow(
                          label: 'ID',
                          value: displayId,
                          onCopy: () => _snack('ID copied'),
                        ),
                        const SizedBox(height: 10),
                        _GlassCredentialRow(
                          label: 'Temp Password',
                          value: tempPw,
                          onCopy: () => _snack('Password copied'),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _G.textSecondary,
                              side: const BorderSide(
                                color: _G.borderMid,
                                width: 0.9,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 11,
                              ),
                            ),
                            child: const Text(
                              'Close',
                              style: TextStyle(fontSize: 13),
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
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(String uid, String name) async {
    final confirmed = await _showGlassConfirm(
      icon: Icons.warning_amber_rounded,
      iconColor: _G.accentRose,
      title: 'Delete User',
      body:
          'Are you sure you want to permanently delete "$name"?\n\nThis action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: _G.accentRose,
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
    final actionColor = currentlyDisabled ? _G.accentEmerald : _G.accentAmber;
    final confirmed = await _showGlassConfirm(
      icon: currentlyDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
      iconColor: actionColor,
      title: '${action[0].toUpperCase()}${action.substring(1)} User',
      body: 'Are you sure you want to $action "$name"?',
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
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 380,
              decoration: _glassDialog(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassDialogHeader(
                    icon: icon,
                    iconColor: iconColor,
                    title: title,
                  ),
                  Divider(height: 1, color: _G.borderMid),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          body,
                          style: const TextStyle(
                            color: _G.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _G.textSecondary,
                                side: const BorderSide(
                                  color: _G.borderMid,
                                  width: 0.9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: confirmColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                confirmLabel,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
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
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _displayId(Map<String, dynamic> data) {
    if ((data['admin_id'] as String? ?? '').isNotEmpty)
      return data['admin_id'] as String;
    if ((data['customer_id'] as String? ?? '').isNotEmpty)
      return data['customer_id'] as String;
    if ((data['employee_id'] as String? ?? '').isNotEmpty)
      return data['employee_id'] as String;
    return '—';
  }

  Color _roleFg(String role) {
    switch (role) {
      case 'admin':
        return _G.accentViolet;
      case 'employee':
        return _G.accentEmerald;
      default:
        return _G.accentBlue;
    }
  }

  Color _roleBg(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFEDE9FE);
      case 'employee':
        return const Color(0xFFD1FAE5);
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  Color _roleBorder(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFC4B5FD);
      case 'employee':
        return const Color(0xFF6EE7B7);
      default:
        return const Color(0xFF93C5FD);
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

  String _initials(String name) {
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
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? _G.accentRose : _G.accentEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildToolbar(),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('User')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _G.navyBlue,
                          strokeWidth: 2,
                        ),
                      );
                    if (snapshot.hasError)
                      return _emptyState('Error: ${snapshot.error}');
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
          ),
        );
      },
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Manage Users',
              style: TextStyle(
                color: _G.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'User accounts & access control',
              style: TextStyle(color: _G.textMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
      if (_isCreating)
        const Padding(
          padding: EdgeInsets.only(right: 10),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _G.navyBlue,
            ),
          ),
        ),
      _CreateButton(
        isCreating: _isCreating,
        onCreateEmployee: _createEmployee,
        onCreateAdmin: _createAdmin,
        onCreateCustomer: _createCustomer, // add this
      ),
    ],
  );

  Widget _buildToolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final searchField = SizedBox(
        height: 44,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: _G.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by name, email or ID…',
            hintStyle: const TextStyle(color: _G.textMuted, fontSize: 12.5),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _G.textMuted,
              size: 17,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _G.textMuted,
                      size: 15,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            filled: true,
            fillColor: _G.surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _G.borderMid, width: 0.9),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _G.navyBlue, width: 1.5),
            ),
          ),
        ),
      );

      final dropdown = _RoleDropdown(
        value: _roleFilter,
        roles: _roles,
        onChanged: (v) => setState(() => _roleFilter = v),
      );

      if (constraints.maxWidth < 360) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [searchField, const SizedBox(height: 8), dropdown],
        );
      }
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 10),
          dropdown,
        ],
      );
    },
  );

  Widget _buildTable(List<QueryDocumentSnapshot> docs, int totalCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    '${docs.length} user${docs.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: _G.textMuted, fontSize: 11.5),
                  ),
                  if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
                    Text(
                      ' of $totalCount total',
                      style: const TextStyle(
                        color: _G.textMuted,
                        fontSize: 11.5,
                      ),
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
                          color: _G.navyBlue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _G.navyBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: isMobile ? _buildCardList(docs) : _buildDesktopTable(docs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCardList(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final doc = docs[i];
        final data = Map<String, dynamic>.from(
          doc.data() as Map<String, dynamic>,
        );
        data['uid'] = doc.id;
        return _buildUserCard(doc.id, data);
      },
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    final displayId = _displayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String? ?? '').isEmpty
        ? '(not set)'
        : data['email'] as String;
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;
    final roleColor = _roleFg(role);
    final roleBg = _roleBg(role);
    final roleBorder = _roleBorder(role);

    return Container(
      decoration: _G.card(radius: 16),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: roleBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                color: roleColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: _G.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mustChange) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _G.accentAmber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _G.accentAmber.withValues(alpha: 0.40),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'Pending',
                          style: TextStyle(
                            color: _G.accentAmber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDisabled ? _G.accentAmber : _G.accentEmerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleBg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: roleBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon(role), color: roleColor, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            role.isNotEmpty
                                ? role[0].toUpperCase() + role.substring(1)
                                : '—',
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayId,
                      style: const TextStyle(
                        color: _G.textMuted,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    color: email == '(not set)'
                        ? _G.textMuted
                        : _G.textSecondary,
                    fontSize: 11.5,
                    fontStyle: email == '(not set)'
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildActionMenu(
            uid,
            data,
            displayId,
            name,
            isDisabled,
            mustChange,
            role,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot> docs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: _G.card(radius: 18),
          child: Column(
            children: [
              _buildTableHeader(),
              Divider(height: 0.8, color: _G.borderMid),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 0.8, color: _G.borderDim),
                  itemBuilder: (_, i) {
                    final doc = docs[i];
                    final data = Map<String, dynamic>.from(
                      doc.data() as Map<String, dynamic>,
                    );
                    data['uid'] = doc.id;
                    return _buildTableRow(doc.id, data, i.isEven);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    Widget col(String label, int idx, {int flex = 1}) {
      final active = _sortColumnIndex == idx;
      return Expanded(
        flex: flex,
        child: GestureDetector(
          onTap: () => setState(() {
            if (_sortColumnIndex == idx)
              _sortAscending = !_sortAscending;
            else {
              _sortColumnIndex = idx;
              _sortAscending = true;
            }
          }),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: active ? _G.navyBlue : _G.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                active
                    ? (_sortAscending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 11,
                color: active ? _G.navyBlue : _G.textMuted,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: _G.surfaceThin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 42),
          const SizedBox(width: 12),
          col('Name', 0, flex: 3),
          col('Role', 1, flex: 2),
          col('ID', 2, flex: 2),
          col('Email', 3, flex: 3),
          col('Status', 4, flex: 2),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTableRow(String uid, Map<String, dynamic> data, bool isEven) {
    final displayId = _displayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String? ?? '').isEmpty
        ? '(not set)'
        : data['email'] as String;
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;
    final roleColor = _roleFg(role);
    final roleBg = _roleBg(role);
    final roleBorder = _roleBorder(role);

    return Container(
      color: isEven ? _G.surfaceThin : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: roleBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                color: roleColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: _G.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
                      color: _G.accentAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _G.accentAmber.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.schedule_rounded,
                          color: _G.accentAmber,
                          size: 9,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Pending',
                          style: TextStyle(
                            color: _G.accentAmber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: roleBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: roleBorder),
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              displayId,
              style: const TextStyle(
                color: _G.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              email,
              style: TextStyle(
                color: email == '(not set)' ? _G.textMuted : _G.textSecondary,
                fontSize: 12,
                fontStyle: email == '(not set)'
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDisabled ? _G.accentAmber : _G.accentEmerald,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isDisabled ? _G.accentAmber : _G.accentEmerald)
                            .withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  isDisabled ? 'Disabled' : 'Active',
                  style: TextStyle(
                    color: isDisabled ? _G.accentAmber : _G.accentEmerald,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildActionMenu(
                uid,
                data,
                displayId,
                name,
                isDisabled,
                mustChange,
                role,
              ),
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
    bool mustChange,
    String role,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: _G.textMuted, size: 18),
      color: _G.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _G.borderMid, width: 0.9),
      ),
      elevation: 12,
      shadowColor: const Color(0x22000000),
      offset: const Offset(0, 4),
      itemBuilder: (_) => [
        if (mustChange && (role == 'employee' || role == 'admin'))
          PopupMenuItem(
            value: 'show_password',
            child: _menuItem(
              Icons.key_rounded,
              'View Temp Password',
              _G.accentViolet,
            ),
          ),
        PopupMenuItem(
          value: 'toggle_disable',
          child: _menuItem(
            isDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
            isDisabled ? 'Enable User' : 'Disable User',
            isDisabled ? _G.accentEmerald : _G.accentAmber,
          ),
        ),
        PopupMenuItem(
          value: 'copy_id',
          child: _menuItem(Icons.copy_rounded, 'Copy ID', _G.textSecondary),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(
            Icons.delete_outline_rounded,
            'Delete User',
            _G.accentRose,
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

  Widget _menuItem(IconData icon, String label, Color color) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: color, size: 13),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _emptyState(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: _G.card(radius: 22),
          child: const Icon(
            Icons.people_outline_rounded,
            size: 30,
            color: _G.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: _G.textMuted, fontSize: 13),
        ),
        if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
          const SizedBox(height: 10),
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
                color: _G.navyBlue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _G.navyBlue,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// =============================================================================
// Shared Glass Widgets
// =============================================================================
class _GlassDialogHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  const _GlassDialogHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.30),
              width: 0.9,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: _G.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}

class _GlassCredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _GlassCredentialRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: _G.surfaceThin,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _G.borderMid, width: 0.9),
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
                  color: _G.textMuted,
                  fontSize: 9,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: _G.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            onCopy();
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _G.navyBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _G.navyBlue.withValues(alpha: 0.20),
                width: 0.8,
              ),
            ),
            child: const Icon(Icons.copy_rounded, color: _G.navyBlue, size: 13),
          ),
        ),
      ],
    ),
  );
}

class _RoleDropdown extends StatelessWidget {
  final String value;
  final List<String> roles;
  final ValueChanged<String> onChanged;
  const _RoleDropdown({
    required this.value,
    required this.roles,
    required this.onChanged,
  });

  Color _dot(String role) {
    switch (role) {
      case 'Admin':
        return _G.accentViolet;
      case 'Employee':
        return _G.accentEmerald;
      case 'Customer':
        return _G.accentBlue;
      default:
        return _G.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _G.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _G.borderMid, width: 0.9),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: _G.surface,
        borderRadius: BorderRadius.circular(14),
        style: const TextStyle(color: _G.textPrimary, fontSize: 12.5),
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: _G.textMuted,
          size: 17,
        ),
        isDense: true,
        items: roles
            .map(
              (role) => DropdownMenuItem<String>(
                value: role,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (role != 'All') ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _dot(role),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                    ] else ...[
                      const Icon(
                        Icons.people_outline_rounded,
                        color: _G.textMuted,
                        size: 13,
                      ),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      role == 'All' ? 'All Roles' : role,
                      style: TextStyle(
                        color: role == 'All' ? _G.textSecondary : _dot(role),
                        fontWeight: role == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

class _CreateButton extends StatefulWidget {
  final bool isCreating;
  final VoidCallback onCreateEmployee;
  final VoidCallback onCreateAdmin;
  final VoidCallback onCreateCustomer; // ADD THIS
  const _CreateButton({
    required this.isCreating,
    required this.onCreateEmployee,
    required this.onCreateAdmin,
    required this.onCreateCustomer, // ADD THIS
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
      duration: const Duration(milliseconds: 200),
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
            top: pos.dy + size.height + 10,
            child: FadeTransition(
              opacity: _fade,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _G.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _G.borderMid, width: 0.9),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _dropdownOption(
                            icon: Icons.admin_panel_settings_rounded,
                            label: 'Create Admin',
                            subtitle: 'Full system access',
                            color: _G.accentViolet,
                            bg: const Color(0xFFEDE9FE),
                            onTap: () {
                              _removeOverlay();
                              widget.onCreateAdmin();
                            },
                          ),
                          const SizedBox(height: 4),
                          _dropdownOption(
                            icon: Icons.badge_rounded,
                            label: 'Create Employee',
                            subtitle: 'Staff-level access',
                            color: _G.accentEmerald,
                            bg: const Color(0xFFD1FAE5),
                            onTap: () {
                              _removeOverlay();
                              widget.onCreateEmployee();
                            },
                          ),
                          // After the existing Create Employee option:
                          const SizedBox(height: 4),
                          _dropdownOption(
                            icon: Icons.person_add_rounded,
                            label: 'Create Customer',
                            subtitle: 'Manual customer account',
                            color: _G.accentBlue,
                            bg: const Color(0xFFDBEAFE),
                            onTap: () {
                              _removeOverlay();
                              widget
                                  .onCreateCustomer(); // we'll add this callback below
                            },
                          ),
                        ],
                      ),
                    ),
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

  Widget _dropdownOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: _G.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isOpen = _overlay != null;
    return GestureDetector(
      key: _key,
      onTap: widget.isCreating ? null : _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: _G.navyBlue,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: _G.navyBlue.withValues(alpha: isOpen ? 0.40 : 0.25),
              blurRadius: isOpen ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.add_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Create User',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCustomerDialog extends StatefulWidget {
  const _CreateCustomerDialog();

  @override
  State<_CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<_CreateCustomerDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 420,
            decoration: _glassDialog(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassDialogHeader(
                  icon: Icons.person_add_rounded,
                  iconColor: _G.accentBlue,
                  title: 'Create Customer Account',
                ),
                Divider(height: 1, color: _G.borderMid),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      _field('Full Name', _nameCtrl, Icons.person_outline),
                      const SizedBox(height: 12),
                      // Email
                      _field(
                        'Email',
                        _emailCtrl,
                        Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      // Password
                      _fieldPassword(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _G.textSecondary,
                              side: const BorderSide(
                                color: _G.borderMid,
                                width: 0.9,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final name = _nameCtrl.text.trim();
                              final email = _emailCtrl.text.trim();
                              final password = _passwordCtrl.text.trim();
                              if (name.isEmpty ||
                                  email.isEmpty ||
                                  password.isEmpty)
                                return;
                              Navigator.pop(context, {
                                'fullName': name,
                                'email': email,
                                'password': password,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _G.accentBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              'Create',
                              style: TextStyle(fontWeight: FontWeight.w700),
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
      ),
    );
  }

  Widget _field(
    String hint,
    TextEditingController ctrl,
    IconData icon, {
    TextInputType? keyboard,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    style: const TextStyle(color: _G.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _G.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, size: 16, color: _G.textMuted),
      filled: true,
      fillColor: _G.surfaceThin,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _G.borderMid, width: 0.9),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _G.navyBlue, width: 1.5),
      ),
    ),
  );

  Widget _fieldPassword() => TextField(
    controller: _passwordCtrl,
    obscureText: _obscure,
    style: const TextStyle(color: _G.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: 'Password',
      hintStyle: const TextStyle(color: _G.textMuted, fontSize: 13),
      prefixIcon: const Icon(Icons.lock_outline, size: 16, color: _G.textMuted),
      suffixIcon: IconButton(
        icon: Icon(
          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 16,
          color: _G.textMuted,
        ),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
      filled: true,
      fillColor: _G.surfaceThin,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _G.borderMid, width: 0.9),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _G.navyBlue, width: 1.5),
      ),
    ),
  );
}
