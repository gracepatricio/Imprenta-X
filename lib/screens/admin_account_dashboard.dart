import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_manage_users_screen.dart';
import 'admin_profile.dart';

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xF5FFFFFF);
  static const Color surfaceMid = Color(0xD8FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);

  static const Color borderTop = Color(0xF0FFFFFF);
  static const Color borderMid = Color(0x60FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xC0111827);
  static const Color textMuted = Color(0x80111827);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 24,
    spreadRadius: -2,
    offset: Offset(0, 6),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  static const BoxShadow glowShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  );

  static BoxDecoration card({
    Color? color,
    double radius = 16,
    bool elevated = false,
  }) => BoxDecoration(
    color: color ?? surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderMid, width: 0.9),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  static BoxDecoration pill({Color? tint}) => BoxDecoration(
    color: tint != null ? tint.withValues(alpha: 0.13) : surfaceThin,
    borderRadius: BorderRadius.circular(99),
    border: Border.all(
      color: tint != null ? tint.withValues(alpha: 0.45) : borderMid,
      width: 0.8,
    ),
    boxShadow: [rowShadow],
  );
}

// =============================================================================
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

  String _selectedMenu = 'dashboard';
  String _fullName = '';
  String _email = '';
  String _uid = '';
  String _adminId = '';

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
        _fullName = doc.data()?['full_name'] ?? user.displayName ?? 'Admin';
        _email = doc.data()?['email'] ?? user.email ?? '';
        _uid = user.uid;
        _adminId = doc.data()?['admin_id'] ?? '';
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
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
              activeItem: 'Account',
              onTap: (item) {
                if (item == 'Account') return;
                Navigator.pop(context);
                widget.onNavigateToTab?.call(item);
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Sidebar(
                      fullName: _fullName,
                      email: _email,
                      uid: _uid,
                      adminId: _adminId,
                      selectedMenu: _selectedMenu,
                      onMenuTap: (key) => setState(() => _selectedMenu = key),
                      onLogout: _logout,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ContentPanel(
                        selectedMenu: _selectedMenu,
                        onNameUpdated: (n) => setState(() => _fullName = n),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sidebar
// =============================================================================
class _Sidebar extends StatelessWidget {
  final String fullName;
  final String email;
  final String uid;
  final String adminId;
  final String selectedMenu;
  final ValueChanged<String> onMenuTap;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.fullName,
    required this.email,
    required this.uid,
    required this.adminId,
    required this.selectedMenu,
    required this.onMenuTap,
    required this.onLogout,
  });

  // ── 'manage' key renamed to 'profile', label changed to 'Profile' ──────────
  static const _items = [
    ('dashboard', 'Dashboard', Icons.dashboard_rounded),
    ('profile', 'Profile', Icons.person_rounded),
    ('roles', 'Manage Users', Icons.admin_panel_settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
      decoration: BoxDecoration(
        color: _Glass.surfaceMid,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Glass.borderMid, width: 0.9),
        boxShadow: const [_Glass.glowShadow],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _Glass.surfaceThin,
              border: Border.all(color: _Glass.borderMid, width: 1.2),
              boxShadow: const [_Glass.elevatedShadow],
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 28,
              color: _Glass.textSecondary,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            fullName.isNotEmpty ? fullName : 'Loading…',
            style: const TextStyle(
              color: _Glass.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            email.isNotEmpty ? email : '',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 10.5),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (adminId.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _Glass.surfaceThin,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _Glass.borderMid),
              ),
              child: Text(
                'ID: $adminId',
                style: const TextStyle(
                  color: _Glass.textMuted,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 18),
          Divider(color: _Glass.borderMid, thickness: 0.8),
          const SizedBox(height: 10),

          // Nav items
          ..._items.map(
                (item) => _SidebarItem(
              label: item.$2,
              icon: item.$3,
              isActive: selectedMenu == item.$1,
              onTap: () => onMenuTap(item.$1),
            ),
          ),

          const Spacer(),

          // Logout
          GestureDetector(
            onTap: onLogout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.28),
                  width: 0.8,
                ),
                boxShadow: const [_Glass.rowShadow],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 14,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
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
        curve: Curves.easeInOut,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xEA1A1A2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isActive ? const Color(0x35FFFFFF) : Colors.transparent,
            width: 0.8,
          ),
          boxShadow: isActive ? const [_Glass.rowShadow] : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : _Glass.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Content Panel
// =============================================================================
class _ContentPanel extends StatelessWidget {
  final String selectedMenu;
  final ValueChanged<String> onNameUpdated;

  const _ContentPanel({
    required this.selectedMenu,
    required this.onNameUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: double.infinity),
      decoration: BoxDecoration(
        color: _Glass.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Glass.borderMid, width: 0.9),
        boxShadow: const [_Glass.glowShadow],
      ),
      padding: const EdgeInsets.all(22),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (selectedMenu) {
      case 'dashboard':
        return const _AdminDashboardContent();
      case 'profile':
      // ── updated key + widget name ──────────────────────────────
        return AdminProfile(onNameUpdated: onNameUpdated);
      case 'roles':
        return const ManageUsersScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}

// =============================================================================
// Dashboard Content
// =============================================================================
class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent();

  static String _status(num current, num restock) {
    if (current <= 0) return 'Out of Stock';
    if (current <= restock * 0.5) return 'Critical';
    if (current <= restock) return 'Low Stock';
    return 'In Stock';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'In Stock':
        return const Color(0xFF2E7D32);
      case 'Low Stock':
        return const Color(0xFFF57F17);
      case 'Critical':
        return const Color(0xFFBF360C);
      default:
        return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page title
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _Glass.surfaceThin,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _Glass.borderMid, width: 0.8),
                  boxShadow: const [_Glass.rowShadow],
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  size: 16,
                  color: _Glass.textSecondary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Order overview ──────────────────────────────────────────────
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
                  const _SectionLabel(
                    label: 'Order Overview',
                    icon: Icons.receipt_long_rounded,
                  ),
                  const SizedBox(height: 10),

                  LayoutBuilder(
                    builder: (_, c) {
                      final cards = [
                        _DashCard(
                          'Pending',
                          pending,
                          Icons.sync_rounded,
                          const Color(0xFFBF360C),
                        ),
                        _DashCard(
                          'In Production',
                          active,
                          Icons.inventory_2_rounded,
                          const Color(0xFFF57F17),
                        ),
                        _DashCard(
                          'Ready for Pickup',
                          ready,
                          Icons.check_circle_rounded,
                          const Color(0xFF2E7D32),
                        ),
                      ];

                      if (c.maxWidth >= 480) {
                        return IntrinsicHeight(
                          child: Row(
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
                      if (c.maxWidth >= 280) {
                        return Column(
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  Expanded(child: cards[0]),
                                  const SizedBox(width: 10),
                                  Expanded(child: cards[1]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            cards[2],
                          ],
                        );
                      }
                      return Column(
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

          const SizedBox(height: 22),

          // ── Stock replenishment ─────────────────────────────────────────
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
                padding: const EdgeInsets.all(18),
                decoration: _Glass.card(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _SectionLabel(
                          label: 'Stock Replenishment',
                          icon: Icons.inventory_rounded,
                        ),
                        if (items.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _StatusPill(
                            '${items.length} need attention',
                            const Color(0xFFC62828),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
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
                        final color = _statusColor(st);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: color.withValues(alpha: 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
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
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$current / $restock $unit',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              _StatusPill(st, color),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // ── Customer reviews ────────────────────────────────────────────
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
                padding: const EdgeInsets.all(18),
                decoration: _Glass.card(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _SectionLabel(
                          label: 'Customer Reviews',
                          icon: Icons.star_rounded,
                        ),
                        if (unread.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          _StatusPill(
                            '${unread.length} unread',
                            const Color(0xFFF57F17),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
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
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _Glass.surfaceThin,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _Glass.borderMid,
                              width: 0.8,
                            ),
                            boxShadow: const [_Glass.rowShadow],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer,
                                          style: const TextStyle(
                                            color: _Glass.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        _CustomerIdText(data: data),
                                      ],
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
                                            : _Glass.textMuted,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => FirebaseFirestore.instance
                                        .collection('OrderReviews')
                                        .doc(d.id)
                                        .update({'read': true}),
                                    child: const Tooltip(
                                      message: 'Mark as read',
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        color: _Glass.textMuted,
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (product.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  product,
                                  style: TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 7),
                                Text(
                                  message,
                                  style: const TextStyle(
                                    color: _Glass.textSecondary,
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

// =============================================================================
// Reusable dashboard widgets
// =============================================================================
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: _Glass.textSecondary, size: 14),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          color: _Glass.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ],
  );
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: color.withValues(alpha: 0.38), width: 0.8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
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
      color: const Color(0xFF2E7D32).withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.22),
        width: 0.8,
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: Color(0xFF2E7D32),
          size: 15,
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(color: _Glass.textSecondary, fontSize: 13),
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
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      boxShadow: const [_Glass.rowShadow],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: _Glass.pill(tint: color),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ],
    ),
  );
}

/// Resolves a customer_uid to a CUS-XXX id via the User collection.
class _CustomerIdText extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CustomerIdText({required this.data});

  @override
  Widget build(BuildContext context) {
    final stored = data['customer_id']?.toString() ?? '';
    if (stored.isNotEmpty) return _label(stored);

    final uid = data['customer_uid']?.toString() ?? '';
    if (uid.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('User').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final cid =
            (snap.data?.data() as Map<String, dynamic>?)?['customer_id']
                ?.toString() ??
                '';
        if (cid.isEmpty) return const SizedBox.shrink();
        return _label(cid);
      },
    );
  }

  Widget _label(String id) => Text(
    'ID: $id',
    style: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 11,
      fontFamily: 'monospace',
    ),
  );
}