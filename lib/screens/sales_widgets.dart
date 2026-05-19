// Shared widgets for Sales Record and Sales Report.
// Used by BOTH the employee and admin screens.
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
  static const Color gold = Color(0xFFB45309); // amber-700
}

// ── Period filter enum shared by both record and report ───────────────────────
enum _Period { day, week, month, year, all }

extension _PeriodLabel on _Period {
  String get label {
    switch (this) {
      case _Period.day:
        return 'Today';
      case _Period.week:
        return 'This Week';
      case _Period.month:
        return 'This Month';
      case _Period.year:
        return 'This Year';
      case _Period.all:
        return 'All Time';
    }
  }

  String get shortLabel {
    switch (this) {
      case _Period.day:
        return 'Today';
      case _Period.week:
        return 'Week';
      case _Period.month:
        return 'Month';
      case _Period.year:
        return 'Year';
      case _Period.all:
        return 'All';
    }
  }
}

bool _inPeriod(DateTime dt, _Period period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case _Period.day:
      return !dt.isBefore(today);
    case _Period.week:
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      return !dt.isBefore(weekStart);
    case _Period.month:
      return dt.year == now.year && dt.month == now.month;
    case _Period.year:
      return dt.year == now.year;
    case _Period.all:
      return true;
  }
}

// ── Period filter bar (shared UI component) ───────────────────────────────────
class _PeriodFilterBar extends StatelessWidget {
  final _Period active;
  final ValueChanged<_Period> onChanged;
  final bool dark; // true = dark pill style (employee), false = light (admin)

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
                    : (dark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? (dark ? AppTheme.gold : const Color(0xFF1A1A2E))
                      : (dark
                            ? Colors.white.withValues(alpha: 0.18)
                            : _T.divider),
                  width: 1,
                ),
                boxShadow: (isActive && !dark)
                    ? [
                        const BoxShadow(
                          color: Color(0x20000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ]
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
  _Period _period = _Period.all;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fmt(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate().toLocal();
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${mo[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'downpayment':
        return 'Downpayment';
      case 'balance':
        return 'Balance';
      case 'cash':
        return 'Cash';
      case 'full':
        return 'Full';
      default:
        return (t != null && t.isNotEmpty) ? t : '—';
    }
  }

  Color _typeFg(String? t) {
    switch (t) {
      case 'downpayment':
        return const Color(0xFF1D4ED8);
      case 'balance':
        return const Color(0xFFB45309);
      case 'cash':
        return const Color(0xFF15803D);
      case 'full':
        return const Color(0xFF6D28D9);
      default:
        return _T.textMuted;
    }
  }

  Color _typeBg(String? t) {
    switch (t) {
      case 'downpayment':
        return const Color(0xFFEFF6FF);
      case 'balance':
        return const Color(0xFFFFFBEB);
      case 'cash':
        return const Color(0xFFF0FDF4);
      case 'full':
        return const Color(0xFFF5F3FF);
      default:
        return _T.headerBg;
    }
  }

  Color _typeBorder(String? t) {
    switch (t) {
      case 'downpayment':
        return const Color(0xFFBFDBFE);
      case 'balance':
        return const Color(0xFFFDE68A);
      case 'cash':
        return const Color(0xFFBBF7D0);
      case 'full':
        return const Color(0xFFDDD6FE);
      default:
        return _T.divider;
    }
  }

  String _methodLabel(String? m) {
    switch (m) {
      case 'gcash':
        return 'GCash';
      case 'card':
        return 'Card';
      case 'maya':
        return 'Maya';
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      default:
        return (m != null && m.isNotEmpty) ? m : '—';
    }
  }

  // ── Type filter data ──────────────────────────────────────────────────────
  static const _typeOptions = [
    ('all', 'All Types', null),
    ('downpayment', 'Downpayment', Color(0xFF1D4ED8)),
    ('balance', 'Balance', Color(0xFFB45309)),
    ('cash', 'Cash', Color(0xFF15803D)),
    ('full', 'Full', Color(0xFF6D28D9)),
  ];

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Sales_Records')
        .orderBy('sale_date', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _T.textPrimary.withValues(alpha: 0.4),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Color(0xFFDC2626)),
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];

        // Apply period filter
        var filtered = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final ts = data['sale_date'] as Timestamp?;
          if (ts == null) return _period == _Period.all;
          return _inPeriod(ts.toDate().toLocal(), _period);
        }).toList();

        // Apply type filter
        if (_typeFilter != 'all') {
          filtered = filtered
              .where(
                (d) =>
                    (d.data() as Map)['payment_type']?.toString() ==
                    _typeFilter,
              )
              .toList();
        }

        // Apply search
        if (_search.isNotEmpty) {
          filtered = filtered.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final ordId = (data['order_id']?.toString() ?? '').toLowerCase();
            final cust = (data['customer_name']?.toString() ?? '')
                .toLowerCase();
            return ordId.contains(_search) || cust.contains(_search);
          }).toList();
        }

        final totalCollected = filtered.fold<double>(
          0,
          (s, d) =>
              s + ((d.data() as Map)['sale_amount'] as num? ?? 0).toDouble(),
        );
        final allTotal = allDocs.fold<double>(
          0,
          (s, d) =>
              s + ((d.data() as Map)['sale_amount'] as num? ?? 0).toDouble(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top controls ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: Summary chips (Period Total | Records | All-Time) ──
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Row 2: Unified filter bar ──────────────────────────
                  _UnifiedFilterBar(
                    activePeriod: _period,
                    activeType: _typeFilter,
                    onPeriodChanged: (p) => setState(() => _period = p),
                    onTypeChanged: (t) => setState(() => _typeFilter = t),
                  ),
                  const SizedBox(height: 12),

                  // ── Row 3: Search field ────────────────────────────────
                  TextFormField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _search = v.trim().toLowerCase()),
                    style: const TextStyle(color: _T.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by order ID or customer name…',
                      hintStyle: const TextStyle(
                        color: _T.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 16,
                        color: _T.textMuted,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                              child: const Icon(
                                Icons.clear,
                                size: 16,
                                color: _T.textMuted,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppTheme.gold.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Table header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _T.headerBg,
                border: Border(
                  top: BorderSide(color: _T.divider),
                  bottom: BorderSide(color: _T.divider),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: _H('Order')),
                  Expanded(flex: 3, child: _H('Customer')),
                  Expanded(flex: 2, child: _H('Type')),
                  Expanded(flex: 2, child: _H('Method')),
                  Expanded(flex: 2, child: _H('Amount')),
                  Expanded(flex: 3, child: _H('Date')),
                ],
              ),
            ),

            // ── Rows ──────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: _T.headerBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _T.divider),
                            ),
                            child: const Icon(
                              Icons.receipt_long_outlined,
                              size: 32,
                              color: _T.textMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No sales records found',
                            style: TextStyle(
                              color: _T.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              color: _T.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: _T.divider),
                      itemBuilder: (_, i) {
                        final d = filtered[i].data() as Map<String, dynamic>;
                        final type = d['payment_type']?.toString();
                        final method = d['payment_method']?.toString();
                        final amount =
                            (d['sale_amount'] as num?)?.toDouble() ?? 0;
                        final orderId = d['order_id']?.toString() ?? '—';
                        final custName = d['customer_name']?.toString() ?? '—';
                        final date = _fmt(d['sale_date'] as Timestamp?);

                        return Container(
                          color: i.isEven
                              ? Colors.white
                              : const Color(0xFFFAFAFA),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  orderId,
                                  style: const TextStyle(
                                    color: _T.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  custName.length > 14
                                      ? '${custName.substring(0, 12)}…'
                                      : custName,
                                  style: const TextStyle(
                                    color: _T.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _typeBg(type),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _typeBorder(type),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _typeLabel(type),
                                      style: TextStyle(
                                        color: _typeFg(type),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _methodLabel(method),
                                  style: const TextStyle(
                                    color: _T.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₱${amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: _T.gold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  date,
                                  style: const TextStyle(
                                    color: _T.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Unified Filter Bar — period + type in a single organised panel
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
    ('all', 'All Types', Color(0xFF374151)),
    ('downpayment', 'Downpayment', Color(0xFF1D4ED8)),
    ('balance', 'Balance', Color(0xFFB45309)),
    ('cash', 'Cash', Color(0xFF15803D)),
    ('full', 'Full', Color(0xFF6D28D9)),
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
          // ── Period row ─────────────────────────────────────────────────
          Row(
            children: [
              // Label
              Container(
                width: 72,
                child: Row(
                  children: const [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: _T.textMuted,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Period',
                      style: TextStyle(
                        color: _T.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Period pills
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF1A1A2E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF1A1A2E)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    const BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            p.shortLabel,
                            style: TextStyle(
                              color: isActive ? Colors.white : _T.textSecondary,
                              fontSize: 12,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
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

          // ── Type row ───────────────────────────────────────────────────
          Row(
            children: [
              // Label
              Container(
                width: 72,
                child: Row(
                  children: const [
                    Icon(
                      Icons.label_outline_rounded,
                      size: 12,
                      color: _T.textMuted,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Type',
                      style: TextStyle(
                        color: _T.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Type pills
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeOptions.map((opt) {
                      final isActive = activeType == opt.$1;
                      final accent = opt.$3;
                      return GestureDetector(
                        onTap: () => onTypeChanged(opt.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? accent.withValues(alpha: 0.10)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive
                                  ? accent.withValues(alpha: 0.50)
                                  : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isActive) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                opt.$2,
                                style: TextStyle(
                                  color: isActive ? accent : _T.textSecondary,
                                  fontSize: 12,
                                  fontWeight: isActive
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color fg, bg, border;
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.fg,
    required this.bg,
    required this.border,
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
        Text(
          label,
          style: TextStyle(
            color: fg.withValues(alpha: 0.65),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

// ── Filter chip ───────────────────────────────────────────────────────────────
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
          border: Border.all(
            color: sel ? const Color(0xFF1A1A2E) : _T.divider,
            width: 1,
          ),
          boxShadow: sel
              ? [
                  const BoxShadow(
                    color: Color(0x20000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : _T.textSecondary,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Table header cell ─────────────────────────────────────────────────────────
class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF374151),
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 0.4,
    ),
  );
}

// =============================================================================
// AdminSalesReportView — light-themed, with period filter (Year/Month/Week/Day)
// =============================================================================
class AdminSalesReportView extends StatefulWidget {
  const AdminSalesReportView({super.key});

  @override
  State<AdminSalesReportView> createState() => _AdminSalesReportViewState();
}

class _AdminSalesReportViewState extends State<AdminSalesReportView> {
  _Period _period = _Period.month;

  static String _shortMonth(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _T.textPrimary.withValues(alpha: 0.4),
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['sale_date'] as Timestamp?;
          if (ts == null) return _period == _Period.all;
          return _inPeriod(ts.toDate().toLocal(), _period);
        }).toList();

        double totalRevenue = 0;
        double downpaymentTotal = 0;
        double balanceTotal = 0;
        final orderIds = <String>{};

        final now = DateTime.now();
        final monthBuckets = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i));
          return _MonthBucket(month: m, label: _shortMonth(m.month), total: 0);
        });

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
          final type = d['payment_type']?.toString() ?? '';
          final ordId = d['order_id']?.toString() ?? '';

          totalRevenue += amount;
          if (type == 'downpayment') downpaymentTotal += amount;
          if (type == 'balance' || type == 'cash') balanceTotal += amount;
          if (ordId.isNotEmpty) orderIds.add(ordId);

          final ts = d['sale_date'] as Timestamp?;
          if (ts != null) {
            final dt = ts.toDate();
            for (final b in monthBuckets) {
              if (b.month.year == dt.year && b.month.month == dt.month) {
                b.total += amount;
                break;
              }
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + period filter
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales Report',
                          style: TextStyle(
                            color: _T.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Revenue breakdown and trends',
                          style: TextStyle(color: _T.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Period filter bar
              _PeriodFilterBar(
                active: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 20),

              // KPI cards
              LayoutBuilder(
                builder: (_, constraints) {
                  final narrow = constraints.maxWidth < 460;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _AdminReportCard(
                        label: 'Total Revenue',
                        value: '₱${totalRevenue.toStringAsFixed(2)}',
                        color: _T.gold,
                        bg: const Color(0xFFFFFBEB),
                        border: const Color(0xFFFDE68A),
                        narrow: narrow,
                      ),
                      _AdminReportCard(
                        label: 'Orders',
                        value: '${orderIds.length}',
                        color: const Color(0xFF1D4ED8),
                        bg: const Color(0xFFEFF6FF),
                        border: const Color(0xFFBFDBFE),
                        narrow: narrow,
                      ),
                      _AdminReportCard(
                        label: 'Downpayments',
                        value: '₱${downpaymentTotal.toStringAsFixed(2)}',
                        color: const Color(0xFF6D28D9),
                        bg: const Color(0xFFF5F3FF),
                        border: const Color(0xFFDDD6FE),
                        narrow: narrow,
                      ),
                      _AdminReportCard(
                        label: 'Balance Collected',
                        value: '₱${balanceTotal.toStringAsFixed(2)}',
                        color: const Color(0xFF15803D),
                        bg: const Color(0xFFF0FDF4),
                        border: const Color(0xFFBBF7D0),
                        narrow: narrow,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Chart section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _T.divider, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Color(0xFF1D4ED8),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monthly Revenue',
                              style: TextStyle(
                                color: _T.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Last 6 months',
                              style: TextStyle(
                                color: _T.textMuted,
                                fontSize: 11,
                              ),
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
                      children: monthBuckets
                          .map(
                            (b) => Column(
                              children: [
                                Text(
                                  b.label,
                                  style: const TextStyle(
                                    color: _T.textMuted,
                                    fontSize: 10,
                                  ),
                                ),
                                if (b.total > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '₱${b.total >= 1000 ? '${(b.total / 1000).toStringAsFixed(1)}k' : b.total.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: _T.gold,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AdminReportCard extends StatelessWidget {
  final String label, value;
  final Color color, bg, border;
  final bool narrow;

  const _AdminReportCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.border,
    required this.narrow,
  });

  @override
  Widget build(BuildContext context) => Container(
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
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _AdminChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _AdminChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n = buckets.length;
    final stepX = size.width / (n - 1).clamp(1, n);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(
      n,
      (i) => Offset(
        i * stepX,
        size.height - (buckets[i].total / effectiveMax) * size.height * 0.85,
      ),
    );

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1D4ED8).withValues(alpha: 0.15),
            const Color(0xFF1D4ED8).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      linePath.cubicTo(
        (prev.dx + curr.dx) / 2,
        prev.dy,
        (prev.dx + curr.dx) / 2,
        curr.dy,
        curr.dx,
        curr.dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF1D4ED8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    for (final p in points) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF1D4ED8));
    }
  }

  @override
  bool shouldRepaint(_AdminChartPainter old) => old.buckets != buckets;
}

// =============================================================================
// SalesReportView — dark-themed (employee side), with period filter
// =============================================================================
class SalesReportView extends StatefulWidget {
  const SalesReportView({super.key});

  @override
  State<SalesReportView> createState() => _SalesReportViewState();
}

class _SalesReportViewState extends State<SalesReportView> {
  _Period _period = _Period.month;

  static String _shortMonth(int m) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white38),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['sale_date'] as Timestamp?;
          if (ts == null) return _period == _Period.all;
          return _inPeriod(ts.toDate().toLocal(), _period);
        }).toList();

        double totalRevenue = 0;
        double downpaymentTotal = 0;
        double balanceTotal = 0;
        final orderIds = <String>{};

        final now = DateTime.now();
        final monthBuckets = List.generate(6, (i) {
          final m = DateTime(now.year, now.month - (5 - i));
          return _MonthBucket(month: m, label: _shortMonth(m.month), total: 0);
        });

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
          final type = d['payment_type']?.toString() ?? '';
          final ordId = d['order_id']?.toString() ?? '';

          totalRevenue += amount;
          if (type == 'downpayment') downpaymentTotal += amount;
          if (type == 'balance' || type == 'cash') balanceTotal += amount;
          if (ordId.isNotEmpty) orderIds.add(ordId);

          final ts = d['sale_date'] as Timestamp?;
          if (ts != null) {
            final dt = ts.toDate();
            for (final b in monthBuckets) {
              if (b.month.year == dt.year && b.month.month == dt.month) {
                b.total += amount;
                break;
              }
            }
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Period filter (dark style)
              _PeriodFilterBar(
                active: _period,
                onChanged: (p) => setState(() => _period = p),
                dark: true,
              ),
              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (_, constraints) {
                  final narrow = constraints.maxWidth < 400;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ReportCard(
                        'Total Revenue',
                        '₱${totalRevenue.toStringAsFixed(2)}',
                        AppTheme.gold,
                        narrow,
                      ),
                      _ReportCard(
                        'Orders',
                        '${orderIds.length}',
                        Colors.blueAccent,
                        narrow,
                      ),
                      _ReportCard(
                        'Downpayments',
                        '₱${downpaymentTotal.toStringAsFixed(2)}',
                        Colors.blue,
                        narrow,
                      ),
                      _ReportCard(
                        'Balance Collected',
                        '₱${balanceTotal.toStringAsFixed(2)}',
                        Colors.green,
                        narrow,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              const Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.blueAccent,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'MONTHLY REVENUE',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _ChartPainter(buckets: monthBuckets),
                  child: Container(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: monthBuckets
                    .map(
                      (b) => Column(
                        children: [
                          Text(
                            b.label,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                          if (b.total > 0)
                            Text(
                              '₱${b.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    )
                    .toList(),
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
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _MonthBucket {
  final DateTime month;
  final String label;
  double total;
  _MonthBucket({required this.month, required this.label, required this.total});
}

class _ChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _ChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n = buckets.length;
    final stepX = size.width / (n - 1).clamp(1, n);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final points = List.generate(
      n,
      (i) => Offset(
        i * stepX,
        size.height - (buckets[i].total / effectiveMax) * size.height * 0.85,
      ),
    );

    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) fillPath.lineTo(p.dx, p.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blueAccent.withValues(alpha: 0.3),
            Colors.blueAccent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      linePath.cubicTo(
        (prev.dx + curr.dx) / 2,
        prev.dy,
        (prev.dx + curr.dx) / 2,
        curr.dy,
        curr.dx,
        curr.dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    final dotBg = Paint()..color = const Color(0xFF1a1a2e);
    final dotFill = Paint()..color = Colors.blueAccent;
    for (final p in points) {
      canvas.drawCircle(p, 5, dotBg);
      canvas.drawCircle(p, 4, dotFill);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.buckets != buckets;
}
