import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  int _topTab = 0; // 0 = Inventory Logs, 1 = Sales

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PillTabBar(
          tabs: const ['Inventory Logs', 'Sales'],
          active: _topTab,
          onTap: (i) => setState(() => _topTab = i),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: _topTab == 0
              ? const _InventoryLogsTab()
              : const _SalesTab(),
        ),
      ],
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;

  const _PillTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

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

class _InventoryLogsTab extends StatefulWidget {
  const _InventoryLogsTab();

  @override
  State<_InventoryLogsTab> createState() => _InventoryLogsTabState();
}

class _InventoryLogsTabState extends State<_InventoryLogsTab> {
  String _employeeFilter = '';
  String _materialFilter = '';
  final _empCtrl = TextEditingController();
  final _matCtrl = TextEditingController();

  static final _dateFmt = DateFormat('MMM dd, yyyy hh:mm a');

  @override
  void dispose() {
    _empCtrl.dispose();
    _matCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: const Text('Clear All Logs',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will permanently delete all inventory log entries. This cannot be undone.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      const batchSize = 400;
      while (true) {
        final snap = await FirebaseFirestore.instance
            .collection('InventoryLogs')
            .limit(batchSize)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('All logs cleared'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logs & History',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text('Employee inventory activity',
                      style:
                      TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _confirmClearAll(context),
              icon: Icon(Icons.delete_sweep_outlined,
                  size: 16, color: Colors.red.shade400),
              label: Text('Clear All',
                  style: TextStyle(
                      fontSize: 12, color: Colors.red.shade400)),
              style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Filter row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _empCtrl,
                style:
                const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) =>
                    setState(() => _employeeFilter = v.toLowerCase()),
                decoration: AppTheme.inputDecoration(
                    'Filter by employee',
                    icon: Icons.person_search_outlined),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _matCtrl,
                style:
                const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) =>
                    setState(() => _materialFilter = v.toLowerCase()),
                decoration: AppTheme.inputDecoration(
                    'Filter by material',
                    icon: Icons.inventory_2_outlined),
              ),
            ),
            if (_employeeFilter.isNotEmpty || _materialFilter.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear,
                    color: Colors.white38, size: 18),
                onPressed: () {
                  _empCtrl.clear();
                  _matCtrl.clear();
                  setState(() {
                    _employeeFilter = '';
                    _materialFilter = '';
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Table header
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Timestamp', style: _h)),
              Expanded(flex: 2, child: Text('Employee', style: _h)),
              Expanded(flex: 3, child: Text('Material', style: _h)),
              SizedBox(
                  width: 70,
                  child: Text('Added',
                      style: _h, textAlign: TextAlign.right)),
              SizedBox(
                  width: 70,
                  child: Text('New Stock',
                      style: _h, textAlign: TextAlign.right)),
              SizedBox(
                  width: 60,
                  child: Text('Method',
                      style: _h, textAlign: TextAlign.center)),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Log list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('InventoryLogs')
                .orderBy('timestamp', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child:
                    CircularProgressIndicator(color: Colors.white));
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off,
                          size: 56, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('No activity logs yet',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 15)),
                      SizedBox(height: 8),
                      Text(
                          'Logs appear here when employees replenish stock',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                );
              }

              final filtered = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                final emp =
                    data['updated_by_name']?.toString().toLowerCase() ??
                        '';
                final mat =
                    data['material_name']?.toString().toLowerCase() ??
                        '';
                return (_employeeFilter.isEmpty ||
                    emp.contains(_employeeFilter)) &&
                    (_materialFilter.isEmpty ||
                        mat.contains(_materialFilter));
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No logs matching your filter',
                    style: TextStyle(
                        color: Colors.white38, fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final data =
                  filtered[i].data() as Map<String, dynamic>;
                  return _LogRow(data: data, dateFmt: _dateFmt);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static const _h = TextStyle(
      color: Colors.white60,
      fontSize: 11,
      fontWeight: FontWeight.bold);
}

class _SalesTab extends StatefulWidget {
  const _SalesTab();

  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  int _subTab = 0; // 0 = Sales Record, 1 = Sales Report

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Underline sub-tab bar
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
            thickness: 1,
          ),

          Expanded(
            child: _subTab == 0
                ? const SalesRecordTable()  // ← sales_widgets.dart
                : const SalesReportView(),  // ← sales_widgets.dart
          ),
        ],
      ),
    );
  }
}

class _UnderlineTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;

  const _UnderlineTabBar({
    required this.tabs,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            margin:
            EdgeInsets.only(right: i < tabs.length - 1 ? 24 : 0),
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

class _LogRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateFormat dateFmt;

  const _LogRow({required this.data, required this.dateFmt});

  String _methodLabel(String method) {
    switch (method) {
      case 'qr_scan':
        return 'QR';
      case 'admin_edit':
        return 'Admin';
      case 'order_deduction':
        return 'Order';
      default:
        return 'Manual';
    }
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'qr_scan':
        return AppTheme.accent;
      case 'admin_edit':
        return AppTheme.gold;
      case 'order_deduction':
        return const Color(0xFFAB47BC);
      default:
        return Colors.white60;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = data['timestamp'] as Timestamp?;
    final timeStr = ts != null ? dateFmt.format(ts.toDate()) : '—';
    final employee = data['updated_by_name']?.toString() ?? '—';
    final materialName = data['material_name']?.toString() ?? '—';
    final materialId = data['material_id']?.toString() ?? '';
    final qtyAdded = (data['quantity_added'] as num?) ?? 0;
    final newStock = (data['new_stock'] as num?) ?? 0;
    final method = data['update_method']?.toString() ?? 'manual';
    final productName = data['product_name']?.toString() ?? '';
    final orderId = data['order_id']?.toString() ?? '';
    final isOrderDeduction = method == 'order_deduction';

    String fmt(num v) =>
        v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

    final isPositive = qtyAdded > 0;
    final isNegative = qtyAdded < 0;
    final qtyDisplay =
    isPositive ? '+${fmt(qtyAdded)}' : fmt(qtyAdded);
    final qtyColor = isPositive
        ? const Color(0xFF4CAF50)
        : isNegative
        ? const Color(0xFFF44336)
        : Colors.white60;

    final methodColor = _methodColor(method);

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOrderDeduction
            ? const Color(0xFFAB47BC).withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isOrderDeduction
              ? const Color(0xFFAB47BC).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(timeStr,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              isOrderDeduction ? 'Auto (Order)' : employee,
              style: TextStyle(
                  color: isOrderDeduction
                      ? const Color(0xFFAB47BC)
                      : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(materialName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(materialId,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace')),
                if (isOrderDeduction && productName.isNotEmpty)
                  Text(
                    'Product: $productName${orderId.isNotEmpty ? ' · #${orderId.substring(0, orderId.length.clamp(0, 6))}' : ''}',
                    style: const TextStyle(
                        color: Color(0xFFCE93D8), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(qtyDisplay,
                style: TextStyle(
                    color: qtyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 70,
            child: Text(fmt(newStock),
                style: const TextStyle(
                    color: Colors.white, fontSize: 12),
                textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: methodColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: methodColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  _methodLabel(method),
                  style: TextStyle(
                      color: methodColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}