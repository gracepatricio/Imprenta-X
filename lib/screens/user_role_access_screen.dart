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
  final CollectionReference _usersRef =
  FirebaseFirestore.instance.collection('User');

  final Map<String, String> _editedRoles = {};
  bool _isSaving = false;

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

  void _confirmDelete(String userId, String name, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        title: const Text(
          "Delete User",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove "$name" from the system? This cannot be undone.',
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = FirebaseFirestore.instance;
              // Mark the User doc as deleted (blocks login).
              await _usersRef.doc(userId).update({'is_deleted': true});
              // Write a publicly-readable flag so unauthenticated
              // registration checks can detect admin-deleted accounts.
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
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete"),
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
        // ── Header ──────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User Roles & Access",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage roles assigned to each user",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.check, size: 15),
                label: Text(
                  _isSaving ? "Saving..." : "Save ${_editedRoles.length}",
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Table header ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 4,
                child: Text("NAME", style: _headerStyle),
              ),
              Expanded(
                flex: 4,
                child: Text("EMAIL", style: _headerStyle),
              ),
              Expanded(
                flex: 4,
                child: Text("ROLE", style: _headerStyle),
              ),
              SizedBox(
                width: 28,
                child: Center(child: Text("DEL", style: _headerStyle)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ── User list ────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _usersRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              // Filter out soft-deleted accounts.
              final users = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['is_deleted'] != true;
              }).toList();
              if (users.isEmpty) {
                return const Center(
                  child: Text("No users found",
                      style: TextStyle(color: Colors.white38)),
                );
              }
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (context, i) {
                  final user = users[i];
                  final uid = user.id;
                  final data = user.data() as Map<String, dynamic>;
                  final name = data['full_name']?.toString() ?? '—';
                  final email = data['email']?.toString() ?? '—';
                  final savedRole =
                      data['user_role']?.toString() ?? 'customer';
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
    color: Colors.white54,
    fontWeight: FontWeight.w700,
    fontSize: 11,
    letterSpacing: 1,
  );
}

// ── User Row ───────────────────────────────────────────────────────────────

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
      case 'admin':    return AppTheme.gold;
      case 'employee': return Colors.blueAccent;
      default:         return Colors.tealAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: isDirty
            ? AppTheme.gold.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDirty
              ? AppTheme.gold.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          // Name column
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _roleColor.withValues(alpha: 0.15),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: _roleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),

          // Email column
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                email,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),

          // Role dropdown column
          Expanded(
            flex: 4,
            child: _RoleDropdown(
              currentRole: currentRole,
              onChanged: onRoleChanged,
            ),
          ),

          // Delete button
          SizedBox(
            width: 28,
            child: Center(
              child: IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.shade400,
                iconSize: 16,
                tooltip: "Delete user",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Role Dropdown ──────────────────────────────────────────────────────────

class _RoleDropdown extends StatelessWidget {
  final String currentRole;
  final ValueChanged<String> onChanged;

  const _RoleDropdown({
    required this.currentRole,
    required this.onChanged,
  });

  static const _roles = ['customer', 'employee', 'admin'];

  Color _colorFor(String role) {
    switch (role) {
      case 'admin':    return AppTheme.gold;
      case 'employee': return Colors.pinkAccent;
      default:         return Colors.tealAccent;
    }
  }

  String _labelFor(String role) {
    switch (role) {
      case 'admin':    return 'Admin';
      case 'employee': return 'Employee';
      default:         return 'Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(currentRole);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentRole,
          isDense: true,
          isExpanded: true,
          padding: EdgeInsets.zero,
          iconSize: 14,
          dropdownColor: const Color(0xFF1e1e3a),
          borderRadius: BorderRadius.circular(12),
          icon: Icon(Icons.expand_more, color: color, size: 14),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Spartan',
          ),
          items: _roles.map((role) {
            final c = _colorFor(role);
            return DropdownMenuItem(
              value: role,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _labelFor(role),
                    style: TextStyle(
                      color: c,
                      fontSize: 13,
                      fontFamily: 'Spartan',
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