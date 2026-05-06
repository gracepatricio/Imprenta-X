import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _statuses = [
    null,
    'pending',
    'in_production',
    'ready',
    'cancelled',
    'completed',
  ];

  static const _tabLabels = [
    'All',
    'Pending',
    'In Production',
    'Ready',
    'Cancelled',
    'Completed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Orders",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Track and manage your orders",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppTheme.gold,
            unselectedLabelColor: Colors.white38,
            indicatorColor: AppTheme.gold,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2.5,
            dividerColor: Colors.white12,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            labelStyle: const TextStyle(
              fontFamily: 'Spartan',
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Spartan',
              fontSize: 13,
            ),
            tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _statuses
                  .map((s) => _OrderList(uid: uid, status: s))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OrderList extends StatelessWidget {
  final String? uid;
  final String? status;

  const _OrderList({required this.uid, required this.status});

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return const Center(
        child: Text("Not logged in", style: TextStyle(color: Colors.white54)),
      );
    }

    Query query = FirebaseFirestore.instance
        .collection('Orders')
        .where('customer_uid', isEqualTo: uid)
        .orderBy('created_at', descending: true);

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _EmptyOrders(status: status);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snapshot.data!.docs[i];
            return _OrderCard(
              docId: doc.id,
              order: doc.data() as Map<String, dynamic>,
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyOrders extends StatelessWidget {
  final String? status;
  const _EmptyOrders({required this.status});

  String get _label {
    switch (status) {
      case 'pending':        return 'pending';
      case 'in_production':  return 'in production';
      case 'ready':          return 'ready for pickup';
      case 'cancelled':      return 'cancelled';
      case 'completed':      return 'completed';
      default:               return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 60,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              status == null ? "No orders yet" : "No $_label orders",
              style: const TextStyle(color: Colors.white38, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              "Orders you place will appear here",
              style: TextStyle(color: Colors.white24, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> order;

  const _OrderCard({required this.docId, required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'pending';
    final color = _statusColor(status);

    return GestureDetector(
        onTap: () => _showOrderDetail(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassCard(opacity: 0.15, radius: 16),
          child: Row(
            children: [
              // Status icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(status), color: color, size: 20),
              ),
              const SizedBox(width: 12),

              // Order info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order['order_id']?.toString() ?? docId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (() {
                        final prods = order['products'];
                        if (prods is List && prods.isNotEmpty) {
                          return prods
                              .map((p) => p['name']?.toString() ?? '')
                              .where((n) => n.isNotEmpty)
                              .join(', ');
                        }
                        return order['product_name']?.toString() ?? 'Order';
                      })(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status badge + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: status),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right, color: Colors.white30, size: 18),
                ],
              ),
            ],
          ),
        ));
  }

  void _showOrderDetail(BuildContext context) {
    final products = (order['products'] as List?) ?? [];
    final status = order['status']?.toString() ?? 'pending';
    final ts = order['created_at'] as dynamic;
    String dateStr = '—';
    if (ts != null) {
      try {
        final d = (ts as dynamic).toDate() as DateTime;
        dateStr = '${d.month}/${d.day}/${d.year}';
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['order_id']?.toString() ?? docId,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text('Placed $dateStr', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),
            const Text('Items', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...products.map((p) {
              final name = p['name']?.toString() ?? 'Item';
              final qty = p['qty']?.toString() ?? '1';
              final price = (p['price'] as num?)?.toStringAsFixed(2) ?? '—';
              final size = p['size_label']?.toString();
              final mat = p['material']?.toString();
              final notes = p['notes']?.toString() ?? '';
              final fileCount = (p['file_urls'] as List?)?.length ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
                        Text('₱$price', style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        'Qty: $qty',
                        if (size != null) size,
                        if (mat != null) mat,
                      ].join(' · '),
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: $notes', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                    if (fileCount > 0) ...[
                      const SizedBox(height: 4),
                      Text('$fileCount file${fileCount != 1 ? 's' : ''} attached',
                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11)),
                    ],
                  ],
                ),
              );
            }).toList(),
            const Divider(color: Colors.white12, height: 24),
            Row(
              children: [
                const Expanded(child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                Text(
                  '₱${(order['total_price'] as num?)?.toStringAsFixed(2) ?? '—'}',
                  style: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('50% downpayment required on pickup',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':        return Colors.amber;
      case 'in_production':  return Colors.blueAccent;
      case 'ready':          return Colors.green;
      case 'cancelled':      return Colors.redAccent;
      case 'completed':      return AppTheme.accent;
      default:               return Colors.white54;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'pending':        return Icons.hourglass_empty;
      case 'in_production':  return Icons.precision_manufacturing_outlined;
      case 'ready':          return Icons.check_circle_outline;
      case 'cancelled':      return Icons.cancel_outlined;
      case 'completed':      return Icons.task_alt;
      default:               return Icons.receipt_long_outlined;
    }
  }
}

// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  String get _label {
    switch (status) {
      case 'pending':        return 'Pending';
      case 'in_production':  return 'In Production';
      case 'ready':          return 'Ready';
      case 'cancelled':      return 'Cancelled';
      case 'completed':      return 'Completed';
      default:               return status;
    }
  }

  Color get _color {
    switch (status) {
      case 'pending':        return Colors.amber;
      case 'in_production':  return Colors.blueAccent;
      case 'ready':          return Colors.green;
      case 'cancelled':      return Colors.redAccent;
      case 'completed':      return AppTheme.accent;
      default:               return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha:0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}