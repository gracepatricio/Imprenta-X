import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_manage_users_screen.dart';
import 'admin_profile.dart';

// =============================================================================
// Design Tokens — Vibrant Glass
// =============================================================================
class _G {
  static const Color navyBlue = Color(0xFF0F1A2E);

  static const Color surface = Color(0xF8FFFFFF);
  static const Color surfaceMid = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);
  static const Color surfaceXThin = Color(0x60FFFFFF);

  static const Color borderTop = Color(0xE0FFFFFF);
  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted = Color(0x880F172A);

  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFEF4444);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x22000000),
    blurRadius: 32,
    spreadRadius: -4,
    offset: Offset(0, 8),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static BoxDecoration card({
    Color? color,
    double radius = 18,
    bool elevated = false,
    Color? tintBorder,
  }) => BoxDecoration(
    color: color ?? surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: tintBorder ?? borderMid, width: 1.0),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  static BoxDecoration pill({Color? tint}) => BoxDecoration(
    color: tint != null ? tint.withValues(alpha: 0.15) : surfaceThin,
    borderRadius: BorderRadius.circular(99),
    border: Border.all(
      color: tint != null ? tint.withValues(alpha: 0.50) : borderMid,
      width: 0.9,
    ),
  );
}

// Blur wrapper
class _BlurCard extends StatelessWidget {
  final Widget child;
  final BoxDecoration decoration;
  final EdgeInsetsGeometry? padding;

  const _BlurCard({
    required this.child,
    required this.decoration,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          (decoration.borderRadius as BorderRadius?) ??
          BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: decoration,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
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

  static const _menus = [
    ('dashboard', 'Dashboard', Icons.dashboard_rounded),
    ('profile', 'Profile', Icons.manage_accounts_rounded),
    ('roles', 'Manage Users', Icons.admin_panel_settings_rounded),
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
    if (context.mounted)
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
decoration: AppTheme.backgroundDecoration(context),
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
                  final isWide = constraints.maxWidth >= 700;
                  return isWide ? _wideLayout() : _narrowLayout(constraints);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide layout ────────────────────────────────────────────────────────────
  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: _BlurCard(
              decoration: _G.card(
                color: _G.surfaceMid,
                radius: 22,
                elevated: true,
              ),
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
              child: Column(
                children: [
                  _buildAvatarSection(72, 38),
                  const SizedBox(height: 20),
                  ..._menus.map(
                    (m) => _SidebarBtn(
                      label: m.$2,
                      icon: m.$3,
                      isActive: _selectedMenu == m.$1,
                      onTap: () => setState(() => _selectedMenu = m.$1),
                    ),
                  ),
                  const Spacer(),
                  _LogoutButton(onLogout: _logout),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _BlurCard(
              decoration: _G.card(
                color: _G.surfaceMid,
                radius: 22,
                elevated: true,
              ),
              padding: const EdgeInsets.all(28),
              child: _contentWidget(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ──────────────────────────────────────────────────────────
  Widget _narrowLayout(BoxConstraints constraints) {
    // ManageUsersScreen uses Expanded internally so it needs a direct
    // bounded parent — NOT wrapped in SingleChildScrollView.
    final isManageUsers = _selectedMenu == 'roles';

    return SizedBox(
      height: constraints.maxHeight,
      child: Column(
        children: [
          // ── Header card ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: _G.surfaceMid,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _G.borderMid, width: 0.9),
                    boxShadow: const [_G.rowShadow],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar row
                          Row(
                            children: [
                              _buildAvatar(40, 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fullName.isNotEmpty
                                          ? _fullName
                                          : 'Admin',
                                      style: const TextStyle(
                                        color: _G.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (_email.isNotEmpty)
                                      Text(
                                        _email,
                                        style: const TextStyle(
                                          color: _G.textSecondary,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (_adminId.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _G.navyBlue.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          border: Border.all(
                                            color: _G.navyBlue.withValues(
                                              alpha: 0.25,
                                            ),
                                            width: 0.9,
                                          ),
                                        ),
                                        child: Text(
                                          'ID: $_adminId',
                                          style: const TextStyle(
                                            color: _G.navyBlue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Logout pill
                              GestureDetector(
                                onTap: _logout,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _G.accentRose,
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _G.accentRose.withValues(
                                          alpha: 0.30,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.logout_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 5),
                                      Text(
                                        'Logout',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Tab chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _menus.map((m) {
                                final active = _selectedMenu == m.$1;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedMenu = m.$1),
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      right: 10,
                                      bottom: 14,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: active
                                        ? BoxDecoration(
                                            color: _G.navyBlue,
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _G.navyBlue.withValues(
                                                  alpha: 0.28,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          )
                                        : _G.pill(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          m.$3,
                                          size: 13,
                                          color: active
                                              ? Colors.white
                                              : _G.textMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          m.$2,
                                          style: TextStyle(
                                            color: active
                                                ? Colors.white
                                                : _G.textSecondary,
                                            fontSize: 11.5,
                                            fontWeight: active
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content area ────────────────────────────────────────
          // KEY FIX: ManageUsersScreen needs a direct bounded height
          // (via Expanded), NOT a SingleChildScrollView parent.
          // Dashboard and Profile use SingleChildScrollView normally.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: _BlurCard(
                decoration: _G.card(
                  color: _G.surfaceMid,
                  radius: 20,
                  elevated: true,
                ),
                padding: const EdgeInsets.all(16),
                child: isManageUsers
                    ? _contentWidget()
                    : SingleChildScrollView(child: _contentWidget()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar section (wide sidebar) ─────────────────────────────────────────
  Widget _buildAvatarSection(double size, double iconSize) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _G.navyBlue.withValues(alpha: 0.12),
            border: Border.all(
              color: _G.navyBlue.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: const [_G.rowShadow],
          ),
          child: Icon(Icons.person_rounded, size: iconSize, color: _G.navyBlue),
        ),
        const SizedBox(height: 10),
        Text(
          _fullName.isNotEmpty ? _fullName : 'Admin',
          style: const TextStyle(
            color: _G.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (_email.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            _email,
            style: const TextStyle(color: _G.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (_adminId.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _G.navyBlue.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: _G.navyBlue.withValues(alpha: 0.25),
                width: 0.9,
              ),
            ),
            child: Text(
              'ID: $_adminId',
              style: const TextStyle(
                color: _G.navyBlue,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatar(double size, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _G.navyBlue.withValues(alpha: 0.12),
        border: Border.all(
          color: _G.navyBlue.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Icon(Icons.person_rounded, size: iconSize, color: _G.navyBlue),
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
        return const _AdminDashboardContent();
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
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          decoration: isActive
              ? BoxDecoration(
                  color: _G.navyBlue,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: _G.navyBlue.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: _G.surfaceThin,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _G.borderMid, width: 0.9),
                ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : _G.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : _G.textSecondary,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onLogout,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          decoration: BoxDecoration(
            color: _G.accentRose,
            borderRadius: BorderRadius.circular(99),
            boxShadow: [
              BoxShadow(
                color: _G.accentRose.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.logout_rounded, size: 15, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
      case 'In Stock':
        return _G.accentEmerald;
      case 'Low Stock':
        return _G.accentAmber;
      case 'Critical':
        return _G.accentRose;
      default:
        return _G.accentRose;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              color: _G.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),

          _SectionLabel(label: 'ORDER STATUS'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Orders').snapshots(),
            builder: (context, snap) {
              int pending = 0, active = 0, ready = 0;
              for (final d in snap.data?.docs ?? []) {
                final s = (d.data() as Map)['status']?.toString() ?? '';
                if (s == 'pending') pending++;
                if (s == 'in_production') active++;
                if (s == 'ready') ready++;
              }
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  final compact = constraints.maxWidth < 360;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Pending\nOrders',
                            count: pending,
                            icon: Icons.sync_rounded,
                            color: _G.accentRose,
                            compact: compact,
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 10),
                        Expanded(
                          child: _StatCard(
                            label: 'In\nProduction',
                            count: active,
                            icon: Icons.precision_manufacturing_rounded,
                            color: _G.accentAmber,
                            compact: compact,
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Ready for\nPickup',
                            count: ready,
                            icon: Icons.check_circle_rounded,
                            color: _G.accentEmerald,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 28),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('RawMaterials')
                .snapshots(),
            builder: (context, snap) {
              final lowMats =
                  (snap.data?.docs ?? []).where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final current =
                        (data['current_stock'] as num?)?.toDouble() ?? 0;
                    final restock =
                        (data['restock_level'] as num?)?.toDouble() ?? 0;
                    return _stockStatus(current, restock) != 'In Stock';
                  }).toList()..sort((a, b) {
                    const ord = {
                      'Out of Stock': 0,
                      'Critical': 1,
                      'Low Stock': 2,
                    };
                    final aD = a.data() as Map;
                    final bD = b.data() as Map;
                    return (ord[_stockStatus(
                              (aD['current_stock'] as num?) ?? 0,
                              (aD['restock_level'] as num?) ?? 1,
                            )] ??
                            3)
                        .compareTo(
                          ord[_stockStatus(
                                (bD['current_stock'] as num?) ?? 0,
                                (bD['restock_level'] as num?) ?? 1,
                              )] ??
                              3,
                        );
                  });

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Needs Replenishment',
                        style: TextStyle(
                          color: _G.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (lowMats.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: _G.pill(tint: _G.accentAmber),
                          child: Text(
                            '${lowMats.length}',
                            style: const TextStyle(
                              color: _G.accentAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (lowMats.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _G.card(
                        radius: 14,
                        tintBorder: _G.accentEmerald.withValues(alpha: 0.30),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _G.accentEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: _G.accentEmerald,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'All materials are adequately stocked',
                            style: TextStyle(
                              color: _G.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...lowMats.take(6).map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final name = d['material_name']?.toString() ?? doc.id;
                      final unit = d['unit_description']?.toString() ?? '';
                      final current =
                          (d['current_stock'] as num?)?.toDouble() ?? 0;
                      final restock =
                          (d['restock_level'] as num?)?.toDouble() ?? 1;
                      final st = _stockStatus(current, restock);
                      final color = _stockColor(st);
                      final pct = restock > 0
                          ? (current / restock).clamp(0.0, 1.0)
                          : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: _G.card(
                          radius: 14,
                          tintBorder: color.withValues(alpha: 0.20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: color,
                                    size: 13,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: _G.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.35),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: Text(
                                    st,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${current % 1 == 0 ? current.toInt() : current} / ${restock % 1 == 0 ? restock.toInt() : restock}${unit.isNotEmpty ? ' $unit' : ''}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'restock target',
                                  style: TextStyle(
                                    color: _G.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: color.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                                minHeight: 5,
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

          const SizedBox(height: 28),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('OrderReviews')
                .snapshots(),
            builder: (context, snap) {
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Customer Reviews',
                        style: TextStyle(
                          color: _G.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (unread.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: _G.pill(tint: _G.accentViolet),
                          child: Text(
                            '${unread.length}',
                            style: const TextStyle(
                              color: _G.accentViolet,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (unread.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _G.card(radius: 14),
                      child: const Center(
                        child: Text(
                          'No unread reviews',
                          style: TextStyle(color: _G.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...unread.take(5).map((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final customer = data['customer_name']?.toString() ?? '';
                      final product = data['product_name']?.toString() ?? '';
                      final rating = (data['rating'] as num?)?.toInt() ?? 0;
                      final message = data['message']?.toString() ?? '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: _G.card(radius: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _G.navyBlue.withValues(alpha: 0.10),
                                    border: Border.all(
                                      color: _G.navyBlue.withValues(
                                        alpha: 0.20,
                                      ),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: _G.navyBlue,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer,
                                        style: const TextStyle(
                                          color: _G.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                          ? _G.accentAmber
                                          : const Color(0x30000000),
                                      size: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // FIX: Removed Tooltip wrapper —
                                // it uses SingleTickerProviderStateMixin
                                // and caused infinite ticker errors
                                // when rebuilt inside PopupMenu lists.
                                GestureDetector(
                                  onTap: () => FirebaseFirestore.instance
                                      .collection('OrderReviews')
                                      .doc(d.id)
                                      .update({'read': true}),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _G.accentEmerald.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      color: _G.accentEmerald,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (product.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: _G.pill(tint: _G.accentAmber),
                                child: Text(
                                  product,
                                  style: const TextStyle(
                                    color: _G.accentAmber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: _G.textSecondary,
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
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool compact;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: _G.surfaceMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1.0),
        boxShadow: const [_G.rowShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: compact ? 18 : 22),
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: compact ? 22 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            label,
            style: TextStyle(
              color: _G.textMuted,
              fontSize: compact ? 10.5 : 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _G.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ── Customer ID Text ──────────────────────────────────────────────────────────
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
      color: _G.textMuted,
      fontSize: 11,
      fontFamily: 'monospace',
    ),
  );
}
