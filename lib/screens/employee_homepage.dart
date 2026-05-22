import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'employee_home_screen.dart';
import 'employee_inventory_screen.dart';
import 'employee_inventory_forecast_screen.dart';
import 'employee_logs_screen.dart';
import 'employee_account_screen.dart';

class EmployeeHomepage extends StatefulWidget {
  const EmployeeHomepage({super.key});

  @override
  State<EmployeeHomepage> createState() => _EmployeeHomepageState();
}

class _EmployeeHomepageState extends State<EmployeeHomepage> {
  static const _items = ['Home', 'Inventory', 'Job Queue', 'Accounting', 'Account'];
  String _active = 'Home';

  StreamSubscription<DocumentSnapshot>? _deletionSub;

  @override
  void initState() {
    super.initState();
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
        return const _InventoryTabContainer();
      case 'Job Queue':
        return const EmployeeJobQueueScreen();
      case 'Accounting':
        return const EmployeeLogsScreen();
      case 'Account':
        return EmployeeAccountScreen(
          onNavigateToLogs: (_) => setState(() => _active = 'Job Queue'),
        );
      default:
        return const EmployeeHomeScreen();
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
              onTap: (item) => setState(() => _active = item),
            ),
            Expanded(child: _screen),
          ],
        ),
      ),
    );
  }
}

// ── Inventory tab container (Inventory | Forecast) ────────────────────────────

class _InventoryTabContainer extends StatefulWidget {
  const _InventoryTabContainer();

  @override
  State<_InventoryTabContainer> createState() => _InventoryTabContainerState();
}

class _InventoryTabContainerState extends State<_InventoryTabContainer> {
  int _tab = 0; // 0 = Inventory, 1 = Forecast

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pill tab bar — matches the pattern used throughout the app
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              _InventoryPillTab(
                label: 'Inventory',
                icon: Icons.inventory_2_outlined,
                isActive: _tab == 0,
                onTap: () => setState(() => _tab = 0),
              ),
              const SizedBox(width: 8),
              _InventoryPillTab(
                label: 'Forecast',
                icon: Icons.trending_up_rounded,
                isActive: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _tab == 0
              ? const EmployeeInventoryScreen()
              : const EmployeeInventoryForecastScreen(),
        ),
      ],
    );
  }
}

class _InventoryPillTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _InventoryPillTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.gold
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white70,
                fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}