import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'chat_screen.dart';
import 'employee_profile.dart'; // ← added import
import '../services/auth_service.dart';

// =============================================================================
// Design Tokens — matches AdminAccountDashboard _G system
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

// =============================================================================
// Blur Card wrapper
// =============================================================================
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
// EmployeeAccountScreen
// =============================================================================
class EmployeeAccountScreen extends StatefulWidget {
  /// tab: 0 = Job Queue Pending, 1 = Job Queue Active, 2 = Ready for Pickup
  final void Function(int tab)? onNavigateToLogs;
  const EmployeeAccountScreen({super.key, this.onNavigateToLogs});

  @override
  State<EmployeeAccountScreen> createState() => _EmployeeAccountScreenState();
}

class _EmployeeAccountScreenState extends State<EmployeeAccountScreen> {
  String selectedMenu = 'dashboard';
  String fullName = '';
  String email = '';
  String employeeId = '';

  static const _menus = [
    ('dashboard', 'Dashboard', Icons.dashboard_rounded),
    ('messages', 'Messages', Icons.chat_bubble_rounded),
    ('manage', 'Profile', Icons.manage_accounts_rounded),
  ];

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
        fullName = doc.data()?['full_name'] ?? user.displayName ?? 'Employee';
        email = doc.data()?['email'] ?? user.email ?? '';
        employeeId = doc.data()?['employee_id'] ?? '';
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return isWide ? _wideLayout() : _narrowLayout(constraints);
      },
    );
  }

  // ── Wide layout ────────────────────────────────────────────────────────────
  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
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
                      isActive: selectedMenu == m.$1,
                      onTap: () => setState(() => selectedMenu = m.$1),
                    ),
                  ),
                  const Spacer(),
                  _LogoutButton(onLogout: _logout),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Content
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
    final isMessages = selectedMenu == 'messages';

    return SizedBox(
      height: constraints.maxHeight,
      child: Column(
        children: [
          // Header card
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
                                      fullName.isNotEmpty
                                          ? fullName
                                          : 'Employee',
                                      style: const TextStyle(
                                        color: _G.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (email.isNotEmpty)
                                      Text(
                                        email,
                                        style: const TextStyle(
                                          color: _G.textSecondary,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (employeeId.isNotEmpty) ...[
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
                                          'ID: $employeeId',
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
                                final active = selectedMenu == m.$1;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => selectedMenu = m.$1),
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

          // Content area
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
                child: isMessages
                    ? _contentWidget()
                    : SingleChildScrollView(child: _contentWidget()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar section (wide sidebar) ──────────────────────────────────────────
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
          fullName.isNotEmpty ? fullName : 'Employee',
          style: const TextStyle(
            color: _G.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            email,
            style: const TextStyle(color: _G.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (employeeId.isNotEmpty) ...[
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
              'ID: $employeeId',
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
    switch (selectedMenu) {
      case 'messages':
        return const _EmployeeMessagesContent();
      case 'manage':
        return _EmployeeManageAccountContent(
          onNameUpdated: (n) => setState(() => fullName = n),
        );
      default:
        return _EmployeeDashboardContent(
          onNavigateToLogs: widget.onNavigateToLogs,
          onNavigateToMessages: () => setState(() => selectedMenu = 'messages'),
        );
    }
  }
}

// =============================================================================
// Sidebar Button
// =============================================================================
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

// =============================================================================
// Logout Button
// =============================================================================
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
class _EmployeeDashboardContent extends StatelessWidget {
  final void Function(int tab)? onNavigateToLogs;
  final VoidCallback? onNavigateToMessages;

  const _EmployeeDashboardContent({
    this.onNavigateToLogs,
    this.onNavigateToMessages,
  });

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

          // ── Order Status ─────────────────────────────────────────────────
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
                            onTap: () => onNavigateToLogs?.call(0),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 10),
                        Expanded(
                          child: _StatCard(
                            label: 'Active\nOrders',
                            count: active,
                            icon: Icons.inventory_2_rounded,
                            color: _G.accentAmber,
                            compact: compact,
                            onTap: () => onNavigateToLogs?.call(1),
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
                            onTap: () => onNavigateToLogs?.call(2),
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

          // ── Needs Replenishment ──────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('RawMaterials')
                .snapshots(),
            builder: (context, snap) {
              final allMats = snap.data?.docs ?? [];
              final lowMats = allMats.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final current =
                    (data['current_stock'] as num?)?.toDouble() ?? 0;
                final restock =
                    (data['restock_level'] as num?)?.toDouble() ?? 0;
                return current <= restock;
              }).toList();

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
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData)
                    const Center(
                      child: CircularProgressIndicator(color: _G.navyBlue),
                    )
                  else if (lowMats.isEmpty)
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
                    ...lowMats.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final name = d['material_name']?.toString() ?? doc.id;
                      final unit = d['unit_description']?.toString() ?? '';
                      final current =
                          (d['current_stock'] as num?)?.toDouble() ?? 0;
                      final restock =
                          (d['restock_level'] as num?)?.toDouble() ?? 0;
                      final isCritical = current <= restock * 0.5;
                      final statusColor = isCritical
                          ? _G.accentRose
                          : _G.accentAmber;
                      final statusLabel = isCritical ? 'Critical' : 'Low Stock';
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
                          tintBorder: statusColor.withValues(alpha: 0.20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.warning_amber_rounded,
                                    color: statusColor,
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
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: statusColor.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 0.9,
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
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
                                    color: statusColor,
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
                                backgroundColor: statusColor.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  statusColor,
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

          // ── Unread Messages ──────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Messages')
                .snapshots(),
            builder: (context, snap) {
              final allDocs = snap.data?.docs ?? [];
              final unreadDocs = allDocs.where((d) {
                final u = ((d.data() as Map)['unread_employee'] as num?) ?? 0;
                return u > 0;
              }).toList();
              final totalUnread = unreadDocs.fold<int>(
                0,
                (sum, d) =>
                    sum +
                    (((d.data() as Map)['unread_employee'] as num?) ?? 0)
                        .toInt(),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: unreadDocs.isNotEmpty ? onNavigateToMessages : null,
                    child: Row(
                      children: [
                        const Text(
                          'Unread Messages',
                          style: TextStyle(
                            color: _G.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (totalUnread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: _G.pill(tint: _G.accentRose),
                            child: Text(
                              '$totalUnread',
                              style: const TextStyle(
                                color: _G.accentRose,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: _G.textMuted,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (unreadDocs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: _G.card(radius: 14),
                      child: const Center(
                        child: Text(
                          'No unread messages',
                          style: TextStyle(color: _G.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...unreadDocs.take(3).map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final customerUid = d['customer_uid']?.toString() ?? '';
                      final customerName =
                          d['customer_name']?.toString() ?? 'Customer';
                      final lastMsg = d['last_message']?.toString() ?? '';
                      final unread = ((d['unread_employee'] as num?) ?? 0)
                          .toInt();

                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              customerUid: customerUid,
                              customerName: customerName,
                              isEmployee: true,
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: _G.card(radius: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _G.navyBlue.withValues(alpha: 0.10),
                                  border: Border.all(
                                    color: _G.navyBlue.withValues(alpha: 0.20),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customerName,
                                      style: const TextStyle(
                                        color: _G.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (lastMsg.isNotEmpty)
                                      Text(
                                        lastMsg,
                                        style: const TextStyle(
                                          color: _G.textMuted,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _G.accentRose,
                                ),
                                child: Center(
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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

// =============================================================================
// Stat Card
// =============================================================================
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool compact;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            if (onTap != null) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: _G.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Section Label
// =============================================================================
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

// =============================================================================
// Employee Messages Content
// =============================================================================
class _EmployeeMessagesContent extends StatefulWidget {
  const _EmployeeMessagesContent();

  @override
  State<_EmployeeMessagesContent> createState() =>
      _EmployeeMessagesContentState();
}

class _EmployeeMessagesContentState extends State<_EmployeeMessagesContent> {
  String? _selectedUid;
  String _selectedName = '';

  Widget _buildList(BuildContext context, {required bool splitMode}) {
    return Padding(
      // Give the list breathing room from the divider on split mode
      padding: splitMode ? const EdgeInsets.only(right: 14) : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 4),
            child: Text(
              'Messages',
              style: TextStyle(
                color: _G.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            'Customer conversations',
            style: TextStyle(color: _G.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Messages')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _G.navyBlue),
                  );
                }
                final docs = List.from(snap.data?.docs ?? [])
                  ..sort((a, b) {
                    final at = (a.data() as Map)['last_updated'];
                    final bt = (b.data() as Map)['last_updated'];
                    if (at == null || bt == null) return 0;
                    return (bt as dynamic).compareTo(at);
                  });
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _G.navyBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 36,
                            color: _G.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No customer messages yet',
                          style: TextStyle(color: _G.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final lastMsg = d['last_message']?.toString() ?? '';
                    final unread = ((d['unread_employee'] as num?) ?? 0)
                        .toInt();
                    final customerName =
                        d['customer_name']?.toString() ?? 'Customer';
                    final customerUid = d['customer_uid']?.toString() ?? '';
                    final isSelected = splitMode && _selectedUid == customerUid;

                    return GestureDetector(
                      onTap: () {
                        if (splitMode) {
                          setState(() {
                            _selectedUid = customerUid;
                            _selectedName = customerName;
                          });
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                customerUid: customerUid,
                                customerName: customerName,
                                isEmployee: true,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _G.navyBlue.withValues(alpha: 0.08)
                              : _G.surfaceMid,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _G.navyBlue.withValues(alpha: 0.30)
                                : _G.borderMid,
                            width: isSelected ? 1.5 : 0.9,
                          ),
                          boxShadow: const [_G.rowShadow],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _G.navyBlue.withValues(alpha: 0.10),
                                border: isSelected
                                    ? Border.all(
                                        color: _G.navyBlue.withValues(
                                          alpha: 0.40,
                                        ),
                                        width: 1.5,
                                      )
                                    : Border.all(
                                        color: _G.navyBlue.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 0.9,
                                      ),
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: _G.navyBlue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customerName,
                                    style: TextStyle(
                                      color: isSelected
                                          ? _G.navyBlue
                                          : _G.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (lastMsg.isNotEmpty)
                                    Text(
                                      lastMsg,
                                      style: const TextStyle(
                                        color: _G.textMuted,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _G.accentRose,
                                ),
                                child: Center(
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ] else
                              const Icon(
                                Icons.chevron_right,
                                color: _G.textMuted,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 500) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ← widened from 230 → 290 so cards have comfortable room
              SizedBox(width: 290, child: _buildList(context, splitMode: true)),
              VerticalDivider(color: _G.borderMid, width: 1),
              const SizedBox(width: 14), // breathing room after the divider
              Expanded(
                child: _selectedUid == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _G.navyBlue.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 32,
                                color: _G.navyBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Select a conversation',
                              style: TextStyle(
                                color: _G.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ChatScreen(
                        key: ValueKey(_selectedUid),
                        customerUid: _selectedUid!,
                        customerName: _selectedName,
                        isEmployee: true,
                        embedded: true,
                        onClose: () => setState(() => _selectedUid = null),
                      ),
              ),
            ],
          );
        }
        return _buildList(context, splitMode: false);
      },
    );
  }
}

// =============================================================================
// Manage Account Content — wired to EmployeeManageAccount
// =============================================================================
class _EmployeeManageAccountContent extends StatelessWidget {
  final void Function(String) onNameUpdated;
  const _EmployeeManageAccountContent({required this.onNameUpdated});

  @override
  Widget build(BuildContext context) {
    return EmployeeManageAccount(onNameUpdated: onNameUpdated);
  }
}
