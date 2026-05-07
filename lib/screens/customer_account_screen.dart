import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'chat_screen.dart';

// ── Root ──────────────────────────────────────────────────────────────────────

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  String _menu     = 'dashboard';
  String fullName  = '';
  String email     = '';
  String customerId = '';

  static const _menus = [
    ('dashboard', 'Dashboard',      Icons.dashboard_outlined),
    ('orders',    'Orders',         Icons.receipt_long_outlined),
    ('messages',  'Messages',       Icons.chat_bubble_outline),
    ('manage',    'Manage Account', Icons.manage_accounts_outlined),
    ('feedback',  'Feedback',       Icons.star_outline),
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
        fullName   = doc.data()?['full_name'] ?? '';
        email      = doc.data()?['email'] ?? user.email ?? '';
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

  Widget _content() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    switch (_menu) {
      case 'orders':
        return _OrdersContent(uid: uid);
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
          onViewOrders:   () => setState(() => _menu = 'orders'),
          onViewMessages: () => setState(() => _menu = 'messages'),
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
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.person, size: 36, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  fullName.isNotEmpty ? fullName : 'Customer',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
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
                const SizedBox(height: 20),
                ..._menus.map((m) => _SidebarBtn(
                      label:    m.$2,
                      icon:     m.$3,
                      isActive: _menu == m.$1,
                      onTap:    () => setState(() => _menu = m.$1),
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
                    label: const Text('Logout',
                        style: TextStyle(fontSize: 13)),
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
                    child: const Icon(Icons.person,
                        color: Colors.white60, size: 20),
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
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(email,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
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
                                color: active
                                    ? AppTheme.gold
                                    : Colors.white60),
                            const SizedBox(width: 6),
                            Text(
                              m.$2,
                              style: TextStyle(
                                color:
                                    active ? AppTheme.gold : Colors.white70,
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
  const _SidebarBtn(
      {required this.label,
      required this.icon,
      required this.isActive,
      required this.onTap});

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
            padding:
                const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
          ),
          icon: Icon(icon, size: 16),
          label: Text(label,
              style: const TextStyle(
                  fontSize: 13, overflow: TextOverflow.ellipsis)),
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
  const _DashboardContent({
    required this.uid,
    required this.onViewOrders,
    required this.onViewMessages,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 360;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dashboard',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isNarrow ? 17 : 20,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: isNarrow ? 12 : 16),
            _OrderStatsRow(uid: uid),
            SizedBox(height: isNarrow ? 16 : 24),
            _UnreadMessagesPreview(uid: uid, onViewAll: onViewMessages),
          ],
        ),
      );
    });
  }
}

class _OrderStatsRow extends StatelessWidget {
  final String uid;
  const _OrderStatsRow({required this.uid});

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
            if (s == 'pending')          pending++;
            if (s == 'in_production')    active++;
            if (s == 'ready_for_pickup') ready++;
          }
        }
        return LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StatCard('Pending\nOrders', pending, Icons.sync,                Colors.red,    compact: compact)),
                SizedBox(width: compact ? 4 : 8),
                Expanded(child: _StatCard('Active\nOrders',  active,  Icons.inventory_2_outlined, Colors.orange, compact: compact)),
                SizedBox(width: compact ? 4 : 8),
                Expanded(child: _StatCard('Ready for\nPickup', ready, Icons.check_circle,       Colors.green,  compact: compact)),
              ],
            ),
          );
        });
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
  const _StatCard(this.label, this.count, this.icon, this.color, {this.compact = false});

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(color: Colors.white60, fontSize: compact ? 10 : 12)),
        ],
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
                (((d.data() as Map)['unread_customer'] as num?) ?? 0)
                    .toInt());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: docs.isNotEmpty ? onViewAll : null,
              child: Row(
                children: [
                  const Text('Unread Messages',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$totalUnread',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        color: Colors.white54, size: 16),
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
                  child: Text('No unread messages',
                      style:
                          TextStyle(color: Colors.white38, fontSize: 13)),
                ),
              )
            else
              ...docs.map((doc) {
                final d           = doc.data() as Map<String, dynamic>;
                final orderId     = d['order_id']?.toString() ?? '';
                final orderDisplay =
                    d['order_display']?.toString() ?? orderId;
                final lastMsg     = d['last_message']?.toString() ?? '';
                final unread      = d['unread_customer'] ?? 0;
                return _UnreadMessageCard(
                  orderId:      orderId,
                  orderDisplay: orderDisplay,
                  lastMsg:      lastMsg,
                  unread:       unread,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        customerUid:  uid,
                        customerName: '',
                        isEmployee:   false,
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
  const _UnreadMessageCard(
      {required this.orderId,
      required this.orderDisplay,
      required this.lastMsg,
      required this.unread,
      required this.onTap});

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
                Text(orderDisplay,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (lastMsg.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(lastMsg,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
            child: Text('$unread new',
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 11)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('View',
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
  const _OrdersContent({required this.uid});

  @override
  State<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<_OrdersContent> {
  String _filter = 'pending';

  static const _filters = [
    ('pending',          'Pending'),
    ('in_production',    'Active'),
    ('ready_for_pickup', 'Ready'),
    ('cancelled',        'Cancelled'),
    ('completed',        'History'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Orders',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
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
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.gold.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active
                            ? AppTheme.gold.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(f.$2,
                      style: TextStyle(
                          color: active ? AppTheme.gold : Colors.white70,
                          fontSize: 12,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal)),
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
                    child:
                        CircularProgressIndicator(color: Colors.white38));
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    'Could not load orders.\nCheck your connection.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13),
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
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13),
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
  const _OrderCard(
      {required this.orderId, required this.data, required this.showMessage});

  @override
  Widget build(BuildContext context) {
    final status   = data['status']?.toString() ?? '';
    final products = List<Map>.from(data['products'] ?? []);
    final total    = data['total_price'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order # + status badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(orderId,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const SizedBox(width: 6),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          // Products list
          ...products.map((p) {
            final name = p['name']?.toString() ?? '';
            final qty  = p['qty'] ?? p['quantity'] ?? 0;
            final pr   = p['price'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      size: 5, color: Colors.white38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('$name × $qty',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (pr != null) ...[
                    const SizedBox(width: 6),
                    Text('₱$pr',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ],
              ),
            );
          }),
          const Divider(color: Colors.white12, height: 14),
          // Total + message button
          Row(
            children: [
              const Text('Total: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              Expanded(
                child: Text(
                  total != null ? '₱$total' : '—',
                  style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showMessage)
                TextButton.icon(
                  onPressed: () {
                    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          customerUid:  uid,
                          customerName: '',
                          isEmployee:   false,
                          orderContext: {
                            'order_id':    orderId,
                            'products':    products,
                            'total_price': total,
                          },
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 13),
                  label: const Text('Message',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
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
        color = Colors.orangeAccent; label = 'Pending'; break;
      case 'in_production':
        color = Colors.blueAccent; label = 'In Production'; break;
      case 'ready_for_pickup':
        color = Colors.greenAccent; label = 'Ready for Pickup'; break;
      case 'cancelled':
        color = Colors.redAccent; label = 'Cancelled'; break;
      case 'completed':
        color = Colors.white54; label = 'Completed'; break;
      default:
        color = Colors.white38; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
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
        .collection('User').doc(widget.uid).get();
    final name = userDoc.data()?['full_name'] ?? 'Customer';
    await ref.set({
      'customer_uid':    widget.uid,
      'customer_name':   name,
      'last_message':    '',
      'last_updated':    FieldValue.serverTimestamp(),
      'unread_customer': 0,
      'unread_employee': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Messages',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
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
                  child: Text('Could not load messages.',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                );
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white38));
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
                    child: CircularProgressIndicator(color: Colors.white38));
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d       = docs[i].data() as Map<String, dynamic>;
                  final lastMsg = d['last_message']?.toString() ?? '';
                  final unread  = ((d['unread_customer'] as num?) ?? 0).toInt();
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          customerUid:  widget.uid,
                          customerName: '',
                          isEmployee:   false,
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
                                  color: AppTheme.gold.withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.local_print_shop,
                                color: AppTheme.gold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Imprenta Inc.',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                const Text('Printing Services',
                                    style: TextStyle(
                                        color: AppTheme.gold, fontSize: 11)),
                                if (lastMsg.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(lastMsg,
                                      style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
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
                                child: Text('$unread',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: Colors.white30, size: 18),
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
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _curPwCtrl   = TextEditingController();
  final _newPwCtrl   = TextEditingController();
  final _confPwCtrl  = TextEditingController();

  bool _showCur = false, _showNew = false, _showConf = false;
  bool _savingInfo = false, _savingPw = false;
  bool _loading = true;
  String? _infoMsg, _infoErr, _pwMsg, _pwErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _curPwCtrl.dispose(); _newPwCtrl.dispose(); _confPwCtrl.dispose();
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
        _nameCtrl.text  = doc.data()?['full_name'] ?? user.displayName ?? '';
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
      setState(() { _infoErr = 'Name cannot be empty.'; _infoMsg = null; });
      return;
    }
    setState(() { _savingInfo = true; _infoErr = null; _infoMsg = null; });
    try {
      await FirebaseFirestore.instance
          .collection('User')
          .doc(user.uid)
          .update({'full_name': name});
      await user.updateDisplayName(name);
      widget.onNameUpdated(name);
      if (mounted) setState(() { _infoMsg = 'Name updated.'; _savingInfo = false; });
    } catch (e) {
      if (mounted) setState(() { _infoErr = 'Failed: $e'; _savingInfo = false; });
    }
  }

  Future<void> _changePw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final cur  = _curPwCtrl.text.trim();
    final nw   = _newPwCtrl.text.trim();
    final conf = _confPwCtrl.text.trim();
    if (cur.isEmpty || nw.isEmpty || conf.isEmpty) {
      setState(() { _pwErr = 'Fill in all password fields.'; _pwMsg = null; }); return;
    }
    if (nw.length < 6) {
      setState(() { _pwErr = 'New password must be at least 6 characters.'; _pwMsg = null; }); return;
    }
    if (nw != conf) {
      setState(() { _pwErr = 'Passwords do not match.'; _pwMsg = null; }); return;
    }
    setState(() { _savingPw = true; _pwErr = null; _pwMsg = null; });
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: cur);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(nw);
      if (mounted) {
        setState(() {
          _pwMsg = 'Password changed successfully.';
          _savingPw = false;
          _curPwCtrl.clear(); _newPwCtrl.clear(); _confPwCtrl.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
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
      return const Center(child: CircularProgressIndicator(color: Colors.white38));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage Account',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _section('Personal Information'),
          const SizedBox(height: 12),
          _field(label: 'Full Name', ctrl: _nameCtrl),
          const SizedBox(height: 10),
          _field(label: 'Email', ctrl: _emailCtrl, readOnly: true),
          const SizedBox(height: 4),
          const Text('Email cannot be changed.',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          if (_infoMsg != null) ...[const SizedBox(height: 8), _banner(_infoMsg!, false)],
          if (_infoErr != null) ...[const SizedBox(height: 8), _banner(_infoErr!, true)],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingInfo ? null : _saveName,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold, foregroundColor: Colors.black, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: _savingInfo
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                  : const Text('Save Name', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          _section('Change Password'),
          const SizedBox(height: 12),
          _pwField(label: 'Current Password', ctrl: _curPwCtrl, show: _showCur,
              toggle: () => setState(() => _showCur = !_showCur)),
          const SizedBox(height: 10),
          _pwField(label: 'New Password', ctrl: _newPwCtrl, show: _showNew,
              toggle: () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 10),
          _pwField(label: 'Confirm New Password', ctrl: _confPwCtrl, show: _showConf,
              toggle: () => setState(() => _showConf = !_showConf)),
          if (_pwMsg != null) ...[const SizedBox(height: 8), _banner(_pwMsg!, false)],
          if (_pwErr != null) ...[const SizedBox(height: 8), _banner(_pwErr!, true)],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingPw ? null : _changePw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold, foregroundColor: Colors.black, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
              child: _savingPw
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                  : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Row(children: [
    Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.2))),
  ]);

  Widget _field({required String label, required TextEditingController ctrl, bool readOnly = false}) =>
    TextField(
      controller: ctrl,
      readOnly: readOnly,
      style: TextStyle(color: readOnly ? Colors.white54 : Colors.white, fontSize: 14),
      decoration: AppTheme.inputDecoration(label),
    );

  Widget _pwField({required String label, required TextEditingController ctrl,
      required bool show, required VoidCallback toggle}) =>
    TextField(
      controller: ctrl,
      obscureText: !show,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: AppTheme.inputDecoration(label,
          icon: Icons.lock_outline,
          suffixIcon: IconButton(
            icon: Icon(show ? Icons.visibility : Icons.visibility_off,
                color: Colors.white54, size: 18),
            onPressed: toggle,
          )),
    );

  Widget _banner(String msg, bool isError) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.redAccent : Colors.greenAccent, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Text(msg,
          style: TextStyle(
              color: isError ? Colors.redAccent : Colors.greenAccent,
              fontSize: 12))),
    ]),
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
        const Text('Order Reviews',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Rate your completed orders',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                    child:
                        CircularProgressIndicator(color: Colors.white38));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('No completed orders yet',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                          'Reviews will appear here once your orders are completed',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 11),
                          textAlign: TextAlign.center),
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
                    orderId:     orderId,
                    productName: productName,
                    totalPrice:  d['total_price'],
                    hasReview:   d['has_review'] == true,
                    uid:         uid,
                    fullName:    fullName,
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
          const Icon(Icons.receipt_long_outlined,
              color: Colors.white54, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderId,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (productName.isNotEmpty)
                  Text(productName,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                if (totalPrice != null)
                  Text('₱$totalPrice',
                      style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasReview)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: const Text('Reviewed ✓',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            )
          else
            ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _ReviewDialog(
                  orderId:     orderId,
                  productName: productName,
                  uid:         uid,
                  fullName:    fullName,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
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
  int  _rating    = 0;
  final _msgCtrl  = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a rating.')));
      return;
    }
    setState(() => _submitting = true);
    final db = FirebaseFirestore.instance;
    await db.collection('OrderReviews').add({
      'order_id':      widget.orderId,
      'customer_uid':  widget.uid,
      'customer_name': widget.fullName,
      'product_name':  widget.productName,
      'rating':        _rating,
      'message':       _msgCtrl.text.trim(),
      'read':          false,
      'created_at':    FieldValue.serverTimestamp(),
    });
    await db
        .collection('Orders')
        .doc(widget.orderId)
        .update({'has_review': true});
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
            const Text('Leave a Review',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.orderId,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12)),
            if (widget.productName.isNotEmpty)
              Text(widget.productName,
                  style: const TextStyle(
                      color: AppTheme.gold, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Rating',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
                          ? AppTheme.gold
                          : Colors.white30,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Your Review',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: AppTheme.inputDecoration(
                  'How was your experience with this order?'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54)),
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
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Submit',
                            style:
                                TextStyle(fontWeight: FontWeight.bold)),
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
