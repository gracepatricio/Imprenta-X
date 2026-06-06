import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_theme.dart';
import 'chat_screen.dart';
import 'customer_orders_screen.dart';
import 'invoice_screen.dart';
import 'payment_webview_screen.dart';
import '../services/paymongo_service.dart';
import 'design_file_viewer.dart';

// =============================================================================
// Design Tokens — Dark Frosted Glass (mirrors admin + product section accents)
// =============================================================================
class _G {
  // Background / surface
  static const Color navyBlue = Color(0xFF0F1A2E);
  static const Color darkBase = Color(0xFF0C091F); // deep dark bg

  // Frosted glass surfaces (dark-tinted)
  static const Color glassDark = Color(0x66080616); // 40% dark glass
  static const Color glassMid = Color(0x44080616); // lighter glass panel
  static const Color glassThin = Color(0x28080616);
  static const Color glassBorder = Color(0x4DFFFFFF); // white border 30%
  static const Color glassBorderDim = Color(0x1AFFFFFF); // white border 10%

  // Active button: light yellow (matches product filter "All" button)
  static const Color activeBtn = Color(0xFFF5F0C0); // light yellow/cream
  static const Color activeBtnText = Color(0xFF1A1200); // dark text on yellow

  // Text
  static const Color textPrimary = Color(0xFFEFF0F6);
  static const Color textSecondary = Color(0xCCEFF0F6);
  static const Color textMuted = Color(0x88EFF0F6);

  // Accents
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFEF4444);
  static const Color accentGold = Color(0xFFD97706);

  // Shadows
  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x55000000),
    blurRadius: 32,
    spreadRadius: -4,
    offset: Offset(0, 8),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  // Dark frosted glass card
  static BoxDecoration glassCard({
    double radius = 18,
    bool elevated = false,
    Color? tintBorder,
  }) => BoxDecoration(
    color: glassDark,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: tintBorder ?? glassBorder, width: 1.2),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  // Light frosted glass card — off-white, contrasts against dark containers
  static BoxDecoration lightCard({double radius = 14, Color? tintBorder}) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: tintBorder ?? Colors.white.withValues(alpha: 0.30),
          width: 1.1,
        ),
        boxShadow: const [rowShadow],
      );

  // Pill decoration for inactive chips
  static BoxDecoration pill({Color? tint}) => BoxDecoration(
    color: tint != null ? tint.withValues(alpha: 0.18) : glassThin,
    borderRadius: BorderRadius.circular(99),
    border: Border.all(
      color: tint != null ? tint.withValues(alpha: 0.45) : glassBorder,
      width: 0.9,
    ),
  );

  // Active pill (light yellow)
  static BoxDecoration activePill() =>
      BoxDecoration(color: activeBtn, borderRadius: BorderRadius.circular(99));
}

// Radius helper since const requires it
extension _RadiusHelper on BoxDecoration {
  static BoxDecoration activePill() => BoxDecoration(
    color: _G.activeBtn,
    borderRadius: BorderRadius.circular(99),
    boxShadow: [
      BoxShadow(
        color: _G.activeBtn.withValues(alpha: 0.45),
        blurRadius: 12,
        offset: const Offset(0, 3),
      ),
    ],
  );
}

// Blur + dark glass wrapper
class _GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final bool elevated;

  const _GlassCard({
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.borderColor,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 12, 9, 31).withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Active pill widget helper
Widget _activePillDecoration({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: _G.activeBtn,
      borderRadius: BorderRadius.circular(99),
      boxShadow: [
        BoxShadow(
          color: _G.activeBtn.withValues(alpha: 0.45),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

// ── Root ──────────────────────────────────────────────────────────────────────

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  String _menu = 'dashboard';
  String _ordersFilter = 'all';
  String fullName = '';
  String email = '';
  String customerId = '';

  static const _menus = [
    ('dashboard', 'Dashboard', Icons.dashboard_rounded),
    ('orders', 'Orders', Icons.receipt_long_rounded),
    ('messages', 'Messages', Icons.chat_bubble_rounded),
    ('manage', 'Profile', Icons.manage_accounts_rounded),
    ('feedback', 'Feedback', Icons.star_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        fullName = doc.data()?['full_name'] ?? '';
        email = doc.data()?['email'] ?? user.email ?? '';
        customerId = doc.data()?['customer_id'] ?? '';
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  void _goToOrders(String filter) => setState(() {
    _ordersFilter = filter;
    _menu = 'orders';
  });

  Widget _content() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    switch (_menu) {
      case 'orders':
        return _OrdersContent(uid: uid, initialFilter: _ordersFilter);
      case 'messages':
        return _MessagesContent(uid: uid);
      case 'manage':
        return _ManageAccountContent(
          onNameUpdated: (n) => setState(() => fullName = n),
        );
      case 'feedback':
        return _FeedbackContent(uid: uid, fullName: fullName);
      default:
        return _DashboardContent(
          uid: uid,
          onViewOrders: () => _goToOrders('all'),
          onViewMessages: () => setState(() => _menu = 'messages'),
          onViewOrdersFiltered: _goToOrders,
        );
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

  // ── Wide layout ─────────────────────────────────────────────────────────────

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 220,
              child: _GlassCard(
                borderRadius: 22,
                elevated: true,
                padding: const EdgeInsets.symmetric(
                  vertical: 26,
                  horizontal: 16,
                ),
                child: Column(
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 20),
                    ..._menus.map(
                      (m) => _SidebarBtn(
                        label: m.$2,
                        icon: m.$3,
                        isActive: _menu == m.$1,
                        onTap: () => setState(() => _menu = m.$1),
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
              child: _GlassCard(
                borderRadius: 22,
                elevated: true,
                padding: const EdgeInsets.all(28),
                child: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Narrow layout ───────────────────────────────────────────────────────────

  Widget _narrowLayout(BoxConstraints constraints) {
    final needsDirectHeight =
        _menu == 'orders' || _menu == 'messages' || _menu == 'feedback';

    return SizedBox(
      height: constraints.maxHeight,
      child: Column(
        children: [
          // Header card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _GlassCard(
              borderRadius: 20,
              padding: EdgeInsets.zero,
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
                                  fullName.isNotEmpty ? fullName : 'Customer',
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
                                if (customerId.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Text(
                                      'ID: $customerId',
                                      style: const TextStyle(
                                        color: _G.textSecondary,
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
                                      alpha: 0.35,
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
                            final active = _menu == m.$1;
                            return GestureDetector(
                              onTap: () => setState(() => _menu = m.$1),
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
                                        color: _G.activeBtn,
                                        borderRadius: BorderRadius.circular(99),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _G.activeBtn.withValues(
                                              alpha: 0.40,
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
                                          ? _G.activeBtnText
                                          : _G.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      m.$2,
                                      style: TextStyle(
                                        color: active
                                            ? _G.activeBtnText
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

          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: _GlassCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(16),
                child: needsDirectHeight
                    ? _content()
                    : SingleChildScrollView(child: _content()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar helpers ──────────────────────────────────────────────────────────

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.5,
            ),
            boxShadow: const [_G.rowShadow],
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 36,
            color: _G.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          fullName.isNotEmpty ? fullName : 'Customer',
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
        if (customerId.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 0.9,
              ),
            ),
            child: Text(
              'ID: $customerId',
              style: const TextStyle(
                color: _G.textSecondary,
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
        color: Colors.white.withValues(alpha: 0.10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Icon(Icons.person_rounded, size: iconSize, color: _G.textPrimary),
    );
  }
}

// ── Sidebar button ────────────────────────────────────────────────────────────

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
                  color: _G.activeBtn,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: _G.activeBtn.withValues(alpha: 0.40),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.9,
                  ),
                ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? _G.activeBtnText : _G.textMuted,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? _G.activeBtnText : _G.textSecondary,
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

// ── Logout button ─────────────────────────────────────────────────────────────

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
                color: _G.accentRose.withValues(alpha: 0.35),
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

// ══════════════════════════════════════════════════════════════════════════════
// Dashboard
// ══════════════════════════════════════════════════════════════════════════════

class _DashboardContent extends StatelessWidget {
  final String uid;
  final VoidCallback onViewOrders;
  final VoidCallback onViewMessages;
  final void Function(String filter) onViewOrdersFiltered;
  const _DashboardContent({
    required this.uid,
    required this.onViewOrders,
    required this.onViewMessages,
    required this.onViewOrdersFiltered,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  color: _G.textPrimary,
                  fontSize: isNarrow ? 17 : 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: isNarrow ? 12 : 18),
              const _SectionLabel(label: 'ORDER STATUS'),
              SizedBox(height: isNarrow ? 8 : 10),
              _OrderStatsRow(uid: uid, onFilter: onViewOrdersFiltered),
              SizedBox(height: isNarrow ? 16 : 28),
              _UnreadMessagesPreview(uid: uid, onViewAll: onViewMessages),
            ],
          ),
        );
      },
    );
  }
}

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

class _OrderStatsRow extends StatelessWidget {
  final String uid;
  final void Function(String filter) onFilter;
  const _OrderStatsRow({required this.uid, required this.onFilter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('customer_uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int pending = 0, active = 0, ready = 0;
        if (!snapshot.hasError) {
          for (final d in docs) {
            final s = (d.data() as Map)['status']?.toString() ?? '';
            if (s == 'pending') pending++;
            if (s == 'in_production') active++;
            if (s == 'ready') ready++;
          }
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
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
                      onTap: () => onFilter('pending'),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Active\nOrders',
                      count: active,
                      icon: Icons.precision_manufacturing_rounded,
                      color: _G.accentAmber,
                      compact: compact,
                      onTap: () => onFilter('in_production'),
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
                      onTap: () => onFilter('ready'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

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
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            _G.rowShadow,
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.40)),
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
              const SizedBox(height: 6),
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

class _UnreadMessagesPreview extends StatelessWidget {
  final String uid;
  final VoidCallback onViewAll;
  const _UnreadMessagesPreview({required this.uid, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Messages')
          .where('customer_uid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        final docs = (snapshot.data?.docs ?? []).where((d) {
          final unread = (d.data() as Map)['unread_customer'];
          return unread != null && (unread as num) > 0;
        }).toList();
        final totalUnread = docs.fold<int>(
          0,
          (sum, d) =>
              sum +
              (((d.data() as Map)['unread_customer'] as num?) ?? 0).toInt(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: docs.isNotEmpty ? onViewAll : null,
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
            const SizedBox(height: 10),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _G.lightCard(radius: 14),
                child: const Center(
                  child: Text(
                    'No unread messages',
                    style: TextStyle(color: _G.textMuted, fontSize: 13),
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final orderId = d['order_id']?.toString() ?? '';
                final orderDisplay = d['order_display']?.toString() ?? orderId;
                final lastMsg = d['last_message']?.toString() ?? '';
                final unread = d['unread_customer'] ?? 0;
                return _UnreadMessageCard(
                  orderId: orderId,
                  orderDisplay: orderDisplay,
                  lastMsg: lastMsg,
                  unread: unread,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        customerUid: uid,
                        customerName: '',
                        isEmployee: false,
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

class _UnreadMessageCard extends StatelessWidget {
  final String orderId, orderDisplay, lastMsg;
  final int unread;
  final VoidCallback onTap;
  const _UnreadMessageCard({
    required this.orderId,
    required this.orderDisplay,
    required this.lastMsg,
    required this.unread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: _G.lightCard(radius: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _G.accentViolet.withValues(alpha: 0.18),
              border: Border.all(
                color: _G.accentViolet.withValues(alpha: 0.40),
                width: 0.9,
              ),
            ),
            child: const Icon(
              Icons.local_print_shop_rounded,
              color: _G.accentViolet,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Imprenta Inc.',
                  style: TextStyle(
                    color: _G.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (lastMsg.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    lastMsg,
                    style: const TextStyle(color: _G.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: _G.pill(tint: _G.accentRose),
            child: Text(
              '$unread new',
              style: const TextStyle(
                color: _G.accentRose,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _G.activeBtn,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: _G.activeBtn.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: _G.activeBtnText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Orders — now with ALL filter
// ══════════════════════════════════════════════════════════════════════════════

class _OrdersContent extends StatefulWidget {
  final String uid;
  final String initialFilter;
  const _OrdersContent({required this.uid, this.initialFilter = 'all'});

  @override
  State<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<_OrdersContent> {
  late String _filter = widget.initialFilter;

  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('in_production', 'Active'),
    ('ready', 'Ready'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orders',
          style: TextStyle(
            color: _G.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        // Filter tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) {
              final active = _filter == f.$1;
              return GestureDetector(
                onTap: () => setState(() => _filter = f.$1),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: active
                      ? BoxDecoration(
                          color: _G.activeBtn,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [
                            BoxShadow(
                              color: _G.activeBtn.withValues(alpha: 0.40),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        )
                      : _G.pill(),
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      color: active ? _G.activeBtnText : _G.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _filter == 'all'
              ? _buildAllOrders()
              : _buildFilteredOrders(_filter),
        ),
      ],
    );
  }

  Widget _buildAllOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('customer_uid', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snap) => _orderList(snap, 'all'),
    );
  }

  Widget _buildFilteredOrders(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Orders')
          .where('customer_uid', isEqualTo: widget.uid)
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snap) => _orderList(snap, status),
    );
  }

  Widget _orderList(AsyncSnapshot<QuerySnapshot> snap, String filter) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Center(
        child: CircularProgressIndicator(color: _G.activeBtn, strokeWidth: 2),
      );
    }
    if (snap.hasError) {
      return Center(
        child: Text(
          'Could not load orders.\nCheck your connection.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _G.textMuted, fontSize: 13),
        ),
      );
    }
    final docs = List.from(snap.data?.docs ?? [])
      ..sort((a, b) {
        final aTs = (a.data() as Map)['created_at'];
        final bTs = (b.data() as Map)['created_at'];
        if (aTs == null || bTs == null) return 0;
        return (bTs as dynamic).compareTo(aTs);
      });
    if (docs.isEmpty) {
      final label = filter == 'all'
          ? 'No orders yet'
          : 'No ${_filters.firstWhere((f) => f.$1 == filter).$2.toLowerCase()} orders';
      return Center(
        child: Text(
          label,
          style: const TextStyle(color: _G.textMuted, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final d = docs[i].data() as Map<String, dynamic>;
        final status = d['status']?.toString() ?? '';
        return _OrderCard(
          orderId: d['order_id']?.toString() ?? docs[i].id,
          data: d,
          showMessage: status != 'cancelled',
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final bool showMessage;
  const _OrderCard({
    required this.orderId,
    required this.data,
    required this.showMessage,
  });

  double get _total => (data['total_price'] as num?)?.toDouble() ?? 0;
  double get _paid => (data['amount_paid'] as num?)?.toDouble() ?? 0;
  double get _remaining =>
      (data['remaining_balance'] as num?)?.toDouble() ?? (_total - _paid);

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountOrderDetailSheet(
        docId: orderId,
        data: data,
        showMessage: showMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? '';
    final products = List<Map>.from(data['products'] ?? []);
    final remaining = _remaining;
    final total = _total;
    final paid = _paid;
    final pct = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final fullyPaid = remaining < 0.01;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _G.lightCard(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    orderId,
                    style: const TextStyle(
                      color: _G.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 10),
            ...products.map((p) {
              final name = p['name']?.toString() ?? '';
              final qty = p['qty'] ?? p['quantity'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _G.textMuted,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '$name × $qty',
                        style: const TextStyle(
                          color: _G.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            DesignFilesSection(products: products),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                // Try order-level notes first, then first product's notes
                final orderNotes = data['notes']?.toString() ?? '';
                final products = List<Map>.from(data['products'] ?? []);
                final productNotes = products.isNotEmpty
                    ? (products.first['notes']?.toString() ?? '')
                    : '';
                final displayNote = orderNotes.isNotEmpty
                    ? orderNotes
                    : productNotes.isNotEmpty
                    ? productNotes
                    : '';
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_outlined, size: 12, color: _G.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        displayNote.isNotEmpty
                            ? 'Special Instructions: $displayNote'
                            : 'Special Instructions: None',
                        style: const TextStyle(
                          color: _G.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (status == 'cancelled' &&
                (data['cancel_reason']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      size: 13,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Cancellation Reason: ${data['cancel_reason']}',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Divider(color: Colors.white.withValues(alpha: 0.10), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _G.accentAmber,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (total > 0 && paid > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        fullyPaid
                            ? 'Fully paid'
                            : 'Remaining: ₱${remaining.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: fullyPaid ? _G.accentEmerald : _G.accentAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    if (showMessage)
                      GestureDetector(
                        onTap: () {
                          final uid =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                customerUid: uid,
                                customerName: '',
                                isEmployee: false,
                                orderContext: {
                                  'order_id': orderId,
                                  'products': products,
                                  'total_price': data['total_price'],
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 12,
                                color: _G.textSecondary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Message',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _G.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: _G.textMuted, size: 18),
                  ],
                ),
              ],
            ),
            if (total > 0 && paid > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: _G.accentAmber.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fullyPaid ? _G.accentEmerald : _G.accentAmber,
                  ),
                  minHeight: 4,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Tap to view details & payment QR',
              style: TextStyle(color: _G.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Account order detail sheet ─────────────────────────────────────────────────

class _AccountOrderDetailSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool showMessage;
  const _AccountOrderDetailSheet({
    required this.docId,
    required this.data,
    required this.showMessage,
  });

  @override
  State<_AccountOrderDetailSheet> createState() =>
      _AccountOrderDetailSheetState();
}

class _AccountOrderDetailSheetState extends State<_AccountOrderDetailSheet> {
  bool _payingNow = false;

  String get _status => widget.data['status']?.toString() ?? '';
  double get _total => (widget.data['total_price'] as num?)?.toDouble() ?? 0;
  double get _paid => (widget.data['amount_paid'] as num?)?.toDouble() ?? 0;
  double get _remaining =>
      (widget.data['remaining_balance'] as num?)?.toDouble() ??
      (_total - _paid);

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as dynamic).toDate() as DateTime;
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  Future<void> _payNow() async {
    final orderId = widget.data['order_id']?.toString() ?? widget.docId;
    final minAmt = _status == 'awaiting_payment'
        ? (_total * 0.5 * 100).round() / 100
        : 1.0;
    final maxAmt = _status == 'awaiting_payment' ? _total : _remaining;

    final chosen = await _showAmountSheet(minAmt, maxAmt);
    if (chosen == null || !mounted) return;

    setState(() => _payingNow = true);
    try {
      final isInitial = _status == 'awaiting_payment';
      final link = await PayMongoService.createLink(
        amount: chosen,
        description: isInitial
            ? 'Downpayment $orderId (Imprenta X)'
            : 'Balance Payment $orderId (Imprenta X)',
      );
      await FirebaseFirestore.instance
          .collection('PayMongoLinks')
          .doc(link.id)
          .set({
            'order_id': orderId,
            'purpose': isInitial ? 'downpayment' : 'balance',
            'expected_amount': chosen,
            'processed': false,
            'created_at': FieldValue.serverTimestamp(),
          });
      if (!isInitial) {
        await FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .update({
              'balance_link_id': link.id,
              'balance_checkout_url': link.checkoutUrl,
              'balance_link_amount': chosen,
            });
      }
      final String checkoutUrl = link.checkoutUrl;
      final String linkId = link.id;

      if (!mounted) return;
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: checkoutUrl,
            linkId: linkId,
            orderId: orderId,
            payAmount: chosen,
            isBalancePayment: !isInitial,
          ),
        ),
      );

      if (paid == true && mounted) {
        Navigator.pop(context);
        final invoiceId = widget.data['invoice_id']?.toString();
        if (invoiceId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  InvoiceScreen(invoiceId: invoiceId, fromPayment: true),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: _G.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _payingNow = false);
    }
  }

  Future<double?> _showAmountSheet(double minAmt, double maxAmt) {
    final ctrl = TextEditingController(text: maxAmt.toStringAsFixed(2));
    return showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final chosen = (double.tryParse(ctrl.text) ?? maxAmt).clamp(
            minAmt,
            maxAmt,
          );
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(
                    255,
                    12,
                    9,
                    31,
                  ).withValues(alpha: 0.92),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.0,
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                      left: 20,
                      right: 20,
                      top: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Enter Payment Amount',
                            style: TextStyle(
                              color: _G.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _G.accentAmber.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _G.accentAmber.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: _G.accentAmber,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _status == 'awaiting_payment'
                                      ? 'Minimum: ₱${minAmt.toStringAsFixed(2)} (50% downpayment)'
                                      : 'Outstanding balance: ₱${maxAmt.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: _G.accentAmber,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 14),
                                child: Text(
                                  '₱',
                                  style: TextStyle(
                                    color: _G.textSecondary,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    color: _G.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                      color: _G.textMuted,
                                      fontSize: 20,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 14,
                                    ),
                                  ),
                                  onChanged: (_) => setSheet(() {}),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: chosen < minAmt - 0.009
                                ? null
                                : () => Navigator.pop(ctx, chosen),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: chosen < minAmt - 0.009
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : _G.activeBtn,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.payment_rounded,
                                    color: chosen < minAmt - 0.009
                                        ? _G.textMuted
                                        : _G.activeBtnText,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pay ₱${chosen.toStringAsFixed(2)} via PayMongo',
                                    style: TextStyle(
                                      color: chosen < minAmt - 0.009
                                          ? _G.textMuted
                                          : _G.activeBtnText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products =
        (widget.data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final turnaround = widget.data['turnaround_days'] as int?;
    final invoiceId = widget.data['invoice_id']?.toString();
    final remaining = _remaining;
    final fullyPaid = remaining < 0.01;
    final showPayBtn =
        _status == 'awaiting_payment' ||
        (remaining > 0.009 &&
            ['pending', 'in_production', 'ready'].contains(_status));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 12, 9, 31).withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.0,
            ),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.95,
            builder: (_, ctrl) => ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data['order_id']?.toString() ?? widget.docId,
                            style: const TextStyle(
                              color: _G.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Placed ${_fmtDate(widget.data['created_at'])}',
                            style: const TextStyle(
                              color: _G.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: _status),
                  ],
                ),

                if (turnaround != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _G.accentAmber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _G.accentAmber.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          color: _G.accentAmber,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Est. turnaround: ~$turnaround day${turnaround == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: _G.accentAmber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const _SectionLabel(label: 'ITEMS'),
                const SizedBox(height: 8),
                ...products.map((p) {
                  final name = p['name']?.toString() ?? '—';
                  final qty = p['qty']?.toString() ?? '1';
                  final price = (p['price'] as num?)?.toStringAsFixed(2) ?? '—';
                  final size = p['size_label']?.toString();
                  final mat = p['material']?.toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: _G.lightCard(radius: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: _G.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                [
                                  'Qty: $qty',
                                  if (size != null) size,
                                  if (mat != null) mat,
                                ].join(' · '),
                                style: const TextStyle(
                                  color: _G.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱$price',
                          style: const TextStyle(
                            color: _G.accentAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 8),
                Divider(color: Colors.white.withValues(alpha: 0.10)),
                const SizedBox(height: 8),

                _BalRow('Order Total', _total, _G.textPrimary),
                const SizedBox(height: 6),
                _BalRow('Paid', _paid, _G.accentEmerald),
                const SizedBox(height: 6),
                _BalRow(
                  fullyPaid ? 'Fully Paid' : 'Balance Due on Pickup',
                  fullyPaid ? 0 : remaining,
                  fullyPaid ? _G.accentEmerald : _G.accentAmber,
                  large: true,
                ),
                if (!fullyPaid) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _total > 0 ? (_paid / _total).clamp(0, 1) : 0,
                      backgroundColor: _G.accentAmber.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        _G.accentAmber,
                      ),
                      minHeight: 5,
                    ),
                  ),
                ],

                if (showPayBtn) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _payingNow ? null : _payNow,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _payingNow
                            ? Colors.white.withValues(alpha: 0.10)
                            : _G.activeBtn,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_payingNow)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            Icon(
                              Icons.payment_rounded,
                              color: _G.activeBtnText,
                              size: 18,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _status == 'awaiting_payment'
                                ? 'Pay via PayMongo (min 50%)'
                                : 'Pay Remaining ₱${remaining.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _payingNow
                                  ? _G.textMuted
                                  : _G.activeBtnText,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (invoiceId != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => InvoiceScreen(invoiceId: invoiceId),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.receipt_long_rounded,
                            color: _G.textSecondary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'View Invoice',
                            style: TextStyle(
                              color: _G.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BalRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool large;
  const _BalRow(this.label, this.value, this.color, {this.large = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: _G.textSecondary,
            fontSize: large ? 14 : 13,
            fontWeight: large ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
      Text(
        value < 0.01 ? 'Settled' : '₱${value.toStringAsFixed(2)}',
        style: TextStyle(
          color: color,
          fontSize: large ? 18 : 13,
          fontWeight: large ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ],
  );
}

// ── QR code section ───────────────────────────────────────────────────────────

class _AccountQrSection extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> order;
  final String status;
  final double remaining;
  const _AccountQrSection({
    required this.docId,
    required this.order,
    required this.status,
    required this.remaining,
  });

  @override
  State<_AccountQrSection> createState() => _AccountQrSectionState();
}

class _AccountQrSectionState extends State<_AccountQrSection> {
  String? _localUrl;
  bool _generating = false;
  bool _stale = false;
  bool _validating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _validateStoredLink());
  }

  Future<void> _validateStoredLink() async {
    final isInitial = widget.status == 'awaiting_payment';
    final linkId = isInitial
        ? widget.order['paymongo_link_id'] as String?
        : widget.order['balance_link_id'] as String?;
    if (linkId == null || !mounted) {
      if (mounted) setState(() => _validating = false);
      return;
    }
    try {
      final status = await PayMongoService.getLinkStatus(linkId);
      if (!mounted) return;
      if (status == 'paid') {
        if (!isInitial) await _applyQrPayment(linkId);
        setState(() => _validating = false);
        return;
      }
      setState(() => _validating = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stale = true);
      final orderId = widget.order['order_id']?.toString() ?? widget.docId;
      if (isInitial) {
        FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .update({
              'paymongo_link_id': FieldValue.delete(),
              'paymongo_checkout_url': FieldValue.delete(),
            })
            .catchError((_) {});
      } else {
        FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .update({
              'balance_link_id': FieldValue.delete(),
              'balance_checkout_url': FieldValue.delete(),
              'balance_link_amount': FieldValue.delete(),
            })
            .catchError((_) {});
      }
      if (mounted) await _generate();
    }
  }

  String? get _url {
    if (_validating) return null;
    if (_stale) return _localUrl;
    return _localUrl ??
        (widget.status == 'awaiting_payment'
            ? widget.order['paymongo_checkout_url'] as String?
            : widget.order['balance_checkout_url'] as String?);
  }

  Future<void> _applyQrPayment(String paidLinkId) async {
    final orderId = widget.order['order_id']?.toString() ?? widget.docId;
    final paid = (widget.order['balance_link_amount'] as num?)?.toDouble() ?? 0;
    if (paid <= 0) return;
    final oldPaid = (widget.order['amount_paid'] as num?)?.toDouble() ?? 0;
    final newPaid = oldPaid + paid;
    final newRemain =
        ((widget.order['remaining_balance'] as num?)?.toDouble() ?? 0) - paid;
    final fullyPaid = newRemain < 0.01;

    await FirebaseFirestore.instance
        .collection('Orders')
        .doc(orderId)
        .update({
          'amount_paid': newPaid,
          'remaining_balance': newRemain.clamp(0.0, double.infinity),
          'payment_status': fullyPaid ? 'paid' : 'partial',
          if (fullyPaid) 'fully_paid_at': FieldValue.serverTimestamp(),
          'balance_link_id': FieldValue.delete(),
          'balance_checkout_url': FieldValue.delete(),
          'balance_link_amount': FieldValue.delete(),
        })
        .catchError((_) {});

    await FirebaseFirestore.instance
        .collection('Payments')
        .doc()
        .set({
          'order_id': orderId,
          'amount': paid,
          'payment_type': 'balance',
          'payment_method': 'online',
          'transaction_reference': paidLinkId,
          'payment_date': FieldValue.serverTimestamp(),
          'status': 'paid',
        })
        .catchError((_) {});

    if (!fullyPaid && mounted) {
      setState(() => _stale = true);
      await _generate();
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final orderId = widget.order['order_id']?.toString() ?? widget.docId;
      final isInitial = widget.status == 'awaiting_payment';
      final total = (widget.order['total_price'] as num?)?.toDouble() ?? 0;
      final amount = isInitial
          ? (total * 0.5 * 100).round() / 100
          : widget.remaining;

      final link = await PayMongoService.createLink(
        amount: amount,
        description: isInitial
            ? 'Downpayment $orderId (Imprenta X)'
            : 'Balance Payment $orderId (Imprenta X)',
      );

      final orderUpdates = isInitial
          ? {
              'paymongo_link_id': link.id,
              'paymongo_checkout_url': link.checkoutUrl,
            }
          : {
              'balance_link_id': link.id,
              'balance_checkout_url': link.checkoutUrl,
              'balance_link_amount': amount,
            };

      await Future.wait([
        FirebaseFirestore.instance
            .collection('PayMongoLinks')
            .doc(link.id)
            .set({
              'order_id': orderId,
              'purpose': isInitial ? 'downpayment' : 'balance',
              'expected_amount': amount,
              'processed': false,
              'created_at': FieldValue.serverTimestamp(),
            }),
        FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .update(orderUpdates),
      ]);
      if (mounted)
        setState(() {
          _localUrl = link.checkoutUrl;
          _validating = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _validating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: _G.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final amount =
        (widget.order['balance_link_amount'] as num?)?.toDouble() ??
        widget.remaining;

    if (_validating || (_generating && url == null)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(
            color: _G.accentAmber,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (url == null && widget.status != 'awaiting_payment') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _G.glassCard(radius: 12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: _G.textSecondary,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Generate a QR code so you or anyone can scan and pay the remaining balance.',
                    style: TextStyle(color: _G.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _generating ? null : _generate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _generating
                      ? Colors.white.withValues(alpha: 0.05)
                      : _G.activeBtn,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_generating)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _G.activeBtnText,
                        ),
                      )
                    else
                      Icon(
                        Icons.qr_code_2_rounded,
                        color: _G.activeBtnText,
                        size: 15,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _generating ? 'Generating…' : 'Generate Payment QR',
                      style: TextStyle(
                        color: _generating ? _G.textMuted : _G.activeBtnText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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

    if (url == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _G.accentAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _G.accentAmber.withValues(alpha: 0.30)),
        boxShadow: const [_G.rowShadow],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _G.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: _G.accentAmber,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.status == 'awaiting_payment'
                    ? 'SCAN TO PAY DOWNPAYMENT'
                    : 'SCAN TO PAY REMAINING BALANCE',
                style: const TextStyle(
                  color: _G.accentAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [_G.rowShadow],
              ),
              child: QrImageView(
                data: url,
                size: 180,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F1A2E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F1A2E),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: _G.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Opens PayMongo → GCash / Maya / Card',
            style: TextStyle(color: _G.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          const Text(
            'This QR is unique to this order and safe to share.',
            style: TextStyle(color: _G.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'pending':
        color = _G.accentAmber;
        label = 'Pending';
        break;
      case 'in_production':
        color = _G.accentBlue;
        label = 'In Production';
        break;
      case 'ready':
      case 'ready_for_pickup':
        color = _G.accentEmerald;
        label = 'Ready';
        break;
      case 'cancelled':
        color = _G.accentRose;
        label = 'Cancelled';
        break;
      case 'completed':
        color = _G.textMuted;
        label = 'Completed';
        break;
      case 'awaiting_payment':
        color = _G.accentViolet;
        label = 'Awaiting Payment';
        break;
      default:
        color = _G.textMuted;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Messages
// ══════════════════════════════════════════════════════════════════════════════

class _MessagesContent extends StatefulWidget {
  final String uid;
  const _MessagesContent({required this.uid});

  @override
  State<_MessagesContent> createState() => _MessagesContentState();
}

class _MessagesContentState extends State<_MessagesContent> {
  @override
  void initState() {
    super.initState();
    _ensureGeneralThread();
  }

  Future<void> _ensureGeneralThread() async {
    final ref = FirebaseFirestore.instance
        .collection('Messages')
        .doc('chat_${widget.uid}');
    final snap = await ref.get();
    if (snap.exists) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('User')
        .doc(widget.uid)
        .get();
    final name = userDoc.data()?['full_name'] ?? 'Customer';
    await ref.set({
      'customer_uid': widget.uid,
      'customer_name': name,
      'last_message': '',
      'last_updated': FieldValue.serverTimestamp(),
      'unread_customer': 0,
      'unread_employee': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Messages',
          style: TextStyle(
            color: _G.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Messages')
                .where('customer_uid', isEqualTo: widget.uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                  child: Text(
                    'Could not load messages.',
                    style: TextStyle(color: _G.textMuted, fontSize: 13),
                  ),
                );
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _G.activeBtn,
                    strokeWidth: 2,
                  ),
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
                return const Center(
                  child: CircularProgressIndicator(
                    color: _G.activeBtn,
                    strokeWidth: 2,
                  ),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final lastMsg = d['last_message']?.toString() ?? '';
                  final unread = ((d['unread_customer'] as num?) ?? 0).toInt();
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          customerUid: widget.uid,
                          customerName: '',
                          isEmployee: false,
                        ),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _G.lightCard(radius: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                                width: 0.9,
                              ),
                            ),
                            child: const Icon(
                              Icons.local_print_shop_rounded,
                              color: _G.textSecondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Imprenta Inc.',
                                  style: TextStyle(
                                    color: _G.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Printing Services',
                                  style: TextStyle(
                                    color: _G.accentAmber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (lastMsg.isNotEmpty) ...[
                                  const SizedBox(height: 2),
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
                              ],
                            ),
                          ),
                          if (unread > 0)
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            color: _G.textMuted,
                            size: 18,
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Manage Account / Profile — fully functional email change + password flowchart
// ══════════════════════════════════════════════════════════════════════════════

class _ManageAccountContent extends StatefulWidget {
  final void Function(String) onNameUpdated;
  const _ManageAccountContent({required this.onNameUpdated});

  @override
  State<_ManageAccountContent> createState() => _ManageAccountContentState();
}

class _ManageAccountContentState extends State<_ManageAccountContent>
    with SingleTickerProviderStateMixin {
  // ── Personal Info ──────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  bool _savingInfo = false;
  String? _infoMsg, _infoErr;

  // ── Email change (full flow) ───────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _emailPwCtrl = TextEditingController();
  bool _editingEmail = false;
  bool _savingEmail = false;
  bool _showEmailPw = false;
  bool _verificationPending = false;
  String _pendingNewEmail = '';
  String _pendingPassword = '';
  String _originalEmail = '';
  bool _checkingVerification = false;
  String? _emailMsg, _emailErr;

  // ── Password (two-step matching flowchart) ─────────────────────
  int _pwStep = 0; // 0 = verify current, 1 = set new
  bool _verifyingCur = false;
  bool _savingPw = false;
  bool _showCur = false, _showNew = false, _showConf = false;
  final _curPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confPwCtrl = TextEditingController();
  String? _pwMsg, _pwErr;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _loadUser();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _emailPwCtrl.dispose();
    _curPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() {
        _nameCtrl.text = doc.data()?['full_name'] ?? user.displayName ?? '';
        _emailCtrl.text = doc.data()?['email'] ?? user.email ?? '';
        _originalEmail = _emailCtrl.text;
        _loading = false;
      });
    }
  }

  // ── Save name ──────────────────────────────────────────────────

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _infoErr = 'Name cannot be empty.';
        _infoMsg = null;
      });
      return;
    }
    setState(() {
      _savingInfo = true;
      _infoErr = null;
      _infoMsg = null;
    });
    try {
      await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
        'full_name': name,
      });
      await user.updateDisplayName(name);
      widget.onNameUpdated(name);
      if (mounted)
        setState(() {
          _infoMsg = 'Name updated successfully.';
          _savingInfo = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _infoErr = 'Failed: $e';
          _savingInfo = false;
        });
    }
  }

  // ── Email change (matches admin_profile.dart logic) ────────────

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newEmail = _emailCtrl.text.trim();
    final password = _emailPwCtrl.text;

    if (newEmail.isEmpty) {
      setState(() {
        _emailErr = 'Email cannot be empty.';
        _emailMsg = null;
      });
      return;
    }
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(newEmail)) {
      setState(() {
        _emailErr = 'Enter a valid email address.';
        _emailMsg = null;
      });
      return;
    }
    if (newEmail == _originalEmail) {
      setState(() {
        _emailErr = 'This is already your current email.';
        _emailMsg = null;
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _emailErr = 'Enter your current password to confirm.';
        _emailMsg = null;
      });
      return;
    }

    setState(() {
      _savingEmail = true;
      _emailErr = null;
      _emailMsg = null;
    });
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);
      if (!mounted) return;
      setState(() {
        _verificationPending = true;
        _pendingNewEmail = newEmail;
        _pendingPassword = password;
        _savingEmail = false;
        _editingEmail = false;
        _emailErr = null;
        _emailMsg = null;
        _emailPwCtrl.clear();
        _showEmailPw = false;
      });
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect password.';
          break;
        case 'requires-recent-login':
          msg = 'Session expired. Please log out and log back in.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait and try again.';
          break;
        default:
          msg = 'Error (${e.code}): ${e.message ?? 'Please try again.'}';
      }
      if (mounted)
        setState(() {
          _emailErr = msg;
          _savingEmail = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _emailErr = 'Unexpected error: $e';
          _savingEmail = false;
        });
    }
  }

  Future<void> _checkVerification() async {
    setState(() {
      _checkingVerification = true;
      _emailErr = null;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == _pendingNewEmail) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _pendingNewEmail,
          password: _pendingPassword,
        );
        user = cred.user;
      } else {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
      }
      if (user == null) {
        if (mounted)
          setState(() {
            _emailErr = 'Session lost. Please log in again.';
            _checkingVerification = false;
          });
        return;
      }
      if ((user.email ?? '') != _pendingNewEmail) {
        if (mounted)
          setState(() {
            _emailErr =
                'Email not verified yet. Please check your inbox and click the link, then try again.';
            _checkingVerification = false;
          });
        return;
      }
      await _finalizeEmailChange(_pendingNewEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-token-expired' ||
          e.code == 'invalid-user-token' ||
          e.code == 'user-not-found') {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _pendingNewEmail,
            password: _pendingPassword,
          );
          if (cred.user != null && cred.user!.email == _pendingNewEmail) {
            await _finalizeEmailChange(_pendingNewEmail);
            return;
          }
        } catch (_) {}
      }
      if (mounted)
        setState(() {
          _emailErr = 'Verification check failed: ${e.message ?? e.code}';
          _checkingVerification = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _emailErr = 'Verification check failed: $e';
          _checkingVerification = false;
        });
    }
  }

  Future<void> _finalizeEmailChange(String newEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
        'email': newEmail,
      });
      if (!mounted) return;
      _originalEmail = newEmail;
      setState(() {
        _verificationPending = false;
        _pendingNewEmail = '';
        _pendingPassword = '';
        _checkingVerification = false;
        _emailCtrl.text = newEmail;
        _emailMsg = 'Email changed successfully.';
        _emailErr = null;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _emailErr = 'Failed to save email change: $e';
          _checkingVerification = false;
        });
    }
  }

  // ── Password: two-step (flowchart: verify current → set new) ──

  Future<void> _verifyCurrentPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final cur = _curPwCtrl.text;
    if (cur.isEmpty) {
      setState(() {
        _pwErr = 'Please enter your current password.';
        _pwMsg = null;
      });
      return;
    }
    setState(() {
      _verifyingCur = true;
      _pwErr = null;
      _pwMsg = null;
    });
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: cur,
      );
      await user.reauthenticateWithCredential(cred);
      if (mounted) {
        setState(() {
          _verifyingCur = false;
          _pwStep = 1;
        });
        _slideCtrl.forward(from: 0);
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Incorrect password. Please try again.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please wait.';
          break;
        default:
          msg = 'Error (${e.code}): ${e.message ?? 'Please try again.'}';
      }
      if (mounted)
        setState(() {
          _pwErr = msg;
          _verifyingCur = false;
        });
    }
  }

  Future<void> _setNewPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final nw = _newPwCtrl.text;
    final conf = _confPwCtrl.text;
    if (nw.isEmpty || conf.isEmpty) {
      setState(() {
        _pwErr = 'Please fill in all fields.';
        _pwMsg = null;
      });
      return;
    }
    if (nw.length < 6) {
      setState(() {
        _pwErr = 'Password must be at least 6 characters.';
        _pwMsg = null;
      });
      return;
    }
    if (nw != conf) {
      setState(() {
        _pwErr = 'Passwords do not match.';
        _pwMsg = null;
      });
      return;
    }
    setState(() {
      _savingPw = true;
      _pwErr = null;
      _pwMsg = null;
    });
    try {
      await user.updatePassword(nw);
      if (mounted) {
        setState(() {
          _pwMsg = 'Password changed successfully.';
          _savingPw = false;
          _pwStep = 0;
          _curPwCtrl.clear();
          _newPwCtrl.clear();
          _confPwCtrl.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() {
          _pwErr = e.code == 'weak-password'
              ? 'Password is too weak.'
              : (e.message ?? 'Failed.');
          _savingPw = false;
        });
    }
  }

  void _resetPwFlow() {
    setState(() {
      _pwStep = 0;
      _pwErr = null;
      _pwMsg = null;
      _curPwCtrl.clear();
      _newPwCtrl.clear();
      _confPwCtrl.clear();
    });
  }

  // ── UI Helpers ─────────────────────────────────────────────────

  Widget _glassField({
    required String label,
    required TextEditingController ctrl,
    bool readOnly = false,
    IconData? icon,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.28),
        width: 1.0,
      ),
    ),
    child: TextField(
      controller: ctrl,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? _G.textMuted : _G.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _G.textMuted, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: _G.textMuted, size: 17)
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    ),
  );

  Widget _pwField({
    required String label,
    required TextEditingController ctrl,
    required bool show,
    required VoidCallback toggle,
    Color? accentColor,
  }) => Container(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.28),
        width: 1.0,
      ),
    ),
    child: TextField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(color: _G.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _G.textMuted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: _G.textMuted,
          size: 17,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility : Icons.visibility_off,
            color: _G.textMuted,
            size: 18,
          ),
          onPressed: toggle,
        ),
      ),
    ),
  );

  Widget _banner(String msg, bool isError) {
    final color = isError ? _G.accentRose : _G.accentEmerald;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: color.withValues(alpha: 0.30),
              width: 1.0,
            ),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _G.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.25), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _primaryBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool loading = false,
    Color? color,
  }) {
    final c = color ?? _G.activeBtn;
    final textC = (c == _G.activeBtn) ? _G.activeBtnText : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.white.withValues(alpha: 0.05) : c,
          borderRadius: BorderRadius.circular(99),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: c.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textC,
                    ),
                  )
                : Icon(
                    icon,
                    size: 14,
                    color: onTap == null ? _G.textMuted : textC,
                  ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: onTap == null ? _G.textMuted : textC,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outlinedBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final c = color ?? _G.accentViolet;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password Section (two-step) ────────────────────────────────

  Widget _passwordSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step track header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 0.9,
                ),
              ),
            ),
            child: Row(
              children: [
                _StepChip(
                  number: 1,
                  label: 'Verify Identity',
                  isActive: _pwStep == 0,
                  isDone: _pwStep > 0,
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 2,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        height: 2,
                        width: _pwStep >= 1 ? double.infinity : 0,
                        color: _G.accentEmerald,
                      ),
                    ],
                  ),
                ),
                _StepChip(
                  number: 2,
                  label: 'New Password',
                  isActive: _pwStep == 1,
                  isDone: false,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _pwStep == 0 ? _step0() : _step1(),
          ),
        ],
      ),
    );
  }

  Widget _step0() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Enter your current password to proceed',
        style: TextStyle(color: _G.textMuted, fontSize: 12),
      ),
      const SizedBox(height: 10),
      _pwField(
        label: 'Current Password',
        ctrl: _curPwCtrl,
        show: _showCur,
        toggle: () => setState(() => _showCur = !_showCur),
      ),
      if (_pwErr != null) ...[
        const SizedBox(height: 8),
        _banner(_pwErr!, true),
      ],
      if (_pwMsg != null) ...[
        const SizedBox(height: 8),
        _banner(_pwMsg!, false),
      ],
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _primaryBtn(
            label: 'Verify & Continue',
            icon: Icons.arrow_forward_rounded,
            onTap: _verifyingCur ? null : _verifyCurrentPassword,
            loading: _verifyingCur,
          ),
        ],
      ),
    ],
  );

  Widget _step1() => SlideTransition(
    position: _slideAnim,
    child: FadeTransition(
      opacity: _slideCtrl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose a new password',
            style: TextStyle(color: _G.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'New Password',
            ctrl: _newPwCtrl,
            show: _showNew,
            toggle: () => setState(() => _showNew = !_showNew),
            accentColor: _G.accentEmerald,
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'Confirm New Password',
            ctrl: _confPwCtrl,
            show: _showConf,
            toggle: () => setState(() => _showConf = !_showConf),
            accentColor: _G.accentEmerald,
          ),
          if (_pwErr != null) ...[
            const SizedBox(height: 8),
            _banner(_pwErr!, true),
          ],
          if (_pwMsg != null) ...[
            const SizedBox(height: 8),
            _banner(_pwMsg!, false),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _resetPwFlow,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 14,
                      color: _G.textMuted,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: _G.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _primaryBtn(
                label: 'Change Password',
                icon: Icons.check_rounded,
                onTap: _savingPw ? null : _setNewPassword,
                loading: _savingPw,
                color: _G.accentEmerald,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _G.activeBtn, strokeWidth: 2),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: _G.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),

          // ── Personal Info ─────────────────────────────────────
          _sectionHeader(
            'Personal Information',
            Icons.person_outline_rounded,
            _G.activeBtn,
          ),
          _glassField(
            label: 'Full Name',
            ctrl: _nameCtrl,
            icon: Icons.person_outline_rounded,
          ),
          if (_infoErr != null) ...[
            const SizedBox(height: 8),
            _banner(_infoErr!, true),
          ],
          if (_infoMsg != null) ...[
            const SizedBox(height: 8),
            _banner(_infoMsg!, false),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _primaryBtn(
                label: 'Save Name',
                icon: Icons.save_rounded,
                onTap: _savingInfo ? null : _saveName,
                loading: _savingInfo,
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── Email ─────────────────────────────────────────────
          _sectionHeader(
            'Email Address',
            Icons.email_outlined,
            _G.accentViolet,
          ),
          _glassField(
            label: 'Email',
            ctrl: _emailCtrl,
            readOnly: !_editingEmail && !_verificationPending,
            icon: Icons.email_outlined,
          ),

          if (!_editingEmail && !_verificationPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _outlinedBtn(
                  label: 'Change Email',
                  icon: Icons.edit_outlined,
                  color: _G.accentViolet,
                  onTap: () => setState(() {
                    _editingEmail = true;
                    _emailErr = null;
                    _emailMsg = null;
                    _emailPwCtrl.clear();
                  }),
                ),
              ],
            ),
          ] else if (_editingEmail && !_verificationPending) ...[
            const SizedBox(height: 10),
            _pwField(
              label: 'Current Password (to confirm)',
              ctrl: _emailPwCtrl,
              show: _showEmailPw,
              toggle: () => setState(() => _showEmailPw = !_showEmailPw),
              accentColor: _G.accentViolet,
            ),
            if (_emailErr != null) ...[
              const SizedBox(height: 8),
              _banner(_emailErr!, true),
            ],
            const SizedBox(height: 4),
            const Text(
              'A verification link will be sent to your new email.',
              style: TextStyle(color: _G.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _savingEmail
                      ? null
                      : () => setState(() {
                          _editingEmail = false;
                          _emailErr = null;
                          _emailMsg = null;
                          _emailPwCtrl.clear();
                          _showEmailPw = false;
                          _emailCtrl.text = _originalEmail;
                        }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: _G.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _primaryBtn(
                  label: 'Send Verification',
                  icon: Icons.send_rounded,
                  color: _G.accentViolet,
                  onTap: _savingEmail ? null : _changeEmail,
                  loading: _savingEmail,
                ),
              ],
            ),
          ] else if (_verificationPending) ...[
            const SizedBox(height: 10),
            _banner(
              'Verification email sent to $_pendingNewEmail.\nClick the link in your inbox, then tap "I\'ve Verified" below.',
              false,
            ),
            if (_emailErr != null) ...[
              const SizedBox(height: 8),
              _banner(_emailErr!, true),
            ],
            const SizedBox(height: 10),
            Row(
              children: const [
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _G.accentViolet,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  'Waiting for verification…',
                  style: TextStyle(color: _G.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _checkingVerification
                      ? null
                      : () => setState(() {
                          _verificationPending = false;
                          _pendingNewEmail = '';
                          _pendingPassword = '';
                          _emailErr = null;
                          _emailCtrl.text = _originalEmail;
                        }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: _G.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _primaryBtn(
                  label: "I've Verified",
                  icon: Icons.verified_rounded,
                  color: _G.accentViolet,
                  onTap: _checkingVerification ? null : _checkVerification,
                  loading: _checkingVerification,
                ),
              ],
            ),
          ],

          if (_emailMsg != null) ...[
            const SizedBox(height: 8),
            _banner(_emailMsg!, false),
          ],

          const SizedBox(height: 22),

          // ── Change Password ───────────────────────────────────
          _sectionHeader(
            'Change Password',
            Icons.lock_outline_rounded,
            _G.accentEmerald,
          ),
          _passwordSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Step Chip ─────────────────────────────────────────────────────────────────

class _StepChip extends StatelessWidget {
  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  const _StepChip({
    required this.number,
    required this.label,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    Color dotBg, dotFg, labelColor;
    if (isDone) {
      dotBg = _G.accentEmerald;
      dotFg = Colors.white;
      labelColor = _G.accentEmerald;
    } else if (isActive) {
      dotBg = _G.activeBtn;
      dotFg = _G.activeBtnText;
      labelColor = _G.activeBtn;
    } else {
      dotBg = Colors.transparent;
      dotFg = _G.textMuted;
      labelColor = _G.textMuted;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotBg,
            border: Border.all(
              color: isDone
                  ? _G.accentEmerald
                  : isActive
                  ? _G.activeBtn
                  : Colors.white.withValues(alpha: 0.20),
              width: 1.8,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: dotFg,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Feedback — Order Reviews
// ══════════════════════════════════════════════════════════════════════════════

class _FeedbackContent extends StatelessWidget {
  final String uid, fullName;
  const _FeedbackContent({required this.uid, required this.fullName});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Reviews',
          style: TextStyle(
            color: _G.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Rate your completed orders',
          style: TextStyle(color: _G.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Orders')
                .where('customer_uid', isEqualTo: uid)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _G.activeBtn,
                    strokeWidth: 2,
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.rate_review_outlined,
                          size: 36,
                          color: _G.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No completed orders yet',
                        style: TextStyle(color: _G.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Reviews will appear here once your orders are completed',
                        style: TextStyle(color: _G.textMuted, fontSize: 11),
                        textAlign: TextAlign.center,
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
                  final orderId = d['order_id']?.toString() ?? docs[i].id;
                  final products = List<Map>.from(d['products'] ?? []);
                  final productName = products.isNotEmpty
                      ? products.first['name']?.toString() ?? ''
                      : '';
                  return _ReviewOrderCard(
                    orderId: orderId,
                    productName: productName,
                    totalPrice: d['total_price'],
                    hasReview: d['has_review'] == true,
                    uid: uid,
                    fullName: fullName,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReviewOrderCard extends StatelessWidget {
  final String orderId, productName, uid, fullName;
  final dynamic totalPrice;
  final bool hasReview;

  const _ReviewOrderCard({
    required this.orderId,
    required this.productName,
    required this.totalPrice,
    required this.hasReview,
    required this.uid,
    required this.fullName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _G.lightCard(radius: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _G.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: _G.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (productName.isNotEmpty)
                  Text(
                    productName,
                    style: const TextStyle(color: _G.textMuted, fontSize: 11),
                  ),
                if (totalPrice != null)
                  Text(
                    '₱$totalPrice',
                    style: const TextStyle(
                      color: _G.accentAmber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasReview)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: _G.pill(tint: _G.accentEmerald),
              child: const Text(
                'Reviewed ✓',
                style: TextStyle(
                  color: _G.accentEmerald,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => _ReviewDialog(
                  orderId: orderId,
                  productName: productName,
                  uid: uid,
                  fullName: fullName,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _G.activeBtn,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: _G.activeBtn.withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Leave Review',
                  style: TextStyle(
                    color: _G.activeBtnText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final String orderId, productName, uid, fullName;
  const _ReviewDialog({
    required this.orderId,
    required this.productName,
    required this.uid,
    required this.fullName,
  });

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 0;
  final _msgCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating.')));
      return;
    }
    setState(() => _submitting = true);
    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('User').doc(widget.uid).get();
    final customerId = userDoc.data()?['customer_id']?.toString() ?? '';

    await db.collection('OrderReviews').add({
      'order_id': widget.orderId,
      'customer_uid': widget.uid,
      'customer_id': customerId,
      'customer_name': widget.fullName,
      'product_name': widget.productName,
      'rating': _rating,
      'message': _msgCtrl.text.trim(),
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
    await db.collection('Orders').doc(widget.orderId).update({
      'has_review': true,
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color.fromARGB(
                255,
                12,
                9,
                31,
              ).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leave a Review',
                  style: TextStyle(
                    color: _G.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.orderId,
                  style: const TextStyle(color: _G.textMuted, fontSize: 12),
                ),
                if (widget.productName.isNotEmpty)
                  Text(
                    widget.productName,
                    style: const TextStyle(color: _G.accentAmber, fontSize: 12),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Rating',
                  style: TextStyle(
                    color: _G.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = star),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          star <= _rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: star <= _rating
                              ? _G.accentAmber
                              : Colors.white.withValues(alpha: 0.20),
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your Review',
                  style: TextStyle(
                    color: _G.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: _G.lightCard(radius: 10),
                  child: TextField(
                    controller: _msgCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: _G.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'How was your experience with this order?',
                      hintStyle: TextStyle(color: _G.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.9,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: _G.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _submitting ? null : _submit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _submitting
                                ? Colors.white.withValues(alpha: 0.05)
                                : _G.activeBtn,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _G.activeBtnText,
                                    ),
                                  )
                                : const Text(
                                    'Submit',
                                    style: TextStyle(
                                      color: _G.activeBtnText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
