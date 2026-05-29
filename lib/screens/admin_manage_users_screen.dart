import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

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

  // ── Create helpers ─────────────────────────────────────────────────────────

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
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        content: Container(
          width: 400,
          decoration: _darkDialog(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkDialogHeader(
                icon: Icons.check_circle_outline,
                iconColor: Colors.greenAccent,
                title: '$role Account Created',
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hand these credentials to the new user.\nThey will be required to change their password on first login.',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DarkCredentialRow(
                      label: idLabel,
                      value: idValue,
                      onCopy: () => _snack('$idLabel copied'),
                    ),
                    const SizedBox(height: 10),
                    _DarkCredentialRow(
                      label: 'Temp Password',
                      value: password,
                      onCopy: () => _snack('Password copied'),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.gold, size: 13),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'The password is also stored and can be retrieved from the user\'s record if needed.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

  Future<void> _showTempPassword(String uid, String role, String displayId) async {
    final doc = await FirebaseFirestore.instance.collection('User').doc(uid).get();
    final tempPw = doc.data()?['temp_password'] as String?;
    if (!mounted) return;
    if (tempPw == null || tempPw.isEmpty) {
      _snack('No temporary password stored for this user.');
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        content: Container(
          width: 380,
          decoration: _darkDialog(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkDialogHeader(
                icon: Icons.key_rounded,
                iconColor: AppTheme.gold,
                title: 'Temporary Password',
              ),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                child: Column(
                  children: [
                    _DarkCredentialRow(
                      label: 'ID',
                      value: displayId,
                      onCopy: () => _snack('ID copied'),
                    ),
                    const SizedBox(height: 10),
                    _DarkCredentialRow(
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
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        child: const Text('Close', style: TextStyle(fontSize: 13)),
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
    final confirmed = await _showDarkConfirm(
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      title: 'Delete User',
      body: 'Are you sure you want to permanently delete "$name"?\n\nThis will remove their account, profile, and all associated data. This cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: Colors.red.shade700,
    );
    if (confirmed == true) {
      final err = await _authService.deleteUser(uid);
      if (mounted)
        _snack(
          err == 'success' ? 'User deleted.' : (err ?? 'Failed to delete user.'),
          isError: err != 'success',
        );
    }
  }

  Future<void> _confirmToggleDisable(String uid, String name, bool currentlyDisabled) async {
    final action = currentlyDisabled ? 'enable' : 'disable';
    final actionColor = currentlyDisabled ? Colors.green.shade600 : Colors.orange.shade700;
    final confirmed = await _showDarkConfirm(
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

  Future<bool?> _showDarkConfirm({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        content: Container(
          width: 380,
          decoration: _darkDialog(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkDialogHeader(icon: icon, iconColor: iconColor, title: title),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.white60,
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
                            foregroundColor: Colors.white70,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          ),
                          child: Text(confirmLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

  BoxDecoration _darkDialog() => BoxDecoration(
    color: const Color(0xFF1a1a2e),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
  );

  String _displayId(Map<String, dynamic> data) {
    if ((data['admin_id'] as String? ?? '').isNotEmpty) return data['admin_id'] as String;
    if ((data['customer_id'] as String? ?? '').isNotEmpty) return data['customer_id'] as String;
    if ((data['employee_id'] as String? ?? '').isNotEmpty) return data['employee_id'] as String;
    return '—';
  }

  Color _roleFg(String role) {
    switch (role) {
      case 'admin': return const Color(0xFFCDB4FF);
      case 'employee': return const Color(0xFF6EE7B7);
      default: return const Color(0xFF93C5FD);
    }
  }

  Color _roleBg(String role) {
    switch (role) {
      case 'admin': return const Color(0x207C3AED);
      case 'employee': return const Color(0x200D9488);
      default: return const Color(0x201D4ED8);
    }
  }

  Color _roleBorder(String role) {
    switch (role) {
      case 'admin': return const Color(0x507C3AED);
      case 'employee': return const Color(0x500D9488);
      default: return const Color(0x501D4ED8);
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin': return Icons.admin_panel_settings_rounded;
      case 'employee': return Icons.badge_rounded;
      default: return Icons.person_rounded;
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
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildToolbar(),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('User').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
                );
              if (snapshot.hasError)
                return _emptyState('Error: ${snapshot.error}');
              final allDocs = snapshot.data?.docs ?? [];
              final filtered = _filtered(allDocs);
              if (allDocs.isEmpty) return _emptyState('No users found.');
              if (filtered.isEmpty) return _emptyState('No users match your search.');
              return _buildTable(filtered, allDocs.length);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() => Row(
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Users',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'User accounts & access control',
              style: TextStyle(color: Colors.white38, fontSize: 11),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
          ),
        ),
      _CreateButton(
        isCreating: _isCreating,
        onCreateEmployee: _createEmployee,
        onCreateAdmin: _createAdmin,
      ),
    ],
  );

  Widget _buildToolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final searchField = SizedBox(
        height: 42,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by name, email or ID…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.5),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 17),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 15),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.07),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.7), width: 1.2),
            ),
          ),
        ),
      );

      final dropdown = _RoleDropdown(
        value: _roleFilter,
        roles: _roles,
        onChanged: (v) => setState(() => _roleFilter = v),
      );

      if (constraints.maxWidth < 400) {
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
        final isMobile = constraints.maxWidth < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    '${docs.length} user${docs.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11.5),
                  ),
                  if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
                    Text(' of $totalCount total',
                        style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() { _searchQuery = ''; _roleFilter = 'All'; });
                      },
                      child: Text(
                        'Clear filters',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 11.5,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.gold,
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
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['uid'] = doc.id;
        return _buildUserCard(doc.id, data);
      },
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    final displayId = _displayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String? ?? '').isEmpty ? '(not set)' : data['email'] as String;
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;
    final roleColor = _roleFg(role);
    final roleBg = _roleBg(role);
    final roleBorder = _roleBorder(role);

    return Container(
      decoration: AppTheme.glassCard(opacity: 0.12, radius: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: roleBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(color: roleColor, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          // Info
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
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mustChange) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                        ),
                        child: Text('Pending',
                            style: TextStyle(color: AppTheme.gold, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isDisabled ? Colors.orange : Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleBg,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: roleBorder),
                      ),
                      child: Text(
                        role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '—',
                        style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayId,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    color: email == '(not set)' ? Colors.white24 : Colors.white60,
                    fontSize: 11.5,
                    fontStyle: email == '(not set)' ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Actions
          _buildActionMenu(uid, data, displayId, name, isDisabled, mustChange, role),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot> docs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
        child: Column(
          children: [
            _buildTableHeader(),
            Container(height: 0.8, color: Colors.white.withValues(alpha: 0.1)),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    Container(height: 0.8, color: Colors.white.withValues(alpha: 0.07)),
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                  data['uid'] = doc.id;
                  return _buildTableRow(doc.id, data, i.isEven);
                },
              ),
            ),
          ],
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
                  color: active ? AppTheme.gold : Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                active
                    ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                    : Icons.unfold_more_rounded,
                size: 11,
                color: active ? AppTheme.gold : Colors.white24,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const SizedBox(width: 40),
          const SizedBox(width: 12),
          col('Name', 0, flex: 3),
          col('Role', 1, flex: 2),
          col('ID', 2, flex: 2),
          col('Email', 3, flex: 3),
          col('Status', 4, flex: 2),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTableRow(String uid, Map<String, dynamic> data, bool isEven) {
    final displayId = _displayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String? ?? '').isEmpty ? '(not set)' : data['email'] as String;
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;
    final roleColor = _roleFg(role);
    final roleBg = _roleBg(role);
    final roleBorder = _roleBorder(role);

    return Container(
      color: isEven ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: roleBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: roleBorder),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(color: roleColor, fontSize: 12, fontWeight: FontWeight.w700),
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
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mustChange) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded, color: AppTheme.gold, size: 9),
                        const SizedBox(width: 3),
                        Text('Pending',
                            style: TextStyle(color: AppTheme.gold, fontSize: 9, fontWeight: FontWeight.w700)),
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
                  border: Border.all(color: roleBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_roleIcon(role), color: roleColor, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '—',
                      style: TextStyle(color: roleColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ID
          Expanded(
            flex: 2,
            child: Text(
              displayId,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
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
                color: email == '(not set)' ? Colors.white24 : Colors.white60,
                fontSize: 12,
                fontStyle: email == '(not set)' ? FontStyle.italic : FontStyle.normal,
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
                    color: isDisabled ? Colors.orange : Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isDisabled ? 'Disabled' : 'Active',
                  style: TextStyle(
                    color: isDisabled ? Colors.orange : Colors.greenAccent,
                    fontSize: 11.5,
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
              child: _buildActionMenu(uid, data, displayId, name, isDisabled, mustChange, role),
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
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 18),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      offset: const Offset(0, 4),
      itemBuilder: (_) => [
        if (mustChange && (role == 'employee' || role == 'admin'))
          PopupMenuItem(
            value: 'show_password',
            child: _menuItem(Icons.key_rounded, 'View Temp Password', AppTheme.gold),
          ),
        PopupMenuItem(
          value: 'toggle_disable',
          child: _menuItem(
            isDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
            isDisabled ? 'Enable User' : 'Disable User',
            isDisabled ? Colors.greenAccent : Colors.orange,
          ),
        ),
        PopupMenuItem(
          value: 'copy_id',
          child: _menuItem(Icons.copy_rounded, 'Copy ID', Colors.white60),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(Icons.delete_outline_rounded, 'Delete User', Colors.redAccent),
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
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
    ],
  );

  Widget _emptyState(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: AppTheme.glassCard(opacity: 0.12, radius: 20),
          child: const Icon(Icons.people_outline_rounded, size: 28, color: Colors.white24),
        ),
        const SizedBox(height: 16),
        Text(message, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              _searchController.clear();
              setState(() { _searchQuery = ''; _roleFilter = 'All'; });
            },
            child: Text(
              'Clear filters',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.gold,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

// =============================================================================
// Shared dark widgets
// =============================================================================

class _DarkDialogHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  const _DarkDialogHeader({required this.icon, required this.iconColor, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: iconColor.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

class _DarkCredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;
  const _DarkCredentialRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
                  color: Colors.white38,
                  fontSize: 9,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: Icon(Icons.copy_rounded, color: AppTheme.gold, size: 13),
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
  const _RoleDropdown({required this.value, required this.roles, required this.onChanged});

  Color _dot(String role) {
    switch (role) {
      case 'Admin': return const Color(0xFFCDB4FF);
      case 'Employee': return const Color(0xFF6EE7B7);
      case 'Customer': return const Color(0xFF93C5FD);
      default: return Colors.white38;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(12),
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 17),
        isDense: true,
        items: roles.map((role) => DropdownMenuItem<String>(
          value: role,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (role != 'All') ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: _dot(role), shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ] else ...[
                const Icon(Icons.people_outline_rounded, color: Colors.white38, size: 13),
                const SizedBox(width: 7),
              ],
              Text(
                role == 'All' ? 'All Roles' : role,
                style: TextStyle(
                  color: role == 'All' ? Colors.white60 : _dot(role),
                  fontWeight: role == value ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
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
                  width: 210,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a2e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _dropdownOption(
                        icon: Icons.admin_panel_settings_rounded,
                        label: 'Create Admin',
                        subtitle: 'Full system access',
                        color: const Color(0xFFCDB4FF),
                        bg: const Color(0x207C3AED),
                        onTap: () { _removeOverlay(); widget.onCreateAdmin(); },
                      ),
                      const SizedBox(height: 4),
                      _dropdownOption(
                        icon: Icons.badge_rounded,
                        label: 'Create Employee',
                        subtitle: 'Staff-level access',
                        color: const Color(0xFF6EE7B7),
                        bg: const Color(0x200D9488),
                        onTap: () { _removeOverlay(); widget.onCreateEmployee(); },
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

  Widget _dropdownOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRotation(
              turns: isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(Icons.add_rounded, size: 14, color: AppTheme.gold),
            ),
            const SizedBox(width: 6),
            const Text(
              'Create User',
              style: TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}