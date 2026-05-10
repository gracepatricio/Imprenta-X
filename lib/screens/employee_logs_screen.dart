import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';
import 'employee_pos_screen.dart';
import 'invoice_screen.dart';

class EmployeeLogsScreen extends StatefulWidget {
  // 0 = Job Queue Pending, 1 = Job Queue Active, 2 = Ready for Pickup
  final int initialJobQueueTab;
  const EmployeeLogsScreen({super.key, this.initialJobQueueTab = 0});

  @override
  State<EmployeeLogsScreen> createState() => _EmployeeLogsScreenState();
}

class _EmployeeLogsScreenState extends State<EmployeeLogsScreen> {
  int _topTab = 0; // 0 = Job Queue, 1 = Sales Record, 2 = POS

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PillTabBar(
            tabs: const ['Job Queue', 'Sales Record', 'POS'],
            active: _topTab,
            onTap: (i) => setState(() => _topTab = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: switch (_topTab) {
              0 => _JobQueuePlaceholder(initialTab: widget.initialJobQueueTab),
              1 => const _SalesSection(),
              2 => const EmployeePosScreen(),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

class _SalesSection extends StatefulWidget {
  const _SalesSection();

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  int _subTab = 0; // 0 = Sales Record, 1 = Sales Report

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _UnderlineTabBar(
              tabs: const ['Sales Record', 'Sales Report'],
              active: _subTab,
              onTap: (i) => setState(() => _subTab = i),
            ),
          ),
          Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
              thickness: 1),
          Expanded(
            child: _subTab == 0
                ? const SalesRecordTable()  // ← from sales_widgets.dart
                : const SalesReportView(),  // ← from sales_widgets.dart
          ),
        ],
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;
  const _PillTabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return Padding(
          padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white70,
                  fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _UnderlineTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;
  const _UnderlineTabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            margin: EdgeInsets.only(right: i < tabs.length - 1 ? 24 : 0),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? AppTheme.gold : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              tabs[i],
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Job Queue ─────────────────────────────────────────────────────────────────

class _JobQueuePlaceholder extends StatefulWidget {
  final int initialTab;
  const _JobQueuePlaceholder({this.initialTab = 0});

  @override
  State<_JobQueuePlaceholder> createState() => _JobQueuePlaceholderState();
}

class _JobQueuePlaceholderState extends State<_JobQueuePlaceholder>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length:       4,
      vsync:        this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UnderlineTabBar(
          tabs: const ['Pending', 'Active', 'Ready for Pickup', 'Order History'],
          active: _tabs.index,
          onTap: (i) => _tabs.animateTo(i),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _QueueList(jobStatus: 'pending'),
              _QueueList(jobStatus: 'active'),
              _ReadyForPickupList(),
              _OrderHistoryList(),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueList extends StatelessWidget {
  final String jobStatus;
  const _QueueList({required this.jobStatus});

  @override
  Widget build(BuildContext context) {
    // No orderBy in Firestore query — compound index would be needed.
    // We sort client-side by created_at for FCFS ordering.
    final query = FirebaseFirestore.instance
        .collection('Order_Queue')
        .where('job_status', isEqualTo: jobStatus);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Queue error: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center),
            ),
          );
        }

        // Sort by created_at ascending = First Come First Served
        final docs = [...(snap.data?.docs ?? [])]
          ..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  jobStatus == 'pending'
                      ? Icons.queue_outlined
                      : Icons.precision_manufacturing_outlined,
                  size: 52, color: Colors.white24,
                ),
                const SizedBox(height: 14),
                Text(
                  jobStatus == 'pending' ? 'No pending jobs' : 'No active jobs',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _QueueCard(
              queueDocId: doc.id,
              data:       data,
              position:   i + 1,
            );
          },
        );
      },
    );
  }
}

// ── Ready for Pickup list ─────────────────────────────────────────────────────

class _ReadyForPickupList extends StatelessWidget {
  const _ReadyForPickupList();

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Orders')
        .where('status', isEqualTo: 'ready');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)));
        }

        // FCFS: sort by created_at ascending
        final docs = [...(snap.data?.docs ?? [])]
          ..sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, size: 52, color: Colors.white24),
                SizedBox(height: 14),
                Text('No orders ready for pickup',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc  = docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _ReadyOrderCard(orderId: doc.id, data: data);
          },
        );
      },
    );
  }
}

class _ReadyOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  const _ReadyOrderCard({required this.orderId, required this.data});

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month-1]} ${d.day}';
    } catch (_) { return '—'; }
  }

  Future<void> _markCompleted(BuildContext context) async {
    final db    = FirebaseFirestore.instance;
    await db.collection('Orders').doc(orderId).update({
      'status': 'completed',
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order $orderId marked as completed'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = data['order_id']?.toString() ?? orderId;
    final customer   = data['customer_name']?.toString() ?? '—';
    final total      = (data['total_price']       as num?)?.toDouble() ?? 0;
    final paid       = (data['amount_paid']       as num?)?.toDouble() ?? 0;
    final remaining  = (data['remaining_balance'] as num?)?.toDouble() ?? (total - paid);
    final fullyPaid  = remaining < 0.01;
    final pct        = total > 0 ? (paid / total).clamp(0.0, 1.0) : 1.0;
    final products   = (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr    = _fmtDate(data['created_at']);
    final payStatus  = data['payment_status']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text('$customer · $dateStr',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Ready',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Products
            if (products.isNotEmpty)
              Text(
                products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', '),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 10),

            // Balance row
            Row(
              children: [
                _Chip('Total', '₱${total.toStringAsFixed(2)}', Colors.white70),
                const SizedBox(width: 10),
                _Chip('Paid', '₱${paid.toStringAsFixed(2)}', Colors.green),
                const SizedBox(width: 10),
                _Chip(
                  fullyPaid ? 'Fully Paid' : 'Balance Due',
                  fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                  fullyPaid ? Colors.green : AppTheme.gold,
                  bold: true,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    fullyPaid ? Colors.green : AppTheme.gold),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 12),

            // Action row
            Row(
              children: [
                if (!fullyPaid)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Collect ₱${remaining.toStringAsFixed(2)} via POS before release',
                              style: const TextStyle(color: Colors.orange, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (fullyPaid) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markCompleted(context),
                      icon: const Icon(Icons.task_alt_rounded, size: 16),
                      label: const Text('Mark as Completed',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _Chip(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              color: color,
              fontSize: bold ? 13 : 11,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
    ],
  );
}

// ── Queue card ────────────────────────────────────────────────────────────────

class _QueueCard extends StatelessWidget {
  final String queueDocId;
  final Map<String, dynamic> data;
  final int position;

  const _QueueCard({
    required this.queueDocId,
    required this.data,
    required this.position,
  });

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month-1]} ${d.day}, ${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return '—'; }
  }

  Future<void> _startJob(BuildContext context) async {
    final orderId     = data['order_id']?.toString();
    final customerUid = data['customer_uid']?.toString();
    if (orderId == null) return;

    final db    = FirebaseFirestore.instance;
    final batch = db.batch();

    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'active',
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {
      'status': 'in_production',
    });

    await batch.commit();

    // Notify customer via chat
    if (customerUid != null && customerUid.isNotEmpty) {
      final threadRef = db.collection('Messages').doc('chat_$customerUid');
      final turnaround = data['turnaround_days'] as int?;
      await threadRef.collection('chat').add({
        'sender_uid':  'system',
        'sender_role': 'system',
        'text':        'Your order $orderId is now in production!'
            '${turnaround != null ? ' Estimated completion: ~$turnaround day${turnaround == 1 ? '' : 's'}.' : ''}',
        'timestamp':   FieldValue.serverTimestamp(),
      });
      await threadRef.set({
        'last_message':    'Your order $orderId is now in production!',
        'last_updated':    FieldValue.serverTimestamp(),
        'unread_customer': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Started production for $orderId'),
        backgroundColor: Colors.blue.shade700,
      ));
    }
  }

  Future<void> _markReady(BuildContext context) async {
    final orderId     = data['order_id']?.toString();
    final customerUid = data['customer_uid']?.toString();
    if (orderId == null) return;

    final db    = FirebaseFirestore.instance;
    final batch = db.batch();

    // Load order for balance info
    final orderSnap = await db.collection('Orders').doc(orderId).get();
    final remaining = (orderSnap.data()?['remaining_balance'] as num?)?.toDouble() ?? 0;

    batch.update(db.collection('Order_Queue').doc(queueDocId), {
      'job_status': 'completed',
      'updated_at': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('Orders').doc(orderId), {
      'status': 'ready',
    });

    await batch.commit();

    // Notify customer via chat
    if (customerUid != null && customerUid.isNotEmpty) {
      final balanceNote = remaining > 0
          ? ' Remaining balance due on pickup: ₱${remaining.toStringAsFixed(2)}.'
          : ' Your order is fully paid — just come pick it up!';
      final threadRef = db.collection('Messages').doc('chat_$customerUid');
      await threadRef.collection('chat').add({
        'sender_uid':  'system',
        'sender_role': 'system',
        'text':        'Your order $orderId is ready for pickup!$balanceNote',
        'timestamp':   FieldValue.serverTimestamp(),
      });
      await threadRef.set({
        'last_message':    'Your order $orderId is ready for pickup!',
        'last_updated':    FieldValue.serverTimestamp(),
        'unread_customer': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order $orderId marked ready for pickup'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderId     = data['order_id']?.toString() ?? '—';
    final customerName = data['customer_name']?.toString() ?? 'Customer';
    final turnaround  = data['turnaround_days'] as int?;
    final total       = (data['total_price'] as num?)?.toDouble() ?? 0;
    final jobStatus   = data['job_status']?.toString() ?? 'pending';
    final products    = (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateStr     = _fmtDate(data['created_at']);

    final statusColor = jobStatus == 'active' ? Colors.blueAccent : Colors.amber;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Queue position badge
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.gold.withValues(alpha: 0.5)),
                  ),
                  child: Center(
                    child: Text('#$position',
                        style: const TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderId,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(customerName,
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    jobStatus == 'active' ? 'Active' : 'Pending',
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Product summary
            if (products.isNotEmpty) ...[
              Text(
                products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', '),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],

            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(
                  turnaround != null
                      ? 'Est. $turnaround day${turnaround == 1 ? '' : 's'}'
                      : 'Turnaround TBD',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today, size: 13, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(dateStr,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
                ),
                Text('₱${total.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                if (jobStatus == 'pending')
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startJob(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Start Job', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                if (jobStatus == 'active') ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _markReady(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Mark Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // View invoice button
                Builder(builder: (ctx) => OutlinedButton(
                  onPressed: () async {
                    final orderSnap = await FirebaseFirestore.instance
                        .collection('Orders').doc(orderId).get();
                    final invId = orderSnap.data()?['invoice_id']?.toString();
                    if (invId != null && ctx.mounted) {
                      Navigator.of(ctx).push(MaterialPageRoute(
                        builder: (_) => InvoiceScreen(invoiceId: invId),
                      ));
                    } else if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('No invoice yet for this order')),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, size: 18),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ── Order History list ────────────────────────────────────────────────────────

// ── Order History list ────────────────────────────────────────────────────────

class _OrderHistoryList extends StatefulWidget {
  const _OrderHistoryList();

  @override
  State<_OrderHistoryList> createState() => _OrderHistoryListState();
}

class _OrderHistoryListState extends State<_OrderHistoryList> {
  String _statusFilter = 'all'; // 'all' | 'completed' | 'cancelled'
  String _search = '';

  static const _statusOpts = [
    ('all',       'All'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  Stream<List<QueryDocumentSnapshot>> _stream() {
    Query q = FirebaseFirestore.instance.collection('Orders');
    if (_statusFilter != 'all') {
      q = q.where('status', isEqualTo: _statusFilter);
    } else {
      // whereIn: completed or cancelled
      q = q.where('status', whereIn: ['completed', 'cancelled']);
    }
    return q.snapshots().map((snap) {
      final docs = [...snap.docs]
        ..sort((a, b) {
          final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
      return docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter row ────────────────────────────────────────────────
        Row(
          children: [
            ..._statusOpts.map((opt) {
              final active = _statusFilter == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _statusFilter = opt.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    child: Text(opt.$2,
                        style: TextStyle(
                          color: active ? AppTheme.gold : Colors.white70,
                          fontSize: 12,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        )),
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        // ── Search field ──────────────────────────────────────────────
        TextField(
          onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by order ID or customer…',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── List ──────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: _stream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.gold));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}',
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12)));
              }

              var docs = snap.data ?? [];
              if (_search.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final id   = (data['order_id']?.toString() ?? d.id).toLowerCase();
                  final name = (data['customer_name']?.toString() ?? '').toLowerCase();
                  return id.contains(_search) || name.contains(_search);
                }).toList();
              }

              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 52, color: Colors.white24),
                      SizedBox(height: 14),
                      Text('No orders found',
                          style: TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc  = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _HistoryOrderCard(orderId: doc.id, data: data);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  const _HistoryOrderCard({required this.orderId, required this.data});

  String _fmtDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final d = (ts as Timestamp).toDate().toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month-1]} ${d.day}, ${d.year}';
    } catch (_) { return '—'; }
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = data['order_id']?.toString() ?? orderId;
    final customer   = data['customer_name']?.toString() ?? '—';
    final status     = data['status']?.toString() ?? 'completed';
    final total      = (data['total_price']       as num?)?.toDouble() ?? 0;
    final paid       = (data['amount_paid']        as num?)?.toDouble() ?? 0;
    final remaining  = (data['remaining_balance']  as num?)?.toDouble() ?? (total - paid);
    final fullyPaid  = remaining < 0.01;
    final pct        = total > 0 ? (paid / total).clamp(0.0, 1.0) : 1.0;
    final products   = (data['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final turnaround = data['turnaround_days'] as int?;
    final dateStr    = _fmtDate(data['created_at']);
    final invoiceId  = data['invoice_id']?.toString();
    final isCancelled = status == 'cancelled';

    final statusColor = isCancelled ? Colors.redAccent : Colors.white54;
    final statusLabel = isCancelled ? 'Cancelled' : 'Completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text('$customer · $dateStr',
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Products ───────────────────────────────────────────────
            if (products.isNotEmpty) ...[
              Text(
                products.map((p) => '${p['name'] ?? '?'} ×${p['qty'] ?? 1}').join(', '),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],

            // ── Turnaround ─────────────────────────────────────────────
            if (turnaround != null) ...[
              Row(children: [
                Icon(Icons.schedule, size: 12, color: Colors.white.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text('$turnaround day${turnaround == 1 ? '' : 's'} turnaround',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
              ]),
              const SizedBox(height: 8),
            ],

            // ── Balance row ────────────────────────────────────────────
            if (!isCancelled) ...[
              Row(
                children: [
                  _Chip('Total', '₱${total.toStringAsFixed(2)}', Colors.white70),
                  const SizedBox(width: 10),
                  _Chip('Paid', '₱${paid.toStringAsFixed(2)}', Colors.green),
                  const SizedBox(width: 10),
                  _Chip(
                    fullyPaid ? 'Fully Paid' : 'Balance Due',
                    fullyPaid ? '—' : '₱${remaining.toStringAsFixed(2)}',
                    fullyPaid ? Colors.green : AppTheme.gold,
                    bold: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Progress bar ───────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      fullyPaid ? Colors.green : AppTheme.gold),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 4),

            // ── Invoice button ─────────────────────────────────────────
            Builder(builder: (ctx) => OutlinedButton.icon(
              onPressed: () async {
                String? invId = invoiceId;
                if (invId == null) {
                  final orderSnap = await FirebaseFirestore.instance
                      .collection('Orders').doc(orderId).get();
                  invId = orderSnap.data()?['invoice_id']?.toString();
                }
                if (invId != null && ctx.mounted) {
                  Navigator.of(ctx).push(MaterialPageRoute(
                    builder: (_) => InvoiceScreen(invoiceId: invId!),
                  ));
                } else if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('No invoice for this order')),
                  );
                }
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 16, color: AppTheme.gold),
              label: const Text('View Invoice',
                  style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
