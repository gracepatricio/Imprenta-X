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
  final CollectionReference usersRef = FirebaseFirestore.instance.collection(
    'User',
  );

  Map<String, String> editedRoles = {};

  void updateRole(String userId, String newRole) {
    editedRoles[userId] = newRole;
  }

  Future<void> saveChanges() async {
    final authService = AuthService();

    for (var entry in editedRoles.entries) {
      String uid = entry.key;
      String newRole = entry.value;

      if (newRole == "employee") {
        // Generates a new employee_id, nulls out customer_id
        await authService.promoteToEmployee(uid);
      } else if (newRole == "admin") {
        // No admin_id in ERD — nulls out both customer_id and employee_id
        await authService.promoteToAdmin(uid);
      } else if (newRole == "customer") {
        // Generates a new customer_id, nulls out employee_id
        await authService.demoteToCustomer(uid);
      }
    }

    setState(() => editedRoles.clear());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Roles updated successfully")));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: usersRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        var users = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Manage User Roles and Access",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            _tableHeader(),

            const SizedBox(height: 6),

            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var user = users[index];
                  String userId = user.id;
                  String currentRole =
                      editedRoles[userId] ?? user['user_role'] ?? 'customer';

                  return _tableRow(user, userId, currentRole);
                },
              ),
            ),

            const SizedBox(height: 12),

            Align(
              alignment: Alignment(0.0, 0.0),
              child: SizedBox(
                width: 160,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade500,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  onPressed: editedRoles.isEmpty ? null : saveChanges,
                  child: const Text("Save Changes"),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              "Name",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              "Email",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                "Role",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                "Actions",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(
    QueryDocumentSnapshot user,
    String userId,
    String currentRole,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              user['full_name'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              user['email'] ?? '',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentRole,
                    dropdownColor: const Color(0xFF1e1e3a),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white60,
                      size: 18,
                    ),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: "customer",
                        child: Text("Customer"),
                      ),
                      DropdownMenuItem(
                        value: "employee",
                        child: Text("Employee"),
                      ),
                      DropdownMenuItem(value: "admin", child: Text("Admin")),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => updateRole(userId, value));
                      }
                    },
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            flex: 1,
            child: Center(
              child: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    await usersRef.doc(userId).delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("User deleted")),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text("Delete"),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
