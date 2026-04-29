import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'employee_home_screen.dart';
import 'employee_inventory_screen.dart';
import 'employee_logs_screen.dart';
import 'employee_account_screen.dart';

class EmployeeHomepage extends StatefulWidget {
  const EmployeeHomepage({super.key});

  @override
  State<EmployeeHomepage> createState() => _EmployeeHomepageState();
}

class _EmployeeHomepageState extends State<EmployeeHomepage> {
  static const _items = ['Home', 'Inventory', 'Logs & History', 'Account'];
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
        .listen((snap) async {
          final deleted =
              !snap.exists || (snap.data() as Map?)?['is_deleted'] == true;
          if (deleted && mounted) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            }
          }
        });
  }

  @override
  void dispose() {
    _deletionSub?.cancel();
    super.dispose();
  }

  Widget get _screen {
    switch (_active) {
      case 'Inventory':
        return const EmployeeInventoryScreen();
      case 'Logs & History':
        return const EmployeeLogsScreen();
      case 'Account':
        return const EmployeeAccountScreen();
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
