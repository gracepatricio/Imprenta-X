// employee_homepage.dart
// ---------------------------------------------------------------------------
// Platform-aware shell for the employee section.
//
//  ┌──────────────────────────────────────────────────────┐
//  │  Platform   │  Nav items shown                       │
//  ├──────────────────────────────────────────────────────┤
//  │  Web        │  Home · Inventory · Job Queue ·        │
//  │             │  Accounting · Account                  │
//  ├──────────────────────────────────────────────────────┤
//  │  Mobile     │  Job Queue · Account           (only)  │
//  │  (Android/  │  • Job Queue → read-only view          │
//  │   iOS)      │  • Accounting tab → hidden             │
//  │             │  • POS / Sales → hidden                │
//  └──────────────────────────────────────────────────────┘
// ---------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'platform_utils.dart';
import 'employee_home_screen.dart';
import 'employee_inventory_screen.dart';
import 'employee_inventory_forecast_screen.dart';
import 'employee_logs_screen.dart';               // full web version
import 'employee_job_queue_mobile_screen.dart';   // read-only mobile version
import 'employee_account_screen.dart';

class EmployeeHomepage extends StatefulWidget {
  const EmployeeHomepage({super.key});

  @override
  State<EmployeeHomepage> createState() => _EmployeeHomepageState();
}

class _EmployeeHomepageState extends State<EmployeeHomepage> {
  // Nav items differ by platform.
  static const _webItems = [
    'Home',
    'Inventory',
    'Job Queue',
    'Accounting',
    'Account',
  ];

  static const _mobileItems = [
    'Home',
    'Inventory',
    'Job Queue',
    'Account',
  ];

  List<String> get _navItems =>
      PlatformUtils.isMobileDevice ? _mobileItems : _webItems;

  late String _active;

  StreamSubscription<DocumentSnapshot>? _deletionSub;

  @override
  void initState() {
    super.initState();
    // Start on the first available tab for this platform.
    _active = _navItems.first;
    _listenForDeletion();
  }

  // ── Account-deletion listener ────────────────────────────────────────────

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
        // Network unavailable — ignore, listener resumes on reconnect.
      },
    );
  }

  @override
  void dispose() {
    _deletionSub?.cancel();
    super.dispose();
  }

  // ── Screen routing ───────────────────────────────────────────────────────

  Widget get _screen {
    // Mobile employees only reach Job Queue and Account.
    if (PlatformUtils.isMobileDevice) {
      switch (_active) {
        case 'Inventory':
          return const _InventoryTabContainer();
        case 'Account':
          return EmployeeAccountScreen(
            // Mobile: "view logs" shortcut still goes to Job Queue tab.
            onNavigateToLogs: (_) =>
                setState(() => _active = 'Job Queue'),
          );
        case 'Job Queue':
          return const EmployeeMobileJobQueueScreen();
        default:
          return const EmployeeHomeScreen();
      }
    }

    // Web / desktop: full feature set.
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: Column(
          children: [
            AppNavBar(
              items: _navItems,
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

// ── Inventory tab container (web only) ────────────────────────────────────

class _InventoryTabContainer extends StatefulWidget {
  const _InventoryTabContainer();

  @override
  State<_InventoryTabContainer> createState() =>
      _InventoryTabContainerState();
}

class _InventoryTabContainerState extends State<_InventoryTabContainer> {
  int _tab = 0; // 0 = Inventory, 1 = Forecast

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        padding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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