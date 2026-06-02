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
import 'employee_logs_screen.dart'; // full web version
import 'employee_job_queue_mobile_screen.dart'; // read-only mobile version
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

  static const _mobileItems = ['Home', 'Inventory', 'Job Queue', 'Account'];

  List<String> get _navItems =>
      PlatformUtils.isMobileDevice ? _mobileItems : _webItems;

  late String _active;

  StreamSubscription<DocumentSnapshot>? _deletionSub;

  @override
  void initState() {
    super.initState();
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
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (_) => false);
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
          return const EmployeeInventoryScreen();
        case 'Account':
          return EmployeeAccountScreen(
            // Mobile: "view logs" shortcut still goes to Job Queue tab.
            onNavigateToLogs: (_) => setState(() => _active = 'Job Queue'),
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
        return const EmployeeInventoryScreen();
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
        decoration: AppTheme.backgroundDecoration(context),
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
