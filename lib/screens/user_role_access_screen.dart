import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'app_theme.dart';

class UserRoleAccessScreenEmbedded extends StatefulWidget {
  const UserRoleAccessScreenEmbedded({super.key});

  @override
  State<UserRoleAccessScreenEmbedded> createState() =>
      _UserRoleAccessScreenEmbeddedState();
}

class _UserRoleAccessScreenEmbeddedState
    extends State<UserRoleAccessScreenEmbedded> {
  final CollectionReference _usersRef = FirebaseFirestore.instance.collection(
    'User',
  );

  final Map<String, String> _editedRoles = {};
  bool _isSaving = false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  Future<void> _saveChanges() async {
    if (_editedRoles.isEmpty) return;
    setState(() => _isSaving = true);
    final svc = AuthService();
    for (final e in _editedRoles.entries) {
      if (e.value == 'employee') {
        await svc.promoteToEmployee(e.key);
      } else if (e.value == 'admin') {
        await svc.promoteToAdmin(e.key);
      } else {
        await svc.demoteToCustomer(e.key);
      }
    }
    setState(() {
      _editedRoles.clear();
      _isSaving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Roles updated successfully")),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmDelete(String userId, String name, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14142B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
        ),
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              "Delete User",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "$name" from the system?\nThis action cannot be undone.',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = FirebaseFirestore.instance;
              await _usersRef.doc(userId).update({'is_deleted': true});
              await db.collection('email_index').doc(email).set({
                'status': 'deleted',
                'uid': userId,
              });
              setState(() => _editedRoles.remove(userId));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$name" has been deactivated')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              "Delete",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ───────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "User Roles & Access",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage roles assigned to each user account",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (_editedRoles.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  _isSaving
                      ? "Saving..."
                      : "Save ${_editedRoles.length} change${_editedRoles.length == 1 ? '' : 's'}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Search + Filter ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            }),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.gold, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRoleFilter,
                    dropdownColor: const Color(0xFF1a1a2e),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Roles')),
                      DropdownMenuItem(
                        value: 'customer',
                        child: Text('Customer'),
                      ),
                      DropdownMenuItem(
                        value: 'employee',
                        child: Text('Employee'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _selectedRoleFilter = value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Table Header ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: const [
              Expanded(flex: 4, child: Text("NAME", style: _headerStyle)),
              Expanded(flex: 4, child: Text("EMAIL", style: _headerStyle)),
              Expanded(flex: 3, child: Text("ROLE", style: _headerStyle)),
              Expanded(
                flex: 2,
                child: Center(child: Text("ACTIONS", style: _headerStyle)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── User List ────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              final users = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['is_deleted'] != true;
              }).toList();

              final searchedUsers = users.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final name = (data['full_name'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                final role =
                    (_editedRoles[d.id] ?? data['user_role'] ?? 'customer')
                        .toString()
                        .toLowerCase();

                final matchesSearch =
                    _searchQuery.isEmpty ||
                    name.contains(_searchQuery) ||
                    email.contains(_searchQuery);
                final matchesRole =
                    _selectedRoleFilter == 'all' || role == _selectedRoleFilter;

                return matchesSearch && matchesRole;
              }).toList();

              if (searchedUsers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      SizedBox(height: 10),
                      Text(
                        "No users found",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: searchedUsers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final user = searchedUsers[i];
                  final uid = user.id;
                  final data = user.data() as Map<String, dynamic>;
                  final name = data['full_name']?.toString() ?? '—';
                  final email = data['email']?.toString() ?? '—';
                  final savedRole = data['user_role']?.toString() ?? 'customer';
                  final displayRole = _editedRoles[uid] ?? savedRole;
                  final isDirty = _editedRoles.containsKey(uid);

                  return _UserRow(
                    name: name,
                    email: email,
                    currentRole: displayRole,
                    isDirty: isDirty,
                    onRoleChanged: (newRole) {
                      setState(() {
                        if (newRole == savedRole) {
                          _editedRoles.remove(uid);
                        } else {
                          _editedRoles[uid] = newRole;
                        }
                      });
                    },
                    onDelete: () => _confirmDelete(uid, name, email),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 1,
  );
}

// ── User Row ─────────────────────────────────────────────────────────────────

class _UserRow extends StatelessWidget {
  final String name;
  final String email;
  final String currentRole;
  final bool isDirty;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onDelete;

  const _UserRow({
    required this.name,
    required this.email,
    required this.currentRole,
    required this.isDirty,
    required this.onRoleChanged,
    required this.onDelete,
  });

  Color get _roleColor {
    switch (currentRole) {
      case 'admin':
        return const Color.fromARGB(216, 255, 233, 173);
      case 'employee':
        return const Color.fromARGB(221, 21, 101, 192); // darker blue
      default:
        return const Color.fromARGB(221, 0, 137, 123); // darker teal
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // Glass look retained — just thicker so it's more opaque
        color: isDirty
            ? AppTheme.gold.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDirty
              ? AppTheme.gold.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.25), // 🔥 reduced
          width: 1.0, // slightly thinner
        ),
      ),
      child: Row(
        children: [
          // ── Name ──────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _roleColor.withValues(alpha: 0.25),
                    border: Border.all(color: _roleColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _roleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          // ── Email ─────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                email,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),

          // ── Role Dropdown ─────────────────────────────────────
          Expanded(
            flex: 3,
            child: _RoleDropdown(
              currentRole: currentRole,
              onChanged: onRoleChanged,
            ),
          ),

          // ── Delete ────────────────────────────────────────────
          Expanded(
            flex: 2,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  // Glass red — more opaque than before so it's visible
                  backgroundColor: Colors.red.shade700.withValues(alpha: 0.85),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.shade300, width: 1.2),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: const Text(
                  "Delete",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role Dropdown ─────────────────────────────────────────────────────────────

class _RoleDropdown extends StatelessWidget {
  final String currentRole;
  final ValueChanged<String> onChanged;

  const _RoleDropdown({required this.currentRole, required this.onChanged});

  static const _roles = ['customer', 'employee', 'admin'];

  Color _colorFor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.gold;
      case 'employee':
        return const Color(0xFF1565C0); // darker blue
      default:
        return const Color(0xFF00897B); // darker teal
    }
  }

  String _labelFor(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'employee':
        return 'Employee';
      default:
        return 'Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(currentRole);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // 🔥 FIX: solid readable background
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentRole,
          isDense: true,
          isExpanded: true,
          padding: EdgeInsets.zero,
          iconSize: 15,
          dropdownColor: const Color(0xFF1a1a2e),
          borderRadius: BorderRadius.circular(12),

          // 🔥 FIX: keep icon visible
          icon: const Icon(
            Icons.expand_more_rounded,
            color: Colors.white,
            size: 16,
          ),

          // 🔥 FIX: text always readable
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),

          items: _roles.map((role) {
            final c = _colorFor(role);
            return DropdownMenuItem(
              value: role,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _labelFor(role),
                    // 🔥 FIX: white text inside dropdown
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
