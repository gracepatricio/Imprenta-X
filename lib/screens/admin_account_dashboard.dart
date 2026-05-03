import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'user_role_access_screen.dart';
import 'admin_manage_account.dart';

class AdminAccountDashboard extends StatefulWidget {
  /// Called when the user taps a non-Account navbar item while in this screen.
  /// The parent [AdminHomepage] uses this to switch to the right tab after pop.
  final void Function(String tab)? onNavigateToTab;

  const AdminAccountDashboard({super.key, this.onNavigateToTab});

  @override
  State<AdminAccountDashboard> createState() => _AdminAccountDashboardState();
}

class _AdminAccountDashboardState extends State<AdminAccountDashboard> {
  static const _adminNavItems = [
    'Home',
    'Inventory',
    'Products',
    'Logs & History',
    'Account',
  ];

  String selectedMenu = "dashboard";
  String fullName = "";
  String email = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        fullName = doc.data()?['full_name'] ?? user.displayName ?? "Admin";
        email = doc.data()?['email'] ?? user.email ?? "";
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
              items: _adminNavItems,
              activeItem: "Account",
              onTap: (item) {
                if (item == "Account") return; // already here
                // Pop back to AdminHomepage and switch to the tapped tab
                Navigator.pop(context);
                widget.onNavigateToTab?.call(item);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSidebar(),
                    const SizedBox(width: 16),
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: AppTheme.glassCard(opacity: 0.18),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.person, size: 40, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            fullName.isNotEmpty ? fullName : "Loading...",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : "",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),
          _sidebarButton("Dashboard", selectedMenu == "dashboard", () {
            setState(() => selectedMenu = "dashboard");
          }),
          const SizedBox(height: 8),
          _sidebarButton("Manage Account", selectedMenu == "manage", () {
            setState(() => selectedMenu = "manage");
          }),
          const SizedBox(height: 8),
          _sidebarButton("User Role and Access", selectedMenu == "roles", () {
            setState(() => selectedMenu = "roles");
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("Logout"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarButton(String label, bool isActive, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive
              ? AppTheme.gold
              : Colors.white.withValues(alpha: 0.12),
          foregroundColor: isActive ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassCard(opacity: 0.15),
      child: _getContentWidget(),
    );
  }

  Widget _getContentWidget() {
    switch (selectedMenu) {
      case "dashboard":
        return const _AdminDashboardContent();
      case "manage":
        return AdminManageAccount(
          onNameUpdated: (newName) {
            setState(() => fullName = newName);
          },
        );
      case "roles":
        return const UserRoleAccessScreenEmbedded();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Admin Dashboard Content ───────────────────────────────────────────────────

class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent();

  static String _status(num current, num restock) {
    if (current <= 0)             return 'Out of Stock';
    if (current <= restock * 0.5) return 'Critical';
    if (current <= restock)       return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // ── Order stats ─────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Orders').snapshots(),
            builder: (_, snap) {
              int pending = 0, active = 0, ready = 0;
              for (final d in snap.data?.docs ?? []) {
                final s = (d.data() as Map)['status']?.toString() ?? '';
                if (s == 'pending')          pending++;
                if (s == 'in_production')    active++;
                if (s == 'ready_for_pickup') ready++;
              }
              final cards = [
                _DashCard('Pending',    pending, Icons.sync,                Colors.red),
                _DashCard('Production', active,  Icons.inventory_2_outlined, Colors.orange),
                _DashCard('Ready',      ready,   Icons.check_circle,         Colors.green),
              ];
              return LayoutBuilder(builder: (_, c) {
                if (c.maxWidth >= 400) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 8),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 8),
                        Expanded(child: cards[2]),
                      ],
                    ),
                  );
                }
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  cards[0], const SizedBox(height: 8),
                  cards[1], const SizedBox(height: 8),
                  cards[2],
                ]);
              });
            },
          ),

          const SizedBox(height: 24),

          // ── Stock replenishment ─────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('RawMaterials').snapshots(),
            builder: (_, snap) {
              final items = (snap.data?.docs ?? []).where((d) {
                final data = d.data() as Map<String, dynamic>;
                return _status(
                    (data['current_stock'] as num?) ?? 0,
                    (data['restock_level']  as num?) ?? 1) != 'In Stock';
              }).toList()
                ..sort((a, b) {
                  const ord = {'Out of Stock': 0, 'Critical': 1, 'Low Stock': 2};
                  final aD = a.data() as Map; final bD = b.data() as Map;
                  return (ord[_status((aD['current_stock'] as num?) ?? 0,
                              (aD['restock_level'] as num?) ?? 1)] ?? 3)
                      .compareTo(ord[_status((bD['current_stock'] as num?) ?? 0,
                              (bD['restock_level'] as num?) ?? 1)] ?? 3);
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Stock Replenishment',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _badge('${items.length} items', Colors.red),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    _okRow('All materials are sufficiently stocked')
                  else
                    ...items.take(6).map((d) {
                      final data    = d.data() as Map<String, dynamic>;
                      final name    = data['material_name']?.toString() ?? d.id;
                      final current = (data['current_stock'] as num?) ?? 0;
                      final restock = (data['restock_level']  as num?) ?? 1;
                      final unit    = data['unit_description']?.toString() ?? '';
                      final st      = _status(current, restock);
                      final color   = switch (st) {
                        'Out of Stock' => Colors.redAccent,
                        'Critical'     => const Color(0xFFFF6D00),
                        _              => Colors.amber,
                      };
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
                        child: Row(children: [
                          Container(width: 8, height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle, color: color)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                          Text('$current / $restock $unit',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          _badge(st, color),
                        ]),
                      );
                    }),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Unread reviews ──────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('OrderReviews').snapshots(),
            builder: (_, snap) {
              final unread = (snap.data?.docs ?? [])
                  .where((d) => (d.data() as Map)['read'] != true)
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
                  Row(children: [
                    const Text('Customer Reviews',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    if (unread.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _badge('${unread.length} unread', Colors.orange),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  if (unread.isEmpty)
                    _okRow('No unread reviews')
                  else
                    ...unread.take(5).map((d) {
                      final data     = d.data() as Map<String, dynamic>;
                      final customer = data['customer_name']?.toString() ?? '';
                      final product  = data['product_name']?.toString() ?? '';
                      final rating   = (data['rating'] as num?)?.toInt() ?? 0;
                      final message  = data['message']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: AppTheme.glassCard(opacity: 0.13, radius: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(customer,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600))),
                              Row(mainAxisSize: MainAxisSize.min,
                                  children: List.generate(5, (i) => Icon(
                                    i < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: i < rating
                                        ? AppTheme.gold
                                        : Colors.white24,
                                    size: 14))),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => FirebaseFirestore.instance
                                    .collection('OrderReviews')
                                    .doc(d.id)
                                    .update({'read': true}),
                                child: const Icon(Icons.check_circle_outline,
                                    color: Colors.white38, size: 16)),
                            ]),
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

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(text,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _okRow(String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: AppTheme.glassCard(opacity: 0.1),
    child: Row(children: [
      const Icon(Icons.check_circle_outline,
          color: Colors.greenAccent, size: 16),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(color: Colors.white54, fontSize: 13)),
    ]),
  );
}

class _DashCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _DashCard(this.label, this.count, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Container(
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
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    ),
  );
}
