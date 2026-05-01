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
        .listen(
          (snap) async {
            final deleted =
                !snap.exists || (snap.data() as Map?)?['is_deleted'] == true;
            if (deleted && mounted) {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/', (_) => false);
              }
            }
          },
          onError: (_) {
            // Network unavailable — ignore, listener will resume when reconnected
          },
        );
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
        return const _AdminHomeContent();
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
                        onNavigateToTab: (tab) {
                          setState(() => _active = tab);
                        },
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

// ── Home content ──────────────────────────────────────────────────────────────

class _AdminHomeContent extends StatelessWidget {
  const _AdminHomeContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/imprentalogo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_print_shop,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: const Text(
                "IMPRENTA INC.",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Specializes in manufacturing of\ncustomized product printing.",
              style: TextStyle(fontSize: 15, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
