import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_account_dashboard.dart';
import 'admin_inventory_screen.dart';
import 'admin_product_management_screen.dart';
import 'admin_logs_screen.dart';

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xEEFFFFFF);
  static const Color surfaceMid = Color(0xCCFFFFFF);
  static const Color surfaceThin = Color(0x99FFFFFF);
  static const Color borderMid = Color(0x55FFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xBB111827);
  static const Color textMuted = Color(0x77111827);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 20,
    spreadRadius: -2,
    offset: Offset(0, 6),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );
}

// =============================================================================
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
    _loadAdminName();
    _listenForDeletion();
  }

  Future<void> _loadAdminName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _adminName = doc.data()?['full_name'] ?? user.displayName ?? '';
      });
    }
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: _AdminHomeContent(adminName: _adminName),
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

// =============================================================================
// Home content
// =============================================================================
class _AdminHomeContent extends StatelessWidget {
  final String adminName;
  const _AdminHomeContent({this.adminName = ''});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final displayName = adminName.isNotEmpty ? adminName : 'Admin';

    return Center(
      child: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Logo + brand block ──────────────────────────────────
            Column(
              children: [
                // Logo with shadow
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 32,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/imprentalogo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        child: Icon(
                          Icons.local_print_shop_rounded,
                          color: Colors.white.withValues(alpha: 0.80),
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Brand name
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      const Color(0xFFFFE9AD).withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds),
                  child: const Text(
                    'IMPRENTA INC.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Tagline
                Text(
                  'Specializes in manufacturing of customized product printing.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),

            const SizedBox(height: 36),

            // ── Greeting card — aligned to navbar (blur 18, alpha 0.72, border 0.45) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xAAFFFFFF), // soft white muted
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Admin badge — same dark pill as active navbar item
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.55),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              color: AppTheme.gold,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Admin',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
