import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_manage_users_screen.dart';
import 'admin_profile.dart';

// =============================================================================
class AdminAccountDashboard extends StatefulWidget {
  final void Function(String tab)? onNavigateToTab;
  const AdminAccountDashboard({super.key, this.onNavigateToTab});

  @override
  State<AdminAccountDashboard> createState() => _AdminAccountDashboardState();
}

class _AdminAccountDashboardState extends State<AdminAccountDashboard> {
  static const _adminNavItems = [
    'Home', 'Inventory', 'Products', 'Logs & History', 'Account',
  ];

  static const _menus = [
    ('dashboard', 'Dashboard',    Icons.dashboard_outlined),
    ('profile',   'Profile',      Icons.manage_accounts_outlined),
    ('roles',     'Manage Users', Icons.admin_panel_settings_outlined),
  ];

  String _selectedMenu = 'dashboard';
  String _fullName     = '';
  String _email        = '';
  String _uid          = '';
  String _adminId      = '';

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
        _email    = doc.data()?['email']     ?? user.email ?? '';
        _uid      = user.uid;
        _adminId  = doc.data()?['admin_id']  ?? '';
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 680;
                  return isWide
                      ? _wideLayout()
                      : _narrowLayout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide layout ─────────────────────────────────────────────────────────────

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: AppTheme.glassCard(opacity: 0.18),
            child: Column(
              children: [
                _buildAvatar(68, 36),
                const SizedBox(height: 10),
                Text(
                  _fullName.isNotEmpty ? _fullName : 'Admin',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (_adminId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      'ID: $_adminId',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10, letterSpacing: 0.5),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ..._menus.map((m) => _SidebarBtn(
                  label:    m.$2,
                  icon:     m.$3,
                  isActive: _selectedMenu == m.$1,
                  onTap:    () => setState(() => _selectedMenu = m.$1),
                )),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.logout, size: 15),
                    label: const Text('Logout', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content panel
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCard(opacity: 0.15),
              child: _contentWidget(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ────────────────────────────────────────────────────────────

  Widget _narrowLayout() {
    return Column(
      children: [
        Container(
          color: Colors.white.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildAvatar(38, 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _fullName.isNotEmpty ? _fullName : 'Admin',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_email.isNotEmpty)
                          Text(_email,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                        if (_adminId.isNotEmpty)
                          Text('ID: $_adminId',
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  letterSpacing: 0.4),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Logout',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _menus.map((m) {
                    final active = _selectedMenu == m.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedMenu = m.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.gold.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? AppTheme.gold.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.$3,
                                size: 14,
                                color: active ? AppTheme.gold : Colors.white60),
                            const SizedBox(width: 6),
                            Text(
                              m.$2,
                              style: TextStyle(
                                color: active ? AppTheme.gold : Colors.white70,
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassCard(opacity: 0.15),
              child: SingleChildScrollView(child: _contentWidget()),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _buildAvatar(double size, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Icon(Icons.person, size: iconSize, color: Colors.white70),
    );
  }

  Widget _contentWidget() {
    switch (_selectedMenu) {
      case 'profile':
        return AdminProfile(
          onNameUpdated: (n) => setState(() => _fullName = n),
        );
      case 'roles':
        return const ManageUsersScreen();
      default:
        return _AdminDashboardContent();
    }
  }
}

// ── Sidebar Button ─────────────────────────────────────────────────────────────

class _SidebarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarBtn({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive
                ? AppTheme.gold
                : Colors.white.withValues(alpha: 0.1),
            foregroundColor: isActive ? Colors.black : Colors.white,
            elevation: 0,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Dashboard Content
// =============================================================================
class _AdminDashboardContent extends StatelessWidget {
  const _AdminDashboardContent();

  static String _stockStatus(num current, num restock) {
    if (current <= 0) return 'Out of Stock';
    if (current <= restock * 0.5) return 'Critical';
    if (current <= restock) return 'Low Stock';
    return 'In Stock';
  }

  Color _stockColor(String s) {
    switch (s) {
      case 'In Stock':    return Colors.green;
      case 'Low Stock':   return Colors.orange;
      case 'Critical':    return Colors.redAccent;
      default:            return Colors.red;
    }
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
          const SizedBox(height: 16),

          // ── Order stats ─────────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Orders')
                .snapshots(),
            builder: (context, snap) {
              int pending = 0, active = 0, ready = 0;
              for (final d in snap.data?.docs ?? []) {
                final s = (d.data() as Map)['status']?.toString() ?? '';
                if (s == 'pending')       pending++;
                if (s == 'in_production') active++;
                if (s == 'ready')         ready++;
              }
              return LayoutBuilder(builder: (ctx, constraints) {
                final compact = constraints.maxWidth < 380;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _statCard('Pending\nOrders',    pending, Icons.sync,               Colors.red,    compact: compact)),
                      SizedBox(width: compact ? 4 : 8),
                      Expanded(child: _statCard('In\nProduction',     active,  Icons.inventory_2_outlined, Colors.orange, compact: compact)),
                      SizedBox(width: compact ? 4 : 8),
                      Expanded(child: _statCard('Ready for\nPickup',  ready,   Icons.check_circle,         Colors.green,  compact: compact)),
                    ],
                  ),
                );
              });
            },
          ),

          const SizedBox(height: 24),

          // ── Stock replenishment ─────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('RawMaterials')
                .snapshots(),
            builder: (context, snap) {
              final lowMats = (snap.data?.docs ?? []).where((d) {
                final data    = d.data() as Map<String, dynamic>;
                final current = (data['current_stock'] as num?)?.toDouble() ?? 0;
                final restock = (data['restock_level']  as num?)?.toDouble() ?? 0;
                return _stockStatus(current, restock) != 'In Stock';
              }).toList()
                ..sort((a, b) {
                  const ord = {'Out of Stock': 0, 'Critical': 1, 'Low Stock': 2};
                  final aD = a.data() as Map;
                  final bD = b.data() as Map;
                  return (ord[_stockStatus((aD['current_stock'] as num?) ?? 0,
                      (aD['restock_level'] as num?) ?? 1)] ?? 3)
                      .compareTo(ord[_stockStatus((bD['current_stock'] as num?) ?? 0,
                      (bD['restock_level'] as num?) ?? 1)] ?? 3);
                });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Needs Replenishment',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (lowMats.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${lowMats.length}',
                              style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (lowMats.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AppTheme.glassCard(opacity: 0.1),
                      child: const Row(children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Text('All materials are adequately stocked',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ]),
                    )
                  else
                    ...lowMats.take(6).map((doc) {
                      final d       = doc.data() as Map<String, dynamic>;
                      final name    = d['material_name']?.toString() ?? doc.id;
                      final unit    = d['unit_description']?.toString() ?? '';
                      final current = (d['current_stock'] as num?)?.toDouble() ?? 0;
                      final restock = (d['restock_level']  as num?)?.toDouble() ?? 1;
                      final st      = _stockStatus(current, restock);
                      final color   = _stockColor(st);
                      final pct     = restock > 0
                          ? (current / restock).clamp(0.0, 1.0)
                          : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: color, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: color.withValues(alpha: 0.4)),
                                ),
                                child: Text(st,
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            Row(children: [
                              Text(
                                '${current % 1 == 0 ? current.toInt() : current} / ${restock % 1 == 0 ? restock.toInt() : restock}${unit.isNotEmpty ? ' $unit' : ''}',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text('restock target',
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.35),
                                      fontSize: 10)),
                            ]),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                                valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Customer reviews ────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('OrderReviews')
                .snapshots(),
            builder: (context, snap) {
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
                  Row(
                    children: [
                      const Text('Customer Reviews',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (unread.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${unread.length}',
                              style: const TextStyle(
                                  color: Colors.black,
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
                      final data     = d.data() as Map<String, dynamic>;
                      final customer = data['customer_name']?.toString() ?? '';
                      final product  = data['product_name']?.toString()  ?? '';
                      final rating   = (data['rating'] as num?)?.toInt() ?? 0;
                      final message  = data['message']?.toString()       ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Avatar dot
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.gold.withValues(alpha: 0.15),
                                  ),
                                  child: const Icon(Icons.person_outline,
                                      color: AppTheme.gold, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(customer,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      _CustomerIdText(data: data),
                                    ],
                                  ),
                                ),
                                // Stars
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
                                GestureDetector(
                                  onTap: () => FirebaseFirestore.instance
                                      .collection('OrderReviews')
                                      .doc(d.id)
                                      .update({'read': true}),
                                  child: const Tooltip(
                                    message: 'Mark as read',
                                    child: Icon(Icons.check_circle_outline,
                                        color: Colors.white38, size: 17),
                                  ),
                                ),
                              ],
                            ),
                            if (product.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(product,
                                  style: const TextStyle(
                                      color: AppTheme.gold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500)),
                            ],
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(message,
                                  style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12.5,
                                      height: 1.5),
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

  Widget _statCard(String label, int count, IconData icon, Color color,
      {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: AppTheme.glassCard(opacity: 0.12, radius: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: compact ? 20 : 28),
          SizedBox(height: compact ? 6 : 10),
          Text('$count',
              style: TextStyle(
                  color: color,
                  fontSize: compact ? 20 : 26,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: compact ? 2 : 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: compact ? 10 : 12)),
        ],
      ),
    );
  }
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
                ?.toString() ?? '';
        if (cid.isEmpty) return const SizedBox.shrink();
        return _label(cid);
      },
    );
  }

  Widget _label(String id) => Text(
    'ID: $id',
    style: const TextStyle(
      color: Colors.white38,
      fontSize: 11,
      fontFamily: 'monospace',
    ),
  );
}