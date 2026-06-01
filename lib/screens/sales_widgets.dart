// Shared widgets for Sales Record and Sales Report.
// Used by BOTH the employee and admin screens.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// ── Light-theme design tokens ─────────────────────────────────────────────────
class _T {
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color headerBg = Color(0xFFF3F4F6);
  static const Color gold = Color(0xFFB45309);
}

// ── Period filter enum ────────────────────────────────────────────────────────
enum _Period { all, day, week, month, year }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.all:   return 'All Time';
      case _Period.day:   return 'Today';
      case _Period.week:  return 'This Week';
      case _Period.month: return 'This Month';
      case _Period.year:  return 'This Year';
    }
  }

  String get shortLabel {
    switch (this) {
      case _Period.all:   return 'All';
      case _Period.day:   return 'Today';
      case _Period.week:  return 'Week';
      case _Period.month: return 'Month';
      case _Period.year:  return 'Year';
    }
  }
}

bool _inPeriod(DateTime dt, _Period period) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case _Period.all:   return true;
    case _Period.day:   return !dt.isBefore(today);
    case _Period.week:
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return !dt.isBefore(weekStart);
    case _Period.month: return dt.year == now.year && dt.month == now.month;
    case _Period.year:  return dt.year == now.year;
  }
}

// ── Period filter bar ─────────────────────────────────────────────────────────
class _PeriodFilterBar extends StatelessWidget {
  final _Period active;
  final ValueChanged<_Period> onChanged;
  final bool dark;

  const _PeriodFilterBar({
    required this.active,
    required this.onChanged,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _Period.values.map((p) {
          final isActive = p == active;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? (dark ? AppTheme.gold : const Color(0xFF1A1A2E))
                    : (dark ? Colors.white.withValues(alpha: 0.10) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? (dark ? AppTheme.gold : const Color(0xFF1A1A2E))
                      : (dark ? Colors.white.withValues(alpha: 0.18) : _T.divider),
                  width: 1,
                ),
                boxShadow: (isActive && !dark)
                    ? [const BoxShadow(color: Color(0x20000000), blurRadius: 6, offset: Offset(0, 2))]
                    : [],
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  color: isActive
                      ? (dark ? Colors.black : Colors.white)
                      : (dark ? Colors.white70 : _T.textSecondary),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Grouped record model ──────────────────────────────────────────────────────
// Represents all Sales_Records for a single order_id merged into one entry.
class _GroupedRecord {
  final String orderId;
  final String custName;
  final String custId;
  final double totalPaid;   // sum of sale_amount across all records for this order
  final double orderTotal;  // order_total field (same across records)
  final String paymentType; // derived: 'full' when fully paid, else latest type
  final String? paymentMethod;
  final Timestamp? latestDate;
  final List<DocumentReference> docRefs;

  const _GroupedRecord({
    required this.orderId,
    required this.custName,
    required this.custId,
    required this.totalPaid,
    required this.orderTotal,
    required this.paymentType,
    required this.paymentMethod,
    required this.latestDate,
    required this.docRefs,
  });
}

// Groups all raw Sales_Records docs by order_id and derives the combined state.
// If a record is missing customer_id (older records), it is resolved from the
// Orders collection so that searching by CUS-XXX works on historical data too.
Future<List<_GroupedRecord>> _groupRecordsAsync(
    List<QueryDocumentSnapshot> docs) async {
  // Accumulate per order_id
  final Map<String, List<Map<String, dynamic>>> byOrder = {};
  final Map<String, List<DocumentReference>>    refsByOrder = {};

  for (final doc in docs) {
    final d       = doc.data() as Map<String, dynamic>;
    final orderId = d['order_id']?.toString() ?? doc.id;
    byOrder.putIfAbsent(orderId, () => []).add(d);
    refsByOrder.putIfAbsent(orderId, () => []).add(doc.reference);
  }

  // Collect order IDs that are missing customer_id so we can batch-resolve them
  final missingCustIdOrders = <String>{};
  for (final orderId in byOrder.keys) {
    final records = byOrder[orderId]!;
    final hasCustId = records.any(
            (r) => (r['customer_id']?.toString() ?? '').isNotEmpty);
    if (!hasCustId) missingCustIdOrders.add(orderId);
  }

  // Resolve missing customer_ids:
  // Orders store customer_uid (not customer_id), so we:
  //   1. Fetch Orders by order_id to get customer_uid
  //   2. Fetch User docs by uid to get customer_id
  final resolvedCustId = <String, String>{};
  if (missingCustIdOrders.isNotEmpty) {
    final ids = missingCustIdOrders.toList();
    // Map orderId → customer_uid
    final orderIdToUid = <String, String>{};
    for (int i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, (i + 30).clamp(0, ids.length));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('Orders')
            .where('order_id', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final d    = doc.data();
          final ordId = d['order_id']?.toString() ?? '';
          final uid   = d['customer_uid']?.toString() ?? '';
          if (ordId.isNotEmpty && uid.isNotEmpty) {
            orderIdToUid[ordId] = uid;
          }
        }
      } catch (_) {}
    }

    // Fetch User docs to get customer_id
    final uids = orderIdToUid.values.toSet().toList();
    final uidToCustId = <String, String>{};
    for (int i = 0; i < uids.length; i += 30) {
      final chunk = uids.sublist(i, (i + 30).clamp(0, uids.length));
      try {
        final snap = await FirebaseFirestore.instance
            .collection('User')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final custId = doc.data()['customer_id']?.toString() ?? '';
          if (custId.isNotEmpty) uidToCustId[doc.id] = custId;
        }
      } catch (_) {}
    }

    // Map orderId → customer_id
    for (final entry in orderIdToUid.entries) {
      final custId = uidToCustId[entry.value];
      if (custId != null && custId.isNotEmpty) {
        resolvedCustId[entry.key] = custId;
      }
    }
  }

  final groups = <_GroupedRecord>[];

  for (final orderId in byOrder.keys) {
    final records = byOrder[orderId]!;
    final refs    = refsByOrder[orderId]!;

    double totalPaid   = 0;
    double orderTotal  = 0;
    String custName    = '—';
    String custId      = '';
    String? lastMethod;
    Timestamp? latestTs;
    String derivedType = 'downpayment';

    for (final r in records) {
      totalPaid  += (r['sale_amount'] as num?)?.toDouble() ?? 0;
      final ot    = (r['order_total'] as num?)?.toDouble() ?? 0;
      if (ot > orderTotal) orderTotal = ot;
      if ((r['customer_name']?.toString() ?? '').isNotEmpty) custName = r['customer_name'];
      if ((r['customer_id']?.toString()   ?? '').isNotEmpty) custId   = r['customer_id'];
      if ((r['payment_method']?.toString() ?? '').isNotEmpty) lastMethod = r['payment_method'];

      final ts = r['sale_date'] as Timestamp?;
      if (ts != null && (latestTs == null || ts.compareTo(latestTs) > 0)) {
        latestTs = ts;
        final t = r['payment_type']?.toString() ?? '';
        if (t == 'cash') {
          derivedType = 'full';
        } else if (t.isNotEmpty) {
          derivedType = t;
        }
      }
    }

    // Fall back to resolved customer_id from Orders if still empty
    if (custId.isEmpty && resolvedCustId.containsKey(orderId)) {
      custId = resolvedCustId[orderId]!;
    }

    groups.add(_GroupedRecord(
      orderId:       orderId,
      custName:      custName,
      custId:        custId,
      totalPaid:     totalPaid,
      orderTotal:    orderTotal,
      paymentType:   derivedType,
      paymentMethod: lastMethod,
      latestDate:    latestTs,
      docRefs:       refs,
    ));
  }

  // Sort by latest payment date descending
  groups.sort((a, b) {
    if (a.latestDate == null && b.latestDate == null) return 0;
    if (a.latestDate == null) return 1;
    if (b.latestDate == null) return -1;
    return b.latestDate!.compareTo(a.latestDate!);
  });

  return groups;
}

// =============================================================================
// Sales Record Table
// =============================================================================
class SalesRecordTable extends StatefulWidget {
  const SalesRecordTable({super.key});

  @override
  State<SalesRecordTable> createState() => _SalesRecordTableState();
}

class _SalesRecordTableState extends State<SalesRecordTable> {
  String _typeFilter = 'all';
  _Period _period    = _Period.all;
  String _search     = '';

  QuerySnapshot? _snapshot;
  List<_GroupedRecord> _allGroups = [];
  bool _groupsLoading = false;
  StreamSubscription<QuerySnapshot>? _sub;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('Sales_Records')
        .orderBy('sale_date', descending: true)
        .snapshots()
        .listen((snap) async {
      if (!mounted) return;
      setState(() { _snapshot = snap; _groupsLoading = true; });
      final groups = await _groupRecordsAsync(snap.docs);
      if (mounted) setState(() { _allGroups = groups; _groupsLoading = false; });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d  = ts.toDate().toLocal();
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'downpayment': return 'Downpayment';
      case 'balance':     return 'Balance';
      case 'full':        return 'Full Payment';
      default:            return (t != null && t.isNotEmpty) ? t : '—';
    }
  }

  Color _typeFg(String? t) {
    switch (t) {
      case 'downpayment': return const Color(0xFF1D4ED8);
      case 'balance':     return const Color(0xFFB45309);
      case 'full':        return const Color(0xFF6D28D9);
      default:            return _T.textMuted;
    }
  }

  Color _typeBg(String? t) {
    switch (t) {
      case 'downpayment': return const Color(0xFFEFF6FF);
      case 'balance':     return const Color(0xFFFFFBEB);
      case 'full':        return const Color(0xFFF5F3FF);
      default:            return _T.headerBg;
    }
  }

  Color _typeBorder(String? t) {
    switch (t) {
      case 'downpayment': return const Color(0xFFBFDBFE);
      case 'balance':     return const Color(0xFFFDE68A);
      case 'full':        return const Color(0xFFDDD6FE);
      default:            return _T.divider;
    }
  }

  String _methodLabel(String? m) {
    switch (m) {
      case 'gcash':  return 'GCash';
      case 'card':   return 'Card';
      case 'maya':   return 'Maya';
      case 'cash':   return 'Cash';
      case 'online': return 'Online';
      default:       return (m != null && m.isNotEmpty) ? m : '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_snapshot == null || _groupsLoading) {
      return Center(child: CircularProgressIndicator(color: _T.textPrimary.withValues(alpha: 0.4)));
    }

    // Group all raw docs by order_id first
    final allGroups = _allGroups;

    // Period filter — use the group's latest payment date
    var filtered = allGroups.where((g) {
      final ts = g.latestDate;
      if (ts == null) return _period == _Period.all;
      return _inPeriod(ts.toDate().toLocal(), _period);
    }).toList();

    // Type filter — match against derived paymentType
    if (_typeFilter != 'all') {
      filtered = filtered
          .where((g) => g.paymentType == _typeFilter)
          .toList();
    }

    // Search — supports full customer ID (e.g. CUS-123), name, order ID,
    // or just the numeric/suffix part of the customer ID (e.g. "123").
    if (_search.isNotEmpty) {
      filtered = filtered.where((g) {
        final custIdLower = g.custId.toLowerCase();
        // Also match the part after the last '-' so typing "123" finds "CUS-123"
        final custIdSuffix = custIdLower.contains('-')
            ? custIdLower.split('-').last
            : custIdLower;
        return g.orderId.toLowerCase().contains(_search) ||
            g.custName.toLowerCase().contains(_search) ||
            custIdLower.contains(_search) ||
            custIdSuffix.contains(_search);
      }).toList();
    }

    final totalCollected = filtered.fold<double>(0, (s, g) => s + g.totalPaid);
    final allTotal       = allGroups.fold<double>(0, (s, g) => s + g.totalPaid);

    // Sum remaining balance from all grouped orders still on 'downpayment' status
    // (i.e. order_total - totalPaid for every group whose latest payment is a downpayment)
    double paymentToCollect = 0;
    for (final g in allGroups) {
      if (g.paymentType == 'downpayment' && g.orderTotal > 0) {
        final remaining = g.orderTotal - g.totalPaid;
        if (remaining > 0.01) paymentToCollect += remaining;
      }
    }

    final headerContent = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SummaryChip(
                  label: 'Period Total',
                  value: '₱${totalCollected.toStringAsFixed(2)}',
                  fg: _T.gold,
                  bg: const Color(0xFFFFFBEB),
                  border: const Color(0xFFFDE68A),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Records',
                  value: '${filtered.length}',
                  fg: const Color(0xFF374151),
                  bg: _T.headerBg,
                  border: _T.divider,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'All-Time',
                  value: '₱${allTotal.toStringAsFixed(2)}',
                  fg: const Color(0xFF6D28D9),
                  bg: const Color(0xFFF5F3FF),
                  border: const Color(0xFFDDD6FE),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'To Collect',
                  value: '₱${paymentToCollect.toStringAsFixed(2)}',
                  fg: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _UnifiedFilterBar(
            activePeriod: _period,
            activeType: _typeFilter,
            onPeriodChanged: (p) => setState(() => _period = p),
            onTypeChanged: (t) => setState(() => _typeFilter = t),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) {
              final trimmed = v.trim().toLowerCase();
              if (trimmed != _search) setState(() => _search = trimmed);
            },
            style: const TextStyle(color: _T.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by Order ID, Customer Name, or Customer ID',
              hintStyle: const TextStyle(color: _T.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 16, color: _T.textMuted),
              suffixIcon: _search.isNotEmpty
                  ? GestureDetector(
                onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                child: const Icon(Icons.clear, size: 16, color: _T.textMuted),
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.7)),
              ),
            ),
          ),
        ],
      ),
    );

    if (filtered.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: headerContent),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _T.headerBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _T.divider),
                    ),
                    child: const Icon(Icons.receipt_long_outlined, size: 32, color: _T.textMuted),
                  ),
                  const SizedBox(height: 20),
                  const Text('No sales records found',
                      style: TextStyle(color: _T.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Try adjusting your filters',
                      style: TextStyle(color: _T.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: headerContent),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (_, i) {
                final g = filtered[i];
                return _SalesRecordCard(
                  index:       i,
                  orderId:     g.orderId,
                  custName:    g.custName,
                  custId:      g.custId,
                  type:        g.paymentType,
                  method:      g.paymentMethod,
                  totalPaid:   g.totalPaid,
                  orderTotal:  g.orderTotal,
                  date:        _fmt(g.latestDate),
                  typeFg:      _typeFg(g.paymentType),
                  typeBg:      _typeBg(g.paymentType),
                  typeBorder:  _typeBorder(g.paymentType),
                  typeLabel:   _typeLabel(g.paymentType),
                  methodLabel: _methodLabel(g.paymentMethod),
                );
              },
              childCount: filtered.length,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Sales Record Card
// =============================================================================
class _SalesRecordCard extends StatelessWidget {
  final int index;
  final String orderId, custName, custId;
  final String? type, method;
  final double totalPaid;   // cumulative total paid across all records
  final double orderTotal;  // full order value
  final String date;
  final Color typeFg, typeBg, typeBorder;
  final String typeLabel, methodLabel;

  const _SalesRecordCard({
    required this.index,
    required this.orderId,
    required this.custName,
    required this.custId,
    required this.type,
    required this.method,
    required this.totalPaid,
    required this.orderTotal,
    required this.date,
    required this.typeFg,
    required this.typeBg,
    required this.typeBorder,
    required this.typeLabel,
    required this.methodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isFullyPaid = type == 'full';
    final hasBalance  = orderTotal > 0 && !isFullyPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22, height: 22,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(color: _T.textMuted, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(orderId,
                          style: const TextStyle(color: _T.textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 10, color: _T.textMuted),
                          const SizedBox(width: 4),
                          Text(date, style: const TextStyle(color: _T.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Total paid (cumulative across all payments for this order)
                    Text('₱${totalPaid.toStringAsFixed(2)}',
                        style: const TextStyle(color: _T.gold, fontSize: 16,
                            fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    if (orderTotal > 0)
                      Text('of ₱${orderTotal.toStringAsFixed(2)}',
                          style: const TextStyle(color: _T.textMuted, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(methodLabel,
                        style: const TextStyle(color: _T.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
            // Progress bar when partially paid
            if (hasBalance && orderTotal > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (totalPaid / orderTotal).clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1D4ED8)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paid ₱${totalPaid.toStringAsFixed(2)}',
                      style: const TextStyle(color: _T.textMuted, fontSize: 10)),
                  Text('Remaining ₱${(orderTotal - totalPaid).clamp(0, double.infinity).toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 13, color: _T.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(custName,
                          style: const TextStyle(color: _T.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      if (custId.isNotEmpty)
                        Text('ID: $custId',
                            style: const TextStyle(color: _T.textMuted, fontSize: 10, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeBorder, width: 1),
                  ),
                  child: Text(typeLabel,
                      style: TextStyle(color: typeFg, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Unified Filter Bar
// =============================================================================
class _UnifiedFilterBar extends StatelessWidget {
  final _Period activePeriod;
  final String activeType;
  final ValueChanged<_Period> onPeriodChanged;
  final ValueChanged<String> onTypeChanged;

  const _UnifiedFilterBar({
    required this.activePeriod,
    required this.activeType,
    required this.onPeriodChanged,
    required this.onTypeChanged,
  });

  static const _typeOptions = [
    ('all',         'All Types',    Color(0xFF374151)),
    ('downpayment', 'Downpayment',  Color(0xFF1D4ED8)),
    ('balance',     'Balance',      Color(0xFFB45309)),
    ('full',        'Full',         Color(0xFF6D28D9)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period row
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Row(
                  children: const [
                    Icon(Icons.calendar_today_outlined, size: 12, color: _T.textMuted),
                    SizedBox(width: 5),
                    Text('Period',
                        style: TextStyle(color: _T.textMuted, fontSize: 11,
                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _Period.values.map((p) {
                      final isActive = p == activePeriod;
                      return GestureDetector(
                        onTap: () => onPeriodChanged(p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF1A1A2E) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? const Color(0xFF1A1A2E) : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: isActive
                                ? [const BoxShadow(color: Color(0x18000000), blurRadius: 4, offset: Offset(0, 1))]
                                : [],
                          ),
                          child: Text(p.shortLabel,
                              style: TextStyle(
                                color: isActive ? Colors.white : _T.textSecondary,
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
          // Type row
          Row(
            children: [
              SizedBox(
                width: 72,
                child: Row(
                  children: const [
                    Icon(Icons.label_outline_rounded, size: 12, color: _T.textMuted),
                    SizedBox(width: 5),
                    Text('Type',
                        style: TextStyle(color: _T.textMuted, fontSize: 11,
                            fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeOptions.map((opt) {
                      final isActive = activeType == opt.$1;
                      final accent   = opt.$3;
                      return GestureDetector(
                        onTap: () => onTypeChanged(opt.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isActive ? accent.withValues(alpha: 0.10) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? accent.withValues(alpha: 0.50) : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive) ...[
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(opt.$2,
                                  style: TextStyle(
                                    color: isActive ? accent : _T.textSecondary,
                                    fontSize: 12,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─ Summary chip ──────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color fg, bg, border;
  const _SummaryChip({
    required this.label, required this.value,
    required this.fg,    required this.bg,    required this.border,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

// ─ Filter chip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label, value, active;
  final ValueChanged<String> onTap;
  const _FilterChip(this.label, this.value, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = value == active;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF1A1A2E) : _T.divider, width: 1),
          boxShadow: sel
              ? [const BoxShadow(color: Color(0x20000000), blurRadius: 6, offset: Offset(0, 2))]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
              color: sel ? Colors.white : _T.textSecondary,
              fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            )),
      ),
    );
  }
}

// ─ Table header cell ─────────────────────────────────────────────────────────
class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w700,
          fontSize: 11, letterSpacing: 0.4));
}

// ─ Month bucket ──────────────────────────────────────────────────────────────
class _MonthBucket {
  final DateTime month;
  final String label;
  double total;
  _MonthBucket({required this.month, required this.label, required this.total});
}

// ─ Shared bucket builder ─────────────────────────────────────────────────────
String _shortMonth(int m) {
  const names = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return names[m - 1];
}

Map<String, _MonthBucket> _buildBucketMap(
    List<QueryDocumentSnapshot> allDocs,
    _Period period,
    ) {
  final now = DateTime.now();
  if (period != _Period.all) {
    // Fixed last-6-months window
    final map = <String, _MonthBucket>{};
    for (int i = 0; i < 6; i++) {
      final m   = DateTime(now.year, now.month - (5 - i));
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      map[key]  = _MonthBucket(month: m, label: _shortMonth(m.month), total: 0);
    }
    return map;
  }

  // All Time: derive buckets from every document
  final map = <String, _MonthBucket>{};
  for (final doc in allDocs) {
    final d  = doc.data() as Map<String, dynamic>;
    final ts = d['sale_date'] as Timestamp?;
    if (ts == null) continue;
    final dt  = ts.toDate();
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    map.putIfAbsent(
      key,
          () => _MonthBucket(
        month: DateTime(dt.year, dt.month),
        label: '${_shortMonth(dt.month)} \'${dt.year.toString().substring(2)}',
        total: 0,
      ),
    );
  }
  if (map.isEmpty) {
    // Fallback if no dates at all
    for (int i = 0; i < 6; i++) {
      final m   = DateTime(now.year, now.month - (5 - i));
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      map[key]  = _MonthBucket(month: m, label: _shortMonth(m.month), total: 0);
    }
  }
  return map;
}

// AdminSalesReportView
class AdminSalesReportView extends StatefulWidget {
  const AdminSalesReportView({super.key});

  @override
  State<AdminSalesReportView> createState() => _AdminSalesReportViewState();
}

class _AdminSalesReportViewState extends State<AdminSalesReportView> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, salesSnap) {
        if (salesSnap.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _T.textPrimary.withValues(alpha: 0.4)));
        }
        if (salesSnap.hasError) {
          return Center(child: Text('Error: ${salesSnap.error}',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Orders')
              .where('status', whereIn: ['pending', 'in_production', 'ready', 'completed'])
              .snapshots(),
          builder: (context, ordersSnap) {
            double outstandingBalance = 0;
            if (ordersSnap.hasData) {
              for (final doc in ordersSnap.data!.docs) {
                final d         = doc.data() as Map<String, dynamic>;
                final remaining = (d['remaining_balance'] as num?)?.toDouble();
                if (remaining != null && remaining > 0.01) {
                  outstandingBalance += remaining;
                } else {
                  final total = (d['total_price'] as num?)?.toDouble() ?? 0;
                  final paid  = (d['amount_paid']  as num?)?.toDouble() ?? 0;
                  final diff  = total - paid;
                  if (diff > 0.01) outstandingBalance += diff;
                }
              }
            }

            final allDocs = salesSnap.data?.docs ?? [];

            // Period-filtered docs
            final docs = allDocs.where((doc) {
              final d  = doc.data() as Map<String, dynamic>;
              final ts = d['sale_date'] as Timestamp?;
              if (ts == null) return _period == _Period.all;
              return _inPeriod(ts.toDate().toLocal(), _period);
            }).toList();

            // Build buckets
            final bucketMap     = _buildBucketMap(allDocs, _period);
            final monthBuckets  = bucketMap.values.toList()
              ..sort((a, b) => a.month.compareTo(b.month));

            double totalRevenue      = 0;
            double downpaymentTotal  = 0;
            double balanceTotal      = 0;
            final  orderIds          = <String>{};

            for (final doc in docs) {
              final d      = doc.data() as Map<String, dynamic>;
              final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
              final type   = d['payment_type']?.toString() ?? '';
              final ordId  = d['order_id']?.toString()     ?? '';

              totalRevenue += amount;
              if (type == 'downpayment') downpaymentTotal += amount;
              if (type == 'balance' || type == 'cash' || type == 'full') balanceTotal += amount;
              if (ordId.isNotEmpty) orderIds.add(ordId);

              final ts = d['sale_date'] as Timestamp?;
              if (ts != null) {
                final dt  = ts.toDate();
                final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
                if (bucketMap.containsKey(key)) bucketMap[key]!.total += amount;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sales Report',
                          style: TextStyle(color: _T.textPrimary, fontSize: 16,
                              fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      SizedBox(height: 2),
                      Text('Revenue breakdown and trends',
                          style: TextStyle(color: _T.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _PeriodFilterBar(active: _period, onChanged: (p) => setState(() => _period = p)),
                  const SizedBox(height: 20),

                  LayoutBuilder(builder: (_, constraints) {
                    final narrow = constraints.maxWidth < 460;
                    return Wrap(
                      spacing: 10, runSpacing: 10,
                      children: [
                        _AdminReportCard(label: 'Total Revenue',      value: '₱${totalRevenue.toStringAsFixed(2)}',     color: _T.gold,                  bg: const Color(0xFFFFFBEB), border: const Color(0xFFFDE68A), narrow: narrow),
                        _AdminReportCard(label: 'Orders',             value: '${orderIds.length}',                       color: const Color(0xFF1D4ED8),  bg: const Color(0xFFEFF6FF), border: const Color(0xFFBFDBFE), narrow: narrow),
                        _AdminReportCard(label: 'Downpayments',       value: '₱${downpaymentTotal.toStringAsFixed(2)}',  color: const Color(0xFF6D28D9),  bg: const Color(0xFFF5F3FF), border: const Color(0xFFDDD6FE), narrow: narrow),
                        _AdminReportCard(label: 'Balance Collected',  value: '₱${balanceTotal.toStringAsFixed(2)}',      color: const Color(0xFF15803D),  bg: const Color(0xFFF0FDF4), border: const Color(0xFFBBF7D0), narrow: narrow),
                        _AdminReportCard(label: 'Balance to Collect', value: '₱${outstandingBalance.toStringAsFixed(2)}',color: const Color(0xFFDC2626),  bg: const Color(0xFFFEF2F2), border: const Color(0xFFFECACA), narrow: narrow,
                            tooltip: 'Total remaining balance on non-cancelled orders'),
                      ],
                    );
                  }),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _T.divider, width: 1),
                      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF1D4ED8), size: 16),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Monthly Revenue',
                                    style: TextStyle(color: _T.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                                Text(
                                  _period == _Period.all ? 'All time by month' : 'Last 6 months',
                                  style: const TextStyle(color: _T.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 160,
                          child: CustomPaint(
                            painter: _AdminChartPainter(buckets: monthBuckets),
                            child: Container(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: monthBuckets.map((b) => Column(
                            children: [
                              Text(b.label, style: const TextStyle(color: _T.textMuted, fontSize: 10)),
                              if (b.total > 0) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '₱${b.total >= 1000 ? '${(b.total / 1000).toStringAsFixed(1)}k' : b.total.toStringAsFixed(0)}',
                                  style: const TextStyle(color: _T.gold, fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ],
                          )).toList(),
                        ),
                      ],
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

class _AdminReportCard extends StatelessWidget {
  final String label, value;
  final Color color, bg, border;
  final bool narrow;
  final String? tooltip;

  const _AdminReportCard({
    required this.label,  required this.value,
    required this.color,  required this.bg,
    required this.border, required this.narrow,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: narrow ? double.infinity : 168,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500)),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  child: Icon(Icons.info_outline_rounded, size: 12, color: color.withValues(alpha: 0.5)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _AdminChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _AdminChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal       = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n            = buckets.length;
    final stepX        = n <= 1 ? size.width : size.width / (n - 1);

    final gridPaint = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(n, (i) => Offset(
      i * stepX,
      size.height - (buckets[i].total / effectiveMax) * size.height * 0.85,
    ));

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [const Color(0xFF1D4ED8).withValues(alpha: 0.15), const Color(0xFF1D4ED8).withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      linePath.cubicTo((prev.dx + curr.dx) / 2, prev.dy, (prev.dx + curr.dx) / 2, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = const Color(0xFF1D4ED8)..strokeWidth = 2.5..style = PaintingStyle.stroke);

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF1D4ED8));
    }
  }

  @override
  bool shouldRepaint(_AdminChartPainter old) => old.buckets != buckets;
}

// SalesReportView
class SalesReportView extends StatefulWidget {
  const SalesReportView({super.key});

  @override
  State<SalesReportView> createState() => _SalesReportViewState();
}

class _SalesReportViewState extends State<SalesReportView> {
  _Period _period = _Period.month;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white38));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent)));
        }

        final allDocs = snap.data?.docs ?? [];

        // Period-filtered docs
        final docs = allDocs.where((doc) {
          final d  = doc.data() as Map<String, dynamic>;
          final ts = d['sale_date'] as Timestamp?;
          if (ts == null) return _period == _Period.all;
          return _inPeriod(ts.toDate().toLocal(), _period);
        }).toList();

        // Build buckets
        final bucketMap    = _buildBucketMap(allDocs, _period);
        final monthBuckets = bucketMap.values.toList()
          ..sort((a, b) => a.month.compareTo(b.month));

        double totalRevenue     = 0;
        double downpaymentTotal = 0;
        double balanceTotal     = 0;
        final  orderIds         = <String>{};

        for (final doc in docs) {
          final d      = doc.data() as Map<String, dynamic>;
          final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
          final type   = d['payment_type']?.toString() ?? '';
          final ordId  = d['order_id']?.toString()     ?? '';

          totalRevenue += amount;
          if (type == 'downpayment') downpaymentTotal += amount;
          if (type == 'balance' || type == 'cash' || type == 'full') balanceTotal += amount;
          if (ordId.isNotEmpty) orderIds.add(ordId);

          final ts = d['sale_date'] as Timestamp?;
          if (ts != null) {
            final dt  = ts.toDate();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            if (bucketMap.containsKey(key)) bucketMap[key]!.total += amount;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sales Report',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              _PeriodFilterBar(active: _period, onChanged: (p) => setState(() => _period = p), dark: true),
              const SizedBox(height: 16),

              LayoutBuilder(builder: (_, constraints) {
                final narrow = constraints.maxWidth < 400;
                return Wrap(
                  spacing: 10, runSpacing: 10,
                  children: [
                    _ReportCard('Total Revenue',     '₱${totalRevenue.toStringAsFixed(2)}',     AppTheme.gold,     narrow),
                    _ReportCard('Orders',            '${orderIds.length}',                       Colors.blueAccent, narrow),
                    _ReportCard('Downpayments',      '₱${downpaymentTotal.toStringAsFixed(2)}',  Colors.blue,       narrow),
                    _ReportCard('Balance Collected', '₱${balanceTotal.toStringAsFixed(2)}',      Colors.green,      narrow),
                  ],
                );
              }),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: Colors.blueAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _period == _Period.all ? 'ALL TIME BY MONTH' : 'MONTHLY REVENUE',
                    style: const TextStyle(color: Colors.white54, fontSize: 11,
                        fontWeight: FontWeight.w600, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: CustomPaint(painter: _ChartPainter(buckets: monthBuckets), child: Container()),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: monthBuckets.map((b) => Column(
                  children: [
                    Text(b.label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    if (b.total > 0)
                      Text('₱${b.total.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppTheme.gold, fontSize: 9)),
                  ],
                )).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool narrow;
  const _ReportCard(this.label, this.value, this.color, this.narrow);

  @override
  Widget build(BuildContext context) => Container(
    width: narrow ? double.infinity : 160,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

class _ChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _ChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal       = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n            = buckets.length;
    final stepX        = n <= 1 ? size.width : size.width / (n - 1);

    final gridPaint = Paint()..color = Colors.white.withValues(alpha: 0.08)..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(n, (i) => Offset(
      i * stepX,
      size.height - (buckets[i].total / effectiveMax) * size.height * 0.85,
    ));

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.blueAccent.withValues(alpha: 0.3), Colors.blueAccent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      linePath.cubicTo((prev.dx + curr.dx) / 2, prev.dy, (prev.dx + curr.dx) / 2, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, Paint()
      ..color = Colors.blueAccent..strokeWidth = 2.5..style = PaintingStyle.stroke);

    final dotBg   = Paint()..color = const Color(0xFF1a1a2e);
    final dotFill = Paint()..color = Colors.blueAccent;
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBg);
      canvas.drawCircle(p, 4, dotFill);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.buckets != buckets;
}