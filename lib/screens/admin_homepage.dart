import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_account_dashboard.dart';
import 'admin_inventory_screen.dart';
import 'admin_product_management_screen.dart';
import 'admin_logs_screen.dart';

class AdminHomepage extends StatefulWidget {
  const AdminHomepage({super.key, this.initialTab = 'Home'});
  final String initialTab;

  @override
  State<AdminHomepage> createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage> {
  static const _items = [
    'Home',
    'Inventory',
    'Products',
    'Logs & History',
    'Account',
  ];

  late String _active;
  StreamSubscription<DocumentSnapshot>? _deletionSub;
  String _adminName = '';

  @override
  void initState() {
    super.initState();
    _active = widget.initialTab;
    _listenForDeletion();
  }

  void _listenForDeletion() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _deletionSub = FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .snapshots()
        .listen((snap) async {
          final deleted =
              !snap.exists || (snap.data() as Map?)?['is_deleted'] == true;
          if (deleted && mounted) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            }
          }
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _deletionSub?.cancel();
    super.dispose();
  }

  Widget get _screen {
    switch (_active) {
      case 'Inventory':
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AdminInventoryScreen(),
        );
      case 'Products':
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AdminProductManagementScreen(),
        );
      case 'Logs & History':
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AdminLogsScreen(),
        );
      default:
        return _AdminHomeContent(adminName: _adminName);
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
              items: _items,
              activeItem: _active,
              onTap: (item) {
                if (item == 'Account') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminAccountDashboard(
                        onNavigateToTab: (tab) => setState(() => _active = tab),
                      ),
                    ),
                  );
                } else {
                  setState(() => _active = item);
                }
              },
            ),
            Expanded(child: _screen),
          ],
        ),
      ),
    );
  }
}

// ── Home branding ─────────────────────────────────────────────────────────────

class _AdminHomeContent extends StatelessWidget {
  final String adminName;
  const _AdminHomeContent({this.adminName = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.45),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/imprentalogo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_print_shop,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: const Text(
                'IMPRENTA INC.',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: Color(0x80000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Subtitle — plain text, no pill/container
            const Text(
              'Specializes in manufacturing of customized product printing.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Admin badge (no 'Panel')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    color: AppTheme.gold,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Admin',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
