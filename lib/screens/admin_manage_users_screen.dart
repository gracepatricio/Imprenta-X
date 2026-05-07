import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final AuthService _authService = AuthService();
  bool _isCreating = false;

  // Search & filter state
  String _searchQuery = '';
  String _roleFilter = 'All'; // 'All', 'Admin', 'Employee', 'Customer'

  final TextEditingController _searchController = TextEditingController();

  static const _roles = ['All', 'Admin', 'Employee', 'Customer'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _filtered(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
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

    if (mounted) {
      _showCredentialsDialog(
        role: 'Employee',
        idLabel: 'Employee ID',
        idValue: employeeId,
        password: result.password!,
      );
    }
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

    if (mounted) {
      _showCredentialsDialog(
        role: 'Admin',
        idLabel: 'UID',
        idValue: result.uid ?? '',
        password: result.password!,
      );
    }
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Colors.greenAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$role Account Created',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hand these credentials to the new user.\n'
                  'They will be required to change their password on first login.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            _credentialRow(idLabel, idValue),
            const SizedBox(height: 10),
            _credentialRow('Temp Password', password),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The password is also stored and can be retrieved from the user\'s record if needed.',
                      style: TextStyle(color: Colors.amber, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Copy $label',
            child: IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                _snack('$label copied');
              },
              icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: Colors.amber, size: 18),
            SizedBox(width: 8),
            Text(
              'Temporary Password',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _credentialRow('ID', displayId),
            const SizedBox(height: 10),
            _credentialRow('Temp Password', tempPw),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Delete User',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: '"$name"',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '?\n\nThis will soft-delete the account. The user will no longer be able to sign in.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final err = await _authService.deleteUser(uid);
      if (mounted) {
        _snack(
          err == 'success' ? 'User deleted.' : (err ?? 'Failed to delete user.'),
          isError: err != 'success',
        );
      }
    }
  }

  Future<void> _confirmToggleDisable(
      String uid,
      String name,
      bool currentlyDisabled,
      ) async {
    final action = currentlyDisabled ? 'enable' : 'disable';
    final actionColor = currentlyDisabled ? Colors.greenAccent : Colors.orangeAccent;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Text(
          '${action[0].toUpperCase()}${action.substring(1)} User',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            children: [
              TextSpan(text: 'Are you sure you want to $action '),
              TextSpan(
                text: '"$name"',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text('${action[0].toUpperCase()}${action.substring(1)}'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final err = await _authService.toggleDisableUser(uid, !currentlyDisabled);
      if (mounted) {
        _snack(
          err == 'success'
              ? 'User ${currentlyDisabled ? 'enabled' : 'disabled'}.'
              : (err ?? 'Action failed.'),
          isError: err != 'success',
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getDisplayId(Map<String, dynamic> data) {
    if (data['customer_id'] != null && (data['customer_id'] as String).isNotEmpty) {
      return data['customer_id'] as String;
    }
    if (data['employee_id'] != null && (data['employee_id'] as String).isNotEmpty) {
      return data['employee_id'] as String;
    }
    return data['uid'] as String? ?? '—';
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purpleAccent;
      case 'employee':
        return AppTheme.gold;
      default:
        return Colors.blueAccent;
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
            ? Colors.redAccent.withValues(alpha: 0.9)
            : Colors.green.withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        // ── Header ─────────────────────────────────────────────────────────
        _buildHeader(),

        const SizedBox(height: 16),

        // ── Search + filter row ─────────────────────────────────────────────
        _buildSearchBar(),

        const SizedBox(height: 10),

        // ── Role filter chips ───────────────────────────────────────────────
        _buildRoleChips(),

        const SizedBox(height: 14),

        // ── User list ───────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('User').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                );
              }
              if (snapshot.hasError) {
                return _errorState('${snapshot.error}');
              }

              final allDocs = snapshot.data?.docs ?? [];
              final filtered = _filtered(allDocs);

              if (allDocs.isEmpty) return _emptyState('No users found.');
              if (filtered.isEmpty) return _emptyState('No users match your search.');

              return _buildUserList(filtered, allDocs.length);
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.people_alt_rounded, color: AppTheme.gold, size: 20),
        ),
        const SizedBox(width: 12),
        const Text(
          'Manage Users',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        if (_isCreating)
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
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

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search by name, email or ID…',
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
          onPressed: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  Widget _buildRoleChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _roles.map((role) {
          final isSelected = _roleFilter == role;
          final chipColor = role == 'All'
              ? Colors.white
              : role == 'Admin'
              ? Colors.purpleAccent
              : role == 'Employee'
              ? AppTheme.gold
              : Colors.blueAccent;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _roleFilter = role),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? chipColor.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.12),
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),
                child: Text(
                  role == 'All' ? 'All Roles' : role,
                  style: TextStyle(
                    color: isSelected ? chipColor : Colors.white54,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUserList(List<QueryDocumentSnapshot> docs, int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                '${docs.length} user${docs.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_searchQuery.isNotEmpty || _roleFilter != 'All') ...[
                Text(
                  ' of $totalCount',
                  style: const TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
              data['uid'] = doc.id;
              return _buildUserCard(doc.id, data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    final displayId = _getDisplayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String?)?.isNotEmpty == true
        ? data['email'] as String
        : '(not set)';
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;
    final roleColor = _roleColor(role);
    final initials = _getInitials(name);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDisabled
              ? Colors.orangeAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: roleColor.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isDisabled)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1a1a2e), width: 1.5),
                    ),
                  ),
                )
              else
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1a1a2e), width: 1.5),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // ── Info ─────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (mustChange) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Awaiting first login',
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, color: Colors.amber, size: 10),
                              SizedBox(width: 3),
                              Text(
                                'Pending',
                                style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                Row(
                  children: [
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_roleIcon(role), color: roleColor, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '—',
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ID chip
                    Flexible(
                      child: Text(
                        displayId,
                        style: TextStyle(
                          color: AppTheme.gold.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 2),

                Text(
                  email,
                  style: TextStyle(
                    color: email == '(not set)' ? Colors.white30 : Colors.white54,
                    fontSize: 11,
                    fontStyle: email == '(not set)' ? FontStyle.italic : FontStyle.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Quick action: toggle disable ─────────────────────────────────
          Tooltip(
            message: isDisabled ? 'Enable User' : 'Disable User',
            child: InkWell(
              onTap: () => _confirmToggleDisable(uid, name, isDisabled),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isDisabled ? Colors.greenAccent : Colors.orangeAccent)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isDisabled ? Colors.greenAccent : Colors.orangeAccent)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  isDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
                  color: isDisabled ? Colors.greenAccent : Colors.orangeAccent,
                  size: 15,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // ── Overflow menu ───────────────────────────────────────────────
          _buildActionMenu(uid, data, displayId, name, isDisabled),
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
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white38, size: 18),
      color: const Color(0xFF1e1e35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      offset: const Offset(0, 4),
      elevation: 8,
      itemBuilder: (_) => [
        if (mustChange && (role == 'employee' || role == 'admin'))
          PopupMenuItem(
            value: 'show_password',
            child: _menuItem(Icons.key_rounded, 'View Temp Password', Colors.amber),
          ),
        PopupMenuItem(
          value: 'toggle_disable',
          child: _menuItem(
            isDisabled ? Icons.lock_open_rounded : Icons.block_rounded,
            isDisabled ? 'Enable User' : 'Disable User',
            isDisabled ? Colors.greenAccent : Colors.orangeAccent,
          ),
        ),
        PopupMenuItem(
          value: 'copy_id',
          child: _menuItem(Icons.copy_rounded, 'Copy ID', Colors.white54),
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

  Widget _menuItem(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
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
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.people_outline_rounded, color: Colors.white24, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
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
              icon: const Icon(Icons.refresh_rounded, size: 15, color: AppTheme.gold),
              label: const Text('Clear filters', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
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
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
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

// ── Inline create button with expandable sub-options ─────────────────────────

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

  void _toggle() {
    if (_overlay != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

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
                    color: const Color(0xFF1e1e35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
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
                        color: Colors.purpleAccent,
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
                        color: AppTheme.gold,
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
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.gold,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
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
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
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