import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'user_role_access_screen.dart';
import 'admin_homepage.dart';

class AdminAccountDashboard extends StatefulWidget {
  const AdminAccountDashboard({super.key});

  @override
  State<AdminAccountDashboard> createState() => _AdminAccountDashboardState();
}

class _AdminAccountDashboardState extends State<AdminAccountDashboard> {
  String selectedMenu = "dashboard";
  String fullName = "";
  String email = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        fullName = doc.data()?['full_name'] ?? user.displayName ?? "Admin";
        email = doc.data()?['email'] ?? user.email ?? "";
      });
    }
  }

  // 🔥 FIXED: uses named route to fully clear the stack and go to login
  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: Column(
          children: [
            AppNavBar(
              activeItem: "Account",
              onTap: (item) {
                if (item == "Home") {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminHomepage()),
                    (route) => false,
                  );
                }
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebar(),
                    const SizedBox(width: 16),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: AppTheme.glassCard(opacity: 0.18),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.person, size: 40, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            fullName.isNotEmpty ? fullName : "Loading...",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : "",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          _sidebarButton("Dashboard", selectedMenu == "dashboard", () {
            setState(() => selectedMenu = "dashboard");
          }),
          const SizedBox(height: 8),
          _sidebarButton("Manage Account", selectedMenu == "manage", () {
            setState(() => selectedMenu = "manage");
          }),
          const SizedBox(height: 8),
          _sidebarButton("User Role and Access", selectedMenu == "roles", () {
            setState(() => selectedMenu = "roles");
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("Logout"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarButton(String label, bool isActive, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? AppTheme.gold
              : Colors.white.withOpacity(0.12),
          foregroundColor: isActive ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(opacity: 0.15),
      child: _getContentWidget(),
    );
  }

  Widget _getContentWidget() {
    switch (selectedMenu) {
      case "dashboard":
        return const Center(
          child: Text(
            "Dashboard",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        );
      case "manage":
        return const Center(
          child: Text(
            "Manage Account",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        );
      case "roles":
        return const UserRoleAccessScreenEmbedded();
      default:
        return const SizedBox.shrink();
    }
  }
}
