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

// ── Home branding ─────────────────────────────────────────────────────────────

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
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25), width: 1.5),
              ),
              child: ClipOval(
                child: Image.asset('assets/images/imprentalogo.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_print_shop,
                        color: Colors.white, size: 40)),
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: const Text('IMPRENTA INC.',
                  style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gold,
                      letterSpacing: 4)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Specializes in manufacturing of\ncustomized product printing.',
              style: TextStyle(fontSize: 14, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Everything below this line is intentionally removed (moved to
// admin_account_dashboard.dart).
// ──────────────────────────────────────────────────────────────────────────────
/*
class _REMOVED extends StatelessWidget {
  static String _computeStatus(num current, num restock) {
    if (current <= 0)              return 'Out of Stock';
    if (current <= restock * 0.5)  return 'Critical';
    if (current <= restock)        return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // ── Quick stats ──────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Orders')
                .snapshots(),
            builder: (context, snap) {
              int pending = 0, active = 0, ready = 0;
              for (final d in snap.data?.docs ?? []) {
                final s = (d.data() as Map)['status']?.toString() ?? '';
                if (s == 'pending')          pending++;
                if (s == 'in_production')    active++;
                if (s == 'ready_for_pickup') ready++;
              }
              final cards = [
                _StatCard('Pending Orders',  pending, Icons.sync,                Colors.red),
                _StatCard('In Production',   active,  Icons.inventory_2_outlined, Colors.orange),
                _StatCard('Ready for Pickup', ready,  Icons.check_circle,         Colors.green),
              ];
              return LayoutBuilder(builder: (_, constraints) {
                if (constraints.maxWidth >= 420) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[2]),
                      ],
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    cards[0],
                    const SizedBox(height: 10),
                    cards[1],
                    const SizedBox(height: 10),
                    cards[2],
                  ],
                );
              });
            },
          ),

          const SizedBox(height: 28),

          // ── Products needing replenishment ───────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('RawMaterials')
                .snapshots(),
            builder: (context, snap) {
              final all = snap.data?.docs ?? [];
              final needsAttention = all.where((d) {
                final data    = d.data() as Map<String, dynamic>;
                final current = (data['current_stock'] as num?) ?? 0;
                final restock = (data['restock_level']  as num?) ?? 1;
                final status  = _computeStatus(current, restock);
                return status != 'In Stock';
              }).toList();

              // Sort: Out of Stock → Critical → Low Stock
              needsAttention.sort((a, b) {
                const order = {'Out of Stock': 0, 'Critical': 1, 'Low Stock': 2};
                final aD = a.data() as Map;
                final bD = b.data() as Map;
                final aS = _computeStatus(
                    (aD['current_stock'] as num?) ?? 0,
                    (aD['restock_level']  as num?) ?? 1);
                final bS = _computeStatus(
                    (bD['current_stock'] as num?) ?? 0,
                    (bD['restock_level']  as num?) ?? 1);
                return (order[aS] ?? 3).compareTo(order[bS] ?? 3);
              });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Stock Replenishment',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (needsAttention.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.5)),
                          ),
                          child: Text('${needsAttention.length} items',
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (needsAttention.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCard(opacity: 0.1),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: Colors.greenAccent, size: 18),
                          SizedBox(width: 10),
                          Text('All materials are sufficiently stocked',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ...needsAttention.take(6).map((d) {
                      final data    = d.data() as Map<String, dynamic>;
                      final name    = data['material_name']?.toString() ?? d.id;
                      final current = (data['current_stock'] as num?) ?? 0;
                      final restock = (data['restock_level']  as num?) ?? 1;
                      final unit    = data['unit_description']?.toString() ?? '';
                      final status  = _computeStatus(current, restock);
                      final color   = switch (status) {
                        'Out of Stock' => Colors.redAccent,
                        'Critical'     => const Color(0xFFFF6D00),
                        _              => Colors.amber,
                      };
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: AppTheme.glassCard(
                            opacity: 0.12, radius: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Text(
                                '$current / $restock $unit',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withValues(alpha: 0.4)),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Unread customer reviews ──────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('OrderReviews')
                .snapshots(),
            builder: (context, snap) {
              final all = snap.data?.docs ?? [];
              final unread = all
                  .where((d) =>
                      (d.data() as Map)['read'] != true)
                  .toList()
                ..sort((a, b) {
                  final at = (a.data() as Map)['created_at'];
                  final bt = (b.data() as Map)['created_at'];
                  if (at == null || bt == null) return 0;
                  return (bt as dynamic).compareTo(at);
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Customer Reviews',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (unread.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: Text('${unread.length} unread',
                              style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (unread.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCard(opacity: 0.1),
                      child: const Center(
                        child: Text('No unread reviews',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ),
                    )
                  else
                    ...unread.take(5).map((d) {
                      final data       = d.data() as Map<String, dynamic>;
                      final customer   = data['customer_name']?.toString() ?? 'Customer';
                      final product    = data['product_name']?.toString() ?? '';
                      final rating     = (data['rating'] as num?)?.toInt() ?? 0;
                      final message    = data['message']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration:
                            AppTheme.glassCard(opacity: 0.13, radius: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(customer,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: i < rating
                                          ? AppTheme.gold
                                          : Colors.white24,
                                      size: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Mark as read button
                                GestureDetector(
                                  onTap: () => FirebaseFirestore.instance
                                      .collection('OrderReviews')
                                      .doc(d.id)
                                      .update({'read': true}),
                                  child: const Icon(Icons.check_circle_outline,
                                      color: Colors.white38, size: 16),
                                ),
                              ],
                            ),
                            if (product.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(product,
                                  style: const TextStyle(
                                      color: AppTheme.gold, fontSize: 11)),
                            ],
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(message,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Shared stat card ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.count, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(opacity: 0.12, radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
*/
