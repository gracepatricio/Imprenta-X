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

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _filtered(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Exclude soft-deleted users
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
      _snack(result.error!);
      return;
    }

    // Read the employee ID directly from the Firestore doc we just created,
    // using the UID returned by the service — no unreliable delay + re-query.
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
      _snack(result.error!);
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
              size: 22,
            ),
            const SizedBox(width: 8),
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
              style: TextStyle(color: Colors.white70, fontSize: 12),
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
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The password is also stored and can be retrieved from the user\'s record if needed.',
                      style: TextStyle(color: Colors.amber, fontSize: 11),
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
            ),
            child: const Text('Done'),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 2),
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
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$label copied')));
            },
            icon: const Icon(Icons.copy, color: Colors.white38, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          'Temporary Password',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          'Delete User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "$name"?\n\n'
          'This will soft-delete the account. The user will no longer be able to sign in.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final err = await _authService.deleteUser(uid);
      if (mounted) {
        _snack(
          err == 'success'
              ? 'User deleted.'
              : (err ?? 'Failed to delete user.'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: Text(
          '${action[0].toUpperCase()}${action.substring(1)} User',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to $action "$name"?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyDisabled
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getDisplayId(Map<String, dynamic> data) {
    if (data['customer_id'] != null &&
        (data['customer_id'] as String).isNotEmpty) {
      return data['customer_id'] as String;
    }
    if (data['employee_id'] != null &&
        (data['employee_id'] as String).isNotEmpty) {
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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row: title + create button ──────────────────────────────
        Row(
          children: [
            const Icon(Icons.people_alt_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold,
                  ),
                ),
              ),
            _CreateButton(
              isCreating: _isCreating,
              onCreateEmployee: _createEmployee,
              onCreateAdmin: _createAdmin,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Search + filter row ─────────────────────────────────────────────
        Row(
          children: [
            // Search field
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or ID…',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 18,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.gold.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Role filter dropdown
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _roleFilter,
                  dropdownColor: const Color(0xFF1a1a2e),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white54,
                    size: 18,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Roles')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                    DropdownMenuItem(
                      value: 'Employee',
                      child: Text('Employee'),
                    ),
                    DropdownMenuItem(
                      value: 'Customer',
                      child: Text('Customer'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _roleFilter = v ?? 'All'),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── User table (fills remaining space) ──────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Fetch ALL users — filter is_deleted in Dart so documents
            // that never had the field set are not silently excluded.
            stream: FirebaseFirestore.instance.collection('User').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.gold),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final allDocs = snapshot.data?.docs ?? [];
              final filtered = _filtered(allDocs);

              if (allDocs.isEmpty) {
                return _emptyState('No users found.');
              }
              if (filtered.isEmpty) {
                return _emptyState('No users match your search.');
              }

              return _buildTable(filtered);
            },
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
          const Icon(Icons.people_outline, color: Colors.white24, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildTable(List<QueryDocumentSnapshot> docs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                Colors.white.withValues(alpha: 0.07),
              ),
              headingTextStyle: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              dataTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
              dividerThickness: 0.3,
              horizontalMargin: 20,
              columnSpacing: 32,
              dataRowMinHeight: 52,
              dataRowMaxHeight: 52,
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Full Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: docs.map((doc) {
                final data = Map<String, dynamic>.from(
                  doc.data() as Map<String, dynamic>,
                );
                data['uid'] = doc.id;
                return _buildTableRow(doc.id, data);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildTableRow(String uid, Map<String, dynamic> data) {
    final displayId = _getDisplayId(data);
    final name = data['full_name'] as String? ?? '—';
    final email = (data['email'] as String?)?.isNotEmpty == true
        ? data['email'] as String
        : '(not set)';
    final role = data['user_role'] as String? ?? '—';
    final isDisabled = data['is_disabled'] == true;
    final mustChange = data['must_change_password'] == true;

    return DataRow(
      cells: [
        // ID
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayId,
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              if (mustChange) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Awaiting first login',
                  child: const Icon(
                    Icons.schedule,
                    color: Colors.amber,
                    size: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Full Name
        DataCell(
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        // Email
        DataCell(
          Text(
            email,
            style: TextStyle(
              color: email == '(not set)' ? Colors.white38 : Colors.white70,
              fontStyle: email == '(not set)'
                  ? FontStyle.italic
                  : FontStyle.normal,
              fontSize: 12,
            ),
          ),
        ),
        // Role — static badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _roleColor(role).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _roleColor(role).withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Text(
              role.isNotEmpty ? role[0].toUpperCase() + role.substring(1) : '—',
              style: TextStyle(
                color: _roleColor(role),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Status
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDisabled ? Colors.orangeAccent : Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isDisabled ? 'Disabled' : 'Active',
                style: TextStyle(
                  color: isDisabled ? Colors.orangeAccent : Colors.greenAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        // Actions
        DataCell(_buildActionMenu(uid, data, displayId, name, isDisabled)),
      ],
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
      icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      itemBuilder: (_) => [
        if (mustChange && (role == 'employee' || role == 'admin'))
          PopupMenuItem(
            value: 'show_password',
            child: _menuItem(
              Icons.key_outlined,
              'View Temp Password',
              Colors.amber,
            ),
          ),
        PopupMenuItem(
          value: 'toggle_disable',
          child: _menuItem(
            isDisabled ? Icons.lock_open_outlined : Icons.block_outlined,
            isDisabled ? 'Enable User' : 'Disable User',
            isDisabled ? Colors.greenAccent : Colors.orangeAccent,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: _menuItem(
            Icons.delete_outline,
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
                  width: 200,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a2e),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _menuOption(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Create Admin',
                        color: Colors.purpleAccent,
                        onTap: () {
                          _removeOverlay();
                          widget.onCreateAdmin();
                        },
                      ),
                      const SizedBox(height: 4),
                      _menuOption(
                        icon: Icons.badge_outlined,
                        label: 'Create Employee',
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
        child: const Icon(Icons.add, size: 18),
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
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
        ),
      ),
    );
  }
}
