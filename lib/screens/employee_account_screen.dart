import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class EmployeeAccountScreen extends StatefulWidget {
  const EmployeeAccountScreen({super.key});

  @override
  State<EmployeeAccountScreen> createState() => _EmployeeAccountScreenState();
}

class _EmployeeAccountScreenState extends State<EmployeeAccountScreen> {
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
        fullName = doc.data()?['full_name'] ?? user.displayName ?? "Employee";
        email = doc.data()?['email'] ?? user.email ?? "";
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: isWide ? _wideLayout() : _mobileLayout(),
        );
      },
    );
  }

  // ── Wide: sidebar + content both fill the same height naturally ────────────
  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar — fixed width, no Spacer, no IntrinsicHeight
        Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: AppTheme.glassCard(opacity: 0.18),
          child: Column(
            mainAxisSize: MainAxisSize.min, // shrink to content
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(),
              const SizedBox(height: 10),
              _nameEmail(),
              const SizedBox(height: 24),
              _menuButtons(),
              const SizedBox(height: 24),
              _logoutButton(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Content fills remaining width
        Expanded(child: _buildContent()),
      ],
    );
  }

  // ── Mobile: stacked, all scrollable ───────────────────────────────────────
  Widget _mobileLayout() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: AppTheme.glassCard(opacity: 0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _avatar(),
                const SizedBox(height: 10),
                _nameEmail(),
                const SizedBox(height: 24),
                _menuButtons(),
                const SizedBox(height: 20),
                _logoutButton(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildContent(),
        ],
      ),
    );
  }

  // ── Sidebar pieces ─────────────────────────────────────────────────────────

  Widget _avatar() {
    return Container(
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
    );
  }

  Widget _nameEmail() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          email,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _menuButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sidebarButton(
          "Dashboard",
          selectedMenu == "dashboard",
          () => setState(() => selectedMenu = "dashboard"),
        ),
        const SizedBox(height: 8),
        _sidebarButton(
          "Messages",
          selectedMenu == "messages",
          () => setState(() => selectedMenu = "messages"),
        ),
        const SizedBox(height: 8),
        _sidebarButton(
          "Manage Account",
          selectedMenu == "manage",
          () => setState(() => selectedMenu = "manage"),
        ),
      ],
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
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
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
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        child: const Text("Logout"),
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────

  Widget _buildContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(opacity: 0.15),
      child: () {
        switch (selectedMenu) {
          case "dashboard":
            return _buildDashboard();
          case "messages":
            return const _Placeholder(
              icon: Icons.message_outlined,
              label: "Messages",
            );
          case "manage":
            return const _Placeholder(
              icon: Icons.manage_accounts_outlined,
              label: "Manage Account",
            );
          default:
            return const SizedBox.shrink();
        }
      }(),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Welcome back, $fullName!",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 480;
            final cards = [
              _statCard(Icons.sync, Colors.red, "—", "Pending Orders"),
              _statCard(
                Icons.inventory_2_outlined,
                Colors.orange,
                "—",
                "Active Orders",
              ),
              _statCard(
                Icons.check_circle,
                Colors.green,
                "—",
                "Orders to be\nPicked Up",
              ),
            ];
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[2]),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                cards[0],
                const SizedBox(height: 12),
                cards[1],
                const SizedBox(height: 12),
                cards[2],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.12, radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder ────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Placeholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Coming soon",
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
