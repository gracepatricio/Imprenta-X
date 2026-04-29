import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'customer_home_screen.dart';
import 'customer_about_screen.dart';
import 'customer_products_screen.dart';
import 'customer_account_screen.dart';

class CustomerHomepage extends StatefulWidget {
  const CustomerHomepage({super.key});

  @override
  State<CustomerHomepage> createState() => _CustomerHomepageState();
}

class _CustomerHomepageState extends State<CustomerHomepage> {
  static const _items = ['Home', 'About', 'Products', 'Account'];
  String _active = 'Home';

  StreamSubscription<DocumentSnapshot>? _deletionSub;

  @override
  void initState() {
    super.initState();
    _listenForDeletion();
  }

  /// Signs the user out and returns to login the moment an admin
  /// deletes their Firestore User document.
  void _listenForDeletion() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _deletionSub = FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .snapshots()
        .listen((snap) async {
      final deleted = !snap.exists ||
          (snap.data() as Map?)?['is_deleted'] == true;
      if (deleted && mounted) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/', (_) => false);
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
      case 'About':    return const CustomerAboutScreen();
      case 'Products': return const CustomerProductsScreen();
      case 'Account':  return const CustomerAccountScreen();
      default:
        return CustomerHomeScreen(
          onViewProducts: () => setState(() => _active = 'Products'),
        );
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
              items:      _items,
              activeItem: _active,
              onTap:      (item) => setState(() => _active = item),
            ),
            Expanded(child: _screen),
          ],
        ),
      ),
    );
  }
}
