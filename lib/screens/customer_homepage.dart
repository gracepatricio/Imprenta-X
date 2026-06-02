import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'customer_home_screen.dart';
import 'customer_about_screen.dart';
import 'customer_products_screen.dart';
import 'customer_cart_screen.dart';
import 'customer_account_screen.dart';
import '../services/cart_manager.dart';

class CustomerHomepage extends StatefulWidget {
  const CustomerHomepage({super.key});

  @override
  State<CustomerHomepage> createState() => _CustomerHomepageState();
}

class _CustomerHomepageState extends State<CustomerHomepage> {
  String _active = 'Home';

  StreamSubscription<DocumentSnapshot>? _deletionSub;

  @override
  void initState() {
    super.initState();
    _listenForDeletion();
    // On web page reload (e.g. after returning from PayMongo), the session is
    // restored without going through login(), so CartManager.loadForUser is
    // never called. Reload here to ensure the cart is always available.
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      CartManager.loadForUser(user.uid);
    }
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

  Widget _screen(int cartCount) {
    switch (_active) {
      case 'About':    return const CustomerAboutScreen();
      case 'Products': return const CustomerProductsScreen();
      case 'Cart':
        return CustomerCartScreen(
          onOrderPlaced: () => setState(() => _active = 'Account'),
        );
      case 'Account':  return const CustomerAccountScreen();
      default:
        return CustomerHomeScreen(
          onViewProducts: () => setState(() => _active = 'Products'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CartManager.count,
      builder: (context, cartCount, _) {
        final cartLabel = cartCount > 0 ? 'Cart ($cartCount)' : 'Cart';
        final items = ['Home', 'About', 'Products', cartLabel, 'Account'];
        final activeItem = _active == 'Cart' ? cartLabel : _active;

        return Scaffold(
          body: Container(
decoration: AppTheme.backgroundDecoration(context),
            child: Column(
              children: [
                AppNavBar(
                  items:      items,
                  activeItem: activeItem,
                  onTap: (item) => setState(() {
                    _active = item.startsWith('Cart') ? 'Cart' : item;
                  }),
                ),
                Expanded(child: _screen(cartCount)),
              ],
            ),
          ),
        );
      },
    );
  }
}
