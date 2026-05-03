import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'user_role_access_screen.dart';
import 'admin_manage_account.dart';

class AdminAccountDashboard extends StatefulWidget {
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
                if (item == "Account") return;
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
      width: 210,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              size: 36,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            fullName.isNotEmpty ? fullName : "Loading...",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            email.isNotEmpty ? email : "",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 28),
          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.1), thickness: 1),
          const SizedBox(height: 16),
          _sidebarButton("Dashboard", "dashboard", Icons.dashboard_rounded),
          const SizedBox(height: 8),
          _sidebarButton(
            "Manage Account",
            "manage",
            Icons.manage_accounts_rounded,
          ),
          const SizedBox(height: 8),
          _sidebarButton(
            "User Role & Access",
            "roles",
            Icons.admin_panel_settings_rounded,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700.withValues(alpha: 0.85),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text(
                "Logout",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarButton(String label, String menuKey, IconData icon) {
    final isActive = selectedMenu == menuKey;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => selectedMenu = menuKey),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.gold.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppTheme.gold.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isActive
                      ? AppTheme.gold
                      : Colors.white.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? AppTheme.gold
                        : Colors.white.withValues(alpha: 0.88),
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
    if (current <= 0) return 'Out of Stock';
    if (current <= restock * 0.5) return 'Critical';
    if (current <= restock) return 'Low Stock';
    return 'In Stock';
  }

  // Consistent glass card decoration used throughout the dashboard
  static BoxDecoration _glassSection({
    double opacity = 0.20,
    double radius = 14,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page Title ────────────────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Order Stats ──────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Orders').snapshots(),
            builder: (_, snap) {
              int pending = 0, active = 0, ready = 0;
              for (final d in snap.data?.docs ?? []) {
                final s = (d.data() as Map)['status']?.toString() ?? '';
                if (s == 'pending') pending++;
                if (s == 'in_production') active++;
                if (s == 'ready_for_pickup') ready++;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(
                    label: 'Order Overview',
                    icon: Icons.receipt_long_rounded,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (_, c) {
                      final cards = [
                        _DashCard(
                          'Pending',
                          pending,
                          Icons.sync_rounded,
                          const Color.fromARGB(255, 204, 53, 53),
                        ),
                        _DashCard(
                          'In Production',
                          active,
                          Icons.inventory_2_rounded,
                          Colors.orange,
                        ),
                        _DashCard(
                          'Ready for Pickup',
                          ready,
                          Icons.check_circle_rounded,
                          Colors.greenAccent.shade400,
                        ),
                      ];
                      if (c.maxWidth >= 400) {
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
                    },
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Stock Replenishment ──────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('RawMaterials')
                .snapshots(),
            builder: (_, snap) {
              final items =
                  (snap.data?.docs ?? []).where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return _status(
                          (data['current_stock'] as num?) ?? 0,
                          (data['restock_level'] as num?) ?? 1,
                        ) !=
                        'In Stock';
                  }).toList()..sort((a, b) {
                    const ord = {
                      'Out of Stock': 0,
                      'Critical': 1,
                      'Low Stock': 2,
                    };
                    final aD = a.data() as Map;
                    final bD = b.data() as Map;
                    return (ord[_status(
                              (aD['current_stock'] as num?) ?? 0,
                              (aD['restock_level'] as num?) ?? 1,
                            )] ??
                            3)
                        .compareTo(
                          ord[_status(
                                (bD['current_stock'] as num?) ?? 0,
                                (bD['restock_level'] as num?) ?? 1,
                              )] ??
                              3,
                        );
                  });

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _glassSection(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SectionLabel(
                          label: 'Stock Replenishment',
                          icon: Icons.inventory_rounded,
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _StatusBadge(
                            '${items.length} items need attention',
                            const Color.fromARGB(255, 204, 53, 53),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      _OkRow('All materials are sufficiently stocked')
                    else
                      ...items.take(6).map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final name = data['material_name']?.toString() ?? d.id;
                        final current = (data['current_stock'] as num?) ?? 0;
                        final restock = (data['restock_level'] as num?) ?? 1;
                        final unit = data['unit_description']?.toString() ?? '';
                        final st = _status(current, restock);
                        final color = switch (st) {
                          'Out of Stock' => const Color.fromARGB(
                            255,
                            204,
                            53,
                            53,
                          ),
                          'Critical' => const Color(0xFFFF6D00),
                          _ => Colors.amber,
                        };
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '$current / $restock $unit',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StatusBadge(st, color),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Customer Reviews ─────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('OrderReviews')
                .snapshots(),
            builder: (_, snap) {
              final unread =
                  (snap.data?.docs ?? [])
                      .where((d) => (d.data() as Map)['read'] != true)
                      .toList()
                    ..sort((a, b) {
                      final at = (a.data() as Map)['created_at'];
                      final bt = (b.data() as Map)['created_at'];
                      if (at == null || bt == null) return 0;
                      return (bt as dynamic).compareTo(at);
                    });

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: _glassSection(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SectionLabel(
                          label: 'Customer Reviews',
                          icon: Icons.star_rounded,
                        ),
                        if (unread.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _StatusBadge(
                            '${unread.length} unread',
                            Colors.orange,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (unread.isEmpty)
                      _OkRow('No unread reviews')
                    else
                      ...unread.take(5).map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final customer =
                            data['customer_name']?.toString() ?? '';
                        final product = data['product_name']?.toString() ?? '';
                        final rating = (data['rating'] as num?)?.toInt() ?? 0;
                        final message = data['message']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      customer,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                            : Colors.white.withValues(
                                                alpha: 0.35,
                                              ),
                                        size: 15,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => FirebaseFirestore.instance
                                        .collection('OrderReviews')
                                        .doc(d.id)
                                        .update({'read': true}),
                                    child: Tooltip(
                                      message: 'Mark as read',
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (product.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  product,
                                  style: const TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12.5,
                                    height: 1.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white.withValues(alpha: 0.75), size: 15),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusBadge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _OkRow extends StatelessWidget {
  final String text;
  const _OkRow(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.greenAccent.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.20)),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Colors.greenAccent,
          size: 16,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 13,
          ),
        ),
      ],
    ),
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
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    ),
  );
}
