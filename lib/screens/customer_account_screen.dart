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

// ── Root ──────────────────────────────────────────────────────────────────────

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  String _menu = 'dashboard';
  String _ordersFilter =
      'pending'; // pre-selected when navigating from dashboard
  String fullName = '';
  String email = '';
  String customerId = '';

  static const _menus = [
    ('dashboard', 'Dashboard', Icons.dashboard_outlined),
    ('orders', 'Orders', Icons.receipt_long_outlined),
    ('messages', 'Messages', Icons.chat_bubble_outline),
    ('manage', 'Profile', Icons.manage_accounts_outlined),
    ('feedback', 'Feedback', Icons.star_outline),
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
          onViewOrders: () => _goToOrders('pending'),
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
        return isWide ? _wideLayout() : _narrowLayout();
      },
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
                // Avatar + name
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 36,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  fullName.isNotEmpty ? fullName : 'Customer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (customerId.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'ID: $customerId',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
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
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: const Icon(Icons.logout, size: 15),
                    label: const Text('Logout', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCard(opacity: 0.15),
              child: _content(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ───────────────────────────────────────────────────────────

  Widget _narrowLayout() {
    return Column(
      children: [
        // Compact header
        Container(
          color: Colors.white.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white60,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : 'Customer',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (customerId.isNotEmpty)
                          Text(
                            'ID: $customerId',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              letterSpacing: 0.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _logout,
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Horizontal scrollable tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _menus.map((m) {
                    final active = _menu == m.$1;
                    return GestureDetector(
                      onTap: () => setState(() => _menu = m.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
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
                            Icon(
                              m.$3,
                              size: 14,
                              color: active ? AppTheme.gold : Colors.white60,
                            ),
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
        // Content — reduced padding for narrow screens
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassCard(opacity: 0.15),
              child: _content(),
            ),
          ),
        ),
      ],
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
                  color: Colors.white,
                  fontSize: isNarrow ? 17 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isNarrow ? 12 : 16),
              _OrderStatsRow(uid: uid, onFilter: onViewOrdersFiltered),
              SizedBox(height: isNarrow ? 16 : 24),
              _UnreadMessagesPreview(uid: uid, onViewAll: onViewMessages),
            ],
          ),
        );
      },
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
                      'Pending\nOrders',
                      pending,
                      Icons.sync,
                      Colors.red,
                      compact: compact,
                      onTap: () => onFilter('pending'),
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 8),
                  Expanded(
                    child: _StatCard(
                      'Active\nOrders',
                      active,
                      Icons.inventory_2_outlined,
                      Colors.orange,
                      compact: compact,
                      onTap: () => onFilter('in_production'),
                    ),
                  ),
                  SizedBox(width: compact ? 4 : 8),
                  Expanded(
                    child: _StatCard(
                      'Ready for\nPickup',
                      ready,
                      Icons.check_circle,
                      Colors.green,
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
  const _StatCard(
    this.label,
    this.count,
    this.icon,
    this.color, {
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: AppTheme.glassCard(opacity: 0.12, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: compact ? 20 : 28),
            SizedBox(height: compact ? 6 : 10),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: compact ? 20 : 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white60,
                fontSize: compact ? 10 : 12,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(height: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: Colors.white.withValues(alpha: 0.3),
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
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalUnread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
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
                decoration: AppTheme.glassCard(opacity: 0.1),
                child: const Center(
                  child: Text(
                    'No unread messages',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
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
      decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderDisplay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (lastMsg.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    lastMsg,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$unread new',
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'View',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Orders
// ══════════════════════════════════════════════════════════════════════════════

class _OrdersContent extends StatefulWidget {
  final String uid;
  final String initialFilter;
  const _OrdersContent({required this.uid, this.initialFilter = 'pending'});

  @override
  State<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<_OrdersContent> {
  late String _filter = widget.initialFilter;

  static const _filters = [
    ('pending', 'Pending'),
    ('in_production', 'Active'),
    ('ready', 'Ready'), // was 'ready_for_pickup' — fixed
    ('cancelled', 'Cancelled'),
    ('completed', 'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orders',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
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
                    vertical: 7,
                  ),
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
                  child: Text(
                    f.$2,
                    style: TextStyle(
                      color: active ? AppTheme.gold : Colors.white70,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // No orderBy here — avoids the composite-index requirement.
            // We sort client-side after fetching.
            stream: FirebaseFirestore.instance
                .collection('Orders')
                .where('customer_uid', isEqualTo: widget.uid)
                .where('status', isEqualTo: _filter)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
                );
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Could not load orders.\nCheck your connection.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                );
              }
              // Sort newest-first client-side
              final docs = List.from(snap.data?.docs ?? [])
                ..sort((a, b) {
                  final aTs = (a.data() as Map)['created_at'];
                  final bTs = (b.data() as Map)['created_at'];
                  if (aTs == null || bTs == null) return 0;
                  return (bTs as dynamic).compareTo(aTs);
                });
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No ${_filters.firstWhere((f) => f.$1 == _filter).$2.toLowerCase()} orders',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return _OrderCard(
                    orderId: d['order_id']?.toString() ?? docs[i].id,
                    data: d,
                    showMessage: _filter != 'cancelled',
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
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
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
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(opacity: 0.13, radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order # + status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    orderId,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),

            // Products list
            ...products.map((p) {
              final name = p['name']?.toString() ?? '';
              final qty = p['qty'] ?? p['quantity'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      size: 5,
                      color: Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$name × $qty',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(color: Colors.white12, height: 14),

            // Balance row
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.bold,
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
                          color: fullyPaid ? Colors.green : Colors.orange,
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
                      TextButton.icon(
                        onPressed: () {
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
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 13),
                        label: const Text(
                          'Message',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),

            // Progress bar — only when payment tracking is active
            if (total > 0 && paid > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fullyPaid ? Colors.green : AppTheme.gold,
                  ),
                  minHeight: 4,
                ),
              ),
            ],

            // Tap hint
            const SizedBox(height: 6),
            Text(
              'Tap to view details & payment QR',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Account order detail sheet (full detail + QR + pay) ──────────────────────

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
      // Always create a fresh link — never reuse stored URLs.
      // Stored URLs may be from a different API environment (test vs live)
      // and will show "Invalid Request" even when link status is 'unpaid'.
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
            checkoutUrl:      checkoutUrl,
            linkId:           linkId,
            orderId:          orderId,
            payAmount:        chosen,
            isBalancePayment: !isInitial,
          ),
        ),
      );

      if (paid == true && mounted) {
        Navigator.pop(context); // close the bottom sheet
        // Navigate to invoice to show the updated payment record
        final invoiceId = widget.data['invoice_id']?.toString();
        if (invoiceId != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => InvoiceScreen(invoiceId: invoiceId, fromPayment: true),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
          ),
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
      backgroundColor: const Color(0xFF1a1a2e),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final chosen = (double.tryParse(ctrl.text) ?? maxAmt).clamp(
            minAmt,
            maxAmt,
          );
          return SafeArea(
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
                        color: Colors.white24,
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
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
                      color: AppTheme.gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppTheme.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status == 'awaiting_payment'
                                ? 'Minimum: ₱${minAmt.toStringAsFixed(2)} (50% downpayment)'
                                : 'Outstanding balance: ₱${maxAmt.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppTheme.gold,
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
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            '₱',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Colors.white24,
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
                    child: ElevatedButton.icon(
                      onPressed: chosen < minAmt - 0.009
                          ? null
                          : () => Navigator.pop(ctx, chosen),
                      icon: const Icon(Icons.payment_rounded),
                      label: Text(
                        'Pay ₱${chosen.toStringAsFixed(2)} via PayMongo',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: AppTheme.primaryButton(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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

    return DraggableScrollableSheet(
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
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.data['order_id']?.toString() ?? widget.docId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Placed ${_fmtDate(widget.data['created_at'])}',
                      style: const TextStyle(
                        color: Colors.white38,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.gold.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    color: AppTheme.gold,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Est. turnaround: ~$turnaround day${turnaround == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Products
          const Text(
            'Items',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
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
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
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
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₱$price',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(color: Colors.white12, height: 24),

          // Balance
          _BalRow('Order Total', _total, Colors.white),
          const SizedBox(height: 6),
          _BalRow('Paid', _paid, Colors.green),
          const SizedBox(height: 6),
          _BalRow(
            fullyPaid ? 'Fully Paid' : 'Balance Due on Pickup',
            fullyPaid ? 0 : remaining,
            fullyPaid ? Colors.green : AppTheme.gold,
            large: true,
          ),
          if (!fullyPaid) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total > 0 ? (_paid / _total).clamp(0, 1) : 0,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                minHeight: 5,
              ),
            ),
          ],

          // Pay button
          if (showPayBtn) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _payingNow ? null : _payNow,
                icon: _payingNow
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.payment_rounded),
                label: Text(
                  _status == 'awaiting_payment'
                      ? 'Pay via PayMongo (min 50%)'
                      : 'Pay Remaining ₱${remaining.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                style: AppTheme.primaryButton(),
              ),
            ),
          ],

          // Invoice button
          if (invoiceId != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => InvoiceScreen(invoiceId: invoiceId),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.gold,
                ),
                label: const Text(
                  'View Invoice',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
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
            color: Colors.white70,
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
          fontWeight: large ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    ],
  );
}

// ── QR code section (account screen version) ─────────────────────────────────

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
  bool _stale      = false;
  bool _validating = true;

  @override
  void initState() {
    super.initState();
    // Validate on load for ALL statuses — awaiting_payment links expire too.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _validateStoredLink(),
    );
  }

  Future<void> _validateStoredLink() async {
    final isInitial = widget.status == 'awaiting_payment';
    final linkId = isInitial
        ? widget.order['paymongo_link_id'] as String?
        : widget.order['balance_link_id']  as String?;
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
              'paymongo_link_id':      FieldValue.delete(),
              'paymongo_checkout_url': FieldValue.delete(),
            })
            .catchError((_) {});
      } else {
        FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .update({
              'balance_link_id':      FieldValue.delete(),
              'balance_checkout_url': FieldValue.delete(),
              'balance_link_amount':  FieldValue.delete(),
            })
            .catchError((_) {});
      }
      if (mounted) await _generate();
    }
  }

  String? get _url {
    if (_validating) return null; // never expose old URL before validation
    if (_stale) return _localUrl;
    return _localUrl ??
        (widget.status == 'awaiting_payment'
            ? widget.order['paymongo_checkout_url'] as String?
            : widget.order['balance_checkout_url'] as String?);
  }

  Future<void> _applyQrPayment(String paidLinkId) async {
    final orderId   = widget.order['order_id']?.toString() ?? widget.docId;
    final paid      = (widget.order['balance_link_amount'] as num?)?.toDouble() ?? 0;
    if (paid <= 0) return;
    final oldPaid   = (widget.order['amount_paid']       as num?)?.toDouble() ?? 0;
    final newPaid   = oldPaid + paid;
    final newRemain = ((widget.order['remaining_balance'] as num?)?.toDouble() ?? 0) - paid;
    final fullyPaid = newRemain < 0.01;

    await FirebaseFirestore.instance.collection('Orders').doc(orderId).update({
      'amount_paid':          newPaid,
      'remaining_balance':    newRemain.clamp(0.0, double.infinity),
      'payment_status':       fullyPaid ? 'paid' : 'partial',
      if (fullyPaid) 'fully_paid_at': FieldValue.serverTimestamp(),
      'balance_link_id':      FieldValue.delete(),
      'balance_checkout_url': FieldValue.delete(),
      'balance_link_amount':  FieldValue.delete(),
    }).catchError((_) {});

    await FirebaseFirestore.instance.collection('Payments').doc().set({
      'order_id':             orderId,
      'amount':               paid,
      'payment_type':         'balance',
      'payment_method':       'online',
      'transaction_reference': paidLinkId,
      'payment_date':         FieldValue.serverTimestamp(),
      'status':               'paid',
    }).catchError((_) {});

    if (!fullyPaid && mounted) {
      setState(() => _stale = true);
      await _generate();
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final orderId   = widget.order['order_id']?.toString() ?? widget.docId;
      final isInitial = widget.status == 'awaiting_payment';
      final total     = (widget.order['total_price'] as num?)?.toDouble() ?? 0;
      final amount    = isInitial
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
              'paymongo_link_id':      link.id,
              'paymongo_checkout_url': link.checkoutUrl,
            }
          : {
              'balance_link_id':      link.id,
              'balance_checkout_url': link.checkoutUrl,
              'balance_link_amount':  amount,
            };

      await Future.wait([
        FirebaseFirestore.instance.collection('PayMongoLinks').doc(link.id).set({
          'order_id':        orderId,
          'purpose':         isInitial ? 'downpayment' : 'balance',
          'expected_amount': amount,
          'processed':       false,
          'created_at':      FieldValue.serverTimestamp(),
        }),
        FirebaseFirestore.instance
            .collection('Orders')
            .doc(orderId)
            .update(orderUpdates),
      ]);
      if (mounted) setState(() { _localUrl = link.checkoutUrl; _validating = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _validating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
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

    // Show spinner while validating or regenerating — never show an expired URL
    if (_validating || (_generating && url == null)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.gold),
        ),
      );
    }

    if (url == null && widget.status != 'awaiting_payment') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Generate a QR code so you or anyone can scan and pay the remaining balance.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.gold,
                        ),
                      )
                    : const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppTheme.gold,
                        size: 16,
                      ),
                label: Text(
                  _generating ? 'Generating…' : 'Generate Payment QR',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                color: AppTheme.gold,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                widget.status == 'awaiting_payment'
                    ? 'SCAN TO PAY DOWNPAYMENT'
                    : 'SCAN TO PAY REMAINING BALANCE',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
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
              ),
              child: QrImageView(
                data: url,
                size: 180,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0f0f23),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0f0f23),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Opens PayMongo → GCash / Maya / Card',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 2),
          const Text(
            'This QR is unique to this order and safe to share.',
            style: TextStyle(color: Colors.white24, fontSize: 10),
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
        color = Colors.orangeAccent;
        label = 'Pending';
        break;
      case 'in_production':
        color = Colors.blueAccent;
        label = 'In Production';
        break;
      case 'ready_for_pickup':
        color = Colors.greenAccent;
        label = 'Ready for Pickup';
        break;
      case 'cancelled':
        color = Colors.redAccent;
        label = 'Cancelled';
        break;
      case 'completed':
        color = Colors.white54;
        label = 'Completed';
        break;
      default:
        color = Colors.white38;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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

  // Silently creates a general chat thread on first visit so the
  // customer can reach the team even without a placed order.
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // No orderBy — avoids composite index requirement.
            // Sort by last_updated client-side.
            stream: FirebaseFirestore.instance
                .collection('Messages')
                .where('customer_uid', isEqualTo: widget.uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(
                  child: Text(
                    'Could not load messages.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                );
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white38),
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
                  child: CircularProgressIndicator(color: Colors.white38),
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
                      decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.gold.withValues(alpha: 0.15),
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.local_print_shop,
                              color: AppTheme.gold,
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
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  'Printing Services',
                                  style: TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 11,
                                  ),
                                ),
                                if (lastMsg.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    lastMsg,
                                    style: const TextStyle(
                                      color: Colors.white54,
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
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent,
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
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white30,
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
// Manage Account
// ══════════════════════════════════════════════════════════════════════════════

class _ManageAccountContent extends StatefulWidget {
  final void Function(String) onNameUpdated;
  const _ManageAccountContent({required this.onNameUpdated});

  @override
  State<_ManageAccountContent> createState() => _ManageAccountContentState();
}

class _ManageAccountContentState extends State<_ManageAccountContent> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _curPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confPwCtrl = TextEditingController();

  bool _showCur = false, _showNew = false, _showConf = false;
  bool _savingInfo = false, _savingPw = false, _savingEmail = false;
  bool _loading = true;
  String? _infoMsg, _infoErr, _pwMsg, _pwErr, _emailMsg, _emailErr;

  final _emailPwCtrl = TextEditingController();
  bool _showEmailPw = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _curPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    _emailPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
        _loading = false;
      });
    }
  }

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
          _infoMsg = 'Name updated.';
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

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newEmail = _emailCtrl.text.trim();
    final pw = _emailPwCtrl.text.trim();
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
    if (pw.isEmpty) {
      setState(() {
        _emailErr = 'Enter your current password to confirm.';
        _emailMsg = null;
      });
      return;
    }
    if (newEmail == user.email) {
      setState(() {
        _emailErr = 'That is already your current email.';
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
        password: pw,
      );
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);
      await FirebaseFirestore.instance.collection('User').doc(user.uid).update({
        'email': newEmail,
      });
      if (mounted) {
        setState(() {
          _emailMsg =
              'Verification email sent to $newEmail. Please verify to complete the change.';
          _savingEmail = false;
          _emailPwCtrl.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() {
          _emailErr = e.code == 'wrong-password'
              ? 'Current password is incorrect.'
              : (e.message ?? 'Failed to update email.');
          _savingEmail = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _emailErr = 'Failed: $e';
          _savingEmail = false;
        });
    }
  }

  Future<void> _changePw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final cur = _curPwCtrl.text.trim();
    final nw = _newPwCtrl.text.trim();
    final conf = _confPwCtrl.text.trim();
    if (cur.isEmpty || nw.isEmpty || conf.isEmpty) {
      setState(() {
        _pwErr = 'Fill in all password fields.';
        _pwMsg = null;
      });
      return;
    }
    if (nw.length < 6) {
      setState(() {
        _pwErr = 'New password must be at least 6 characters.';
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
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: cur,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(nw);
      if (mounted) {
        setState(() {
          _pwMsg = 'Password changed successfully.';
          _savingPw = false;
          _curPwCtrl.clear();
          _newPwCtrl.clear();
          _confPwCtrl.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        setState(() {
          _pwErr = e.code == 'wrong-password'
              ? 'Current password is incorrect.'
              : (e.message ?? 'Failed.');
          _savingPw = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white38),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _section('Personal Information'),
          const SizedBox(height: 12),
          _field(label: 'Full Name', ctrl: _nameCtrl),
          const SizedBox(height: 10),
          _field(label: 'Email', ctrl: _emailCtrl),
          const SizedBox(height: 10),
          _pwField(
            label: 'Current Password (to confirm email change)',
            ctrl: _emailPwCtrl,
            show: _showEmailPw,
            toggle: () => setState(() => _showEmailPw = !_showEmailPw),
          ),
          const SizedBox(height: 4),
          const Text(
            'A verification link will be sent to your new email.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          if (_emailMsg != null) ...[
            const SizedBox(height: 8),
            _banner(_emailMsg!, false),
          ],
          if (_emailErr != null) ...[
            const SizedBox(height: 8),
            _banner(_emailErr!, true),
          ],
          if (_infoMsg != null) ...[
            const SizedBox(height: 8),
            _banner(_infoMsg!, false),
          ],
          if (_infoErr != null) ...[
            const SizedBox(height: 8),
            _banner(_infoErr!, true),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _savingEmail ? null : _changeEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: _savingEmail
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white54,
                        ),
                      )
                    : const Text(
                        'Change Email',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _savingInfo ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                ),
                child: _savingInfo
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : const Text(
                        'Save Name',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _section('Change Password'),
          const SizedBox(height: 12),
          _pwField(
            label: 'Current Password',
            ctrl: _curPwCtrl,
            show: _showCur,
            toggle: () => setState(() => _showCur = !_showCur),
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'New Password',
            ctrl: _newPwCtrl,
            show: _showNew,
            toggle: () => setState(() => _showNew = !_showNew),
          ),
          const SizedBox(height: 10),
          _pwField(
            label: 'Confirm New Password',
            ctrl: _confPwCtrl,
            show: _showConf,
            toggle: () => setState(() => _showConf = !_showConf),
          ),
          if (_pwMsg != null) ...[
            const SizedBox(height: 8),
            _banner(_pwMsg!, false),
          ],
          if (_pwErr != null) ...[
            const SizedBox(height: 8),
            _banner(_pwErr!, true),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingPw ? null : _changePw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
              ),
              child: _savingPw
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black54,
                      ),
                    )
                  : const Text(
                      'Change Password',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
    ],
  );

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    bool readOnly = false,
  }) => TextField(
    controller: ctrl,
    readOnly: readOnly,
    style: TextStyle(
      color: readOnly ? Colors.white54 : Colors.white,
      fontSize: 14,
    ),
    decoration: AppTheme.inputDecoration(label),
  );

  Widget _pwField({
    required String label,
    required TextEditingController ctrl,
    required bool show,
    required VoidCallback toggle,
  }) => TextField(
    controller: ctrl,
    obscureText: !show,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: AppTheme.inputDecoration(
      label,
      icon: Icons.lock_outline,
      suffixIcon: IconButton(
        icon: Icon(
          show ? Icons.visibility : Icons.visibility_off,
          color: Colors.white54,
          size: 18,
        ),
        onPressed: toggle,
      ),
    ),
  );

  Widget _banner(String msg, bool isError) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.35),
      ),
    ),
    child: Row(
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.redAccent : Colors.greenAccent,
          size: 15,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(
              color: isError ? Colors.redAccent : Colors.greenAccent,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Rate your completed orders',
          style: TextStyle(color: Colors.white54, fontSize: 13),
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
                  child: CircularProgressIndicator(color: Colors.white38),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No completed orders yet',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Reviews will appear here once your orders are completed',
                        style: TextStyle(color: Colors.white24, fontSize: 11),
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
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCard(opacity: 0.12, radius: 12),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: Colors.white54,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (productName.isNotEmpty)
                  Text(
                    productName,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                if (totalPrice != null)
                  Text(
                    '₱$totalPrice',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasReview)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Text(
                'Reviewed ✓',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _ReviewDialog(
                  orderId: orderId,
                  productName: productName,
                  uid: uid,
                  fullName: fullName,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Leave Review'),
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

    // Fetch the customer_id from the User document
    final userDoc = await db.collection('User').doc(widget.uid).get();
    final customerId = userDoc.data()?['customer_id']?.toString() ?? '';

    await db.collection('OrderReviews').add({
      'order_id': widget.orderId,
      'customer_uid': widget.uid,
      'customer_id': customerId, // ← add this
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
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave a Review',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.orderId,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            if (widget.productName.isNotEmpty)
              Text(
                widget.productName,
                style: const TextStyle(color: AppTheme.gold, fontSize: 12),
              ),
            const SizedBox(height: 16),
            const Text(
              'Rating',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
                      color: star <= _rating ? AppTheme.gold : Colors.white30,
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
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: AppTheme.inputDecoration(
                'How was your experience with this order?',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: AppTheme.primaryButton(),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
