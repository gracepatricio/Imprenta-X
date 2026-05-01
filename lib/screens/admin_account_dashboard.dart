import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'user_role_access_screen.dart';
import 'admin_manage_account.dart';

class AdminAccountDashboard extends StatefulWidget {
  /// Called when the user taps a non-Account navbar item while in this screen.
  /// The parent [AdminHomepage] uses this to switch to the right tab after pop.
  final void Function(String tab)? onNavigateToTab;

  const AdminAccountDashboard({super.key, this.onNavigateToTab});

  @override
  State<AdminAccountDashboard> createState() => _AdminAccountDashboardState();
}

class _AdminAccountDashboardState extends State<AdminAccountDashboard> {
  static const _adminNavItems = [
    'Home',
    'Inventory',
    'Products',
    'Logs & History',
    'Account',
  ];

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
              items: _adminNavItems,
              activeItem: "Account",
              onTap: (item) {
                if (item == "Account") return; // already here
                // Pop back to AdminHomepage and switch to the tapped tab
                Navigator.pop(context);
                widget.onNavigateToTab?.call(item);
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
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
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
              : Colors.white.withValues(alpha: 0.12),
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
        return AdminManageAccount(
          onNameUpdated: (newName) {
            setState(() => fullName = newName);
          },
        );
      case "roles":
        return const UserRoleAccessScreenEmbedded();
      default:
        return const SizedBox.shrink();
    }
  }
}
