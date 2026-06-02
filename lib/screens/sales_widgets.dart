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
  static const Color navy = Color(0xFF1A1A2E);
}

// ── Date filter helpers ───────────────────────────────────────────────────────
DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

String _formatDateLabel(DateTime date) {
  const mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${mo[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
}

String _formatDateRangeLabel(DateTimeRange? range) {
  if (range == null) return 'All Dates';
  final start = _formatDateLabel(range.start);
  final end = _formatDateLabel(range.end);
  return start == end ? start : '$start – $end';
}

bool _isWithinDateRange(DateTime date, DateTimeRange? range) {
  if (range == null) return true;
  final day = _dateOnly(date);
  final start = _dateOnly(range.start);
  final end = _dateOnly(range.end);
  return !day.isBefore(start) && !day.isAfter(end);
}

// ── Date picker dialog ────────────────────────────────────────────────────────
Future<void> _pickSalesDateRange({
  required BuildContext context,
  required DateTimeRange? selectedRange,
  required ValueChanged<DateTimeRange?> onChanged,
  bool dark = false,
}) async {
  final now = DateTime.now();
  final start = _dateOnly(selectedRange?.start ?? now);
  final end = _dateOnly(selectedRange?.end ?? now);

  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _SalesDatePickerDialog(
      initialStart: start,
      initialEnd: end,
      dark: dark,
      onApply: (s, e) => onChanged(DateTimeRange(start: s, end: e)),
      onClear: () => onChanged(null),
    ),
  );
}

// ── Custom date picker dialog widget ─────────────────────────────────────────
class _SalesDatePickerDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final bool dark;
  final void Function(DateTime start, DateTime end) onApply;
  final VoidCallback onClear;

  const _SalesDatePickerDialog({
    required this.initialStart,
    required this.initialEnd,
    required this.dark,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_SalesDatePickerDialog> createState() => _SalesDatePickerDialogState();
}

class _SalesDatePickerDialogState extends State<_SalesDatePickerDialog> {
  late DateTime _start;
  late DateTime _end;
  late bool _pickingStart;
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _pickingStart = true;
    _viewMonth = DateTime(_start.year, _start.month);
  }

  // ── Theming helpers ────────────────────────────────────────────────────────
  Color get _bg => widget.dark ? const Color(0xFF1A1A2E) : Colors.white;
  Color get _surface => widget.dark ? const Color(0xFF242440) : const Color(0xFFF9FAFB);
  Color get _border => widget.dark ? Colors.white.withValues(alpha: 0.12) : _T.divider;
  Color get _textPrimary => widget.dark ? Colors.white : _T.textPrimary;
  Color get _textMuted => widget.dark ? Colors.white54 : _T.textMuted;
  Color get _accent => widget.dark ? AppTheme.gold : _T.navy;
  Color get _accentFg => widget.dark ? Colors.black : Colors.white;

  void _prevMonth() => setState(() =>
  _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1));
  void _nextMonth() => setState(() =>
  _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1));

  void _onDayTap(DateTime day) {
    setState(() {
      if (_pickingStart) {
        _start = day;
        if (_start.isAfter(_end)) _end = _start;
        _pickingStart = false;
      } else {
        _end = day;
        if (_end.isBefore(_start)) _start = _end;
        _pickingStart = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.dark ? 0.5 : 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildDateBoxes(),
              _buildDivider(),
              _buildCalendarHeader(),
              _buildWeekLabels(),
              _buildDayGrid(),
              _buildDivider(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: widget.dark ? 0.18 : 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          child: Icon(Icons.calendar_month_rounded, size: 15, color: _accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Select date range',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 18, color: _textMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );

  Widget _buildDateBoxes() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    child: Row(
      children: [
        _DateBox(
          label: 'Start',
          date: _start,
          active: _pickingStart,
          dark: widget.dark,
          accent: _accent,
          textPrimary: _textPrimary,
          textMuted: _textMuted,
          surface: _surface,
          border: _border,
          onTap: () => setState(() => _pickingStart = true),
        ),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward_rounded, size: 14, color: _textMuted),
        const SizedBox(width: 8),
        _DateBox(
          label: 'End',
          date: _end,
          active: !_pickingStart,
          dark: widget.dark,
          accent: _accent,
          textPrimary: _textPrimary,
          textMuted: _textMuted,
          surface: _surface,
          border: _border,
          onTap: () => setState(() => _pickingStart = false),
        ),
      ],
    ),
  );

  Widget _buildCalendarHeader() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: _prevMonth,
            dark: widget.dark,
            accent: _accent,
          ),
          Expanded(
            child: Center(
              child: Text(
                '${months[_viewMonth.month - 1]} ${_viewMonth.year}',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: _nextMonth,
            dark: widget.dark,
            accent: _accent,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekLabels() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(
      children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
          .map((d) => Expanded(
        child: Center(
          child: Text(
            d,
            style: TextStyle(
              color: _textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ))
          .toList(),
    ),
  );

  Widget _buildDayGrid() {
    final firstOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final startOffset = firstOfMonth.weekday % 7; // 0 = Sunday

    final cells = <Widget>[];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_viewMonth.year, _viewMonth.month, day);
      final isStart = _dateOnly(date) == _dateOnly(_start);
      final isEnd = _dateOnly(date) == _dateOnly(_end);
      final inRange = !date.isBefore(_start) && !date.isAfter(_end);
      final isToday = _dateOnly(date) == _dateOnly(DateTime.now());

      cells.add(_DayCell(
        day: day,
        isStart: isStart,
        isEnd: isEnd,
        inRange: inRange,
        isToday: isToday,
        dark: widget.dark,
        accent: _accent,
        accentFg: _accentFg,
        textPrimary: _textPrimary,
        textMuted: _textMuted,
        onTap: () => _onDayTap(date),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.1,
        children: cells,
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: _border);

  Widget _buildFooter() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
    child: Row(
      children: [
        TextButton(
          onPressed: () {
            widget.onClear();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: _textMuted,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('Clear', style: TextStyle(fontSize: 13)),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: _textMuted,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            widget.onApply(_start, _end);
            Navigator.of(context).pop();
          },
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: _accentFg,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Apply',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

// ── Start / End date selection box ────────────────────────────────────────────
class _DateBox extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool active;
  final bool dark;
  final Color accent, textPrimary, textMuted, surface, border;
  final VoidCallback onTap;

  const _DateBox({
    required this.label,
    required this.date,
    required this.active,
    required this.dark,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = accent.withValues(alpha: dark ? 0.16 : 0.07);
    final activeBorder = accent.withValues(alpha: 0.45);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? activeBg : surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? activeBorder : border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? accent : textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                _formatDateLabel(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Month navigation button ───────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dark;
  final Color accent;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.dark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: dark ? Colors.white70 : _T.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Individual day cell ───────────────────────────────────────────────────────
class _DayCell extends StatelessWidget {
  final int day;
  final bool isStart, isEnd, inRange, isToday, dark;
  final Color accent, accentFg, textPrimary, textMuted;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.isToday,
    required this.dark,
    required this.accent,
    required this.accentFg,
    required this.textPrimary,
    required this.textMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEdge = isStart || isEnd;
    final rangeBg = accent.withValues(alpha: dark ? 0.14 : 0.08);

    Color cellBg = Colors.transparent;
    Color textColor = textMuted;
    bool showRing = false;

    if (isEdge) {
      cellBg = accent;
      textColor = accentFg;
    } else if (inRange) {
      cellBg = rangeBg;
      textColor = dark ? Colors.white.withValues(alpha: 0.9) : textPrimary;
    } else if (isToday) {
      showRing = true;
      textColor = accent;
    }

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cellBg,
            shape: BoxShape.circle,
            border: showRing ? Border.all(color: accent, width: 1.5) : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: isEdge ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date filter button (trigger chip) ─────────────────────────────────────────
class _DateFilterButton extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final ValueChanged<DateTimeRange?> onChanged;
  final bool dark;

  const _DateFilterButton({
    required this.selectedRange,
    required this.onChanged,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedRange != null;

    final Color bg = dark
        ? Colors.white.withValues(alpha: 0.07)
        : (hasDate ? const Color(0xFFFFFBEB) : const Color(0xFFF9FAFB));
    final Color border = dark
        ? Colors.white.withValues(alpha: hasDate ? 0.22 : 0.12)
        : (hasDate ? const Color(0xFFFDE68A) : _T.divider);
    final Color iconClr = dark
        ? (hasDate ? AppTheme.gold : Colors.white54)
        : (hasDate ? _T.gold : _T.textMuted);
    final Color textClr = dark
        ? (hasDate ? Colors.white : Colors.white70)
        : (hasDate ? _T.gold : _T.textSecondary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickSalesDateRange(
            context: context,
            selectedRange: selectedRange,
            onChanged: onChanged,
            dark: dark,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border, width: hasDate ? 1.5 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_month_rounded, size: 14, color: iconClr),
                const SizedBox(width: 8),
                Text(
                  _formatDateRangeLabel(selectedRange),
                  style: TextStyle(
                    color: textClr,
                    fontSize: 12,
                    fontWeight: hasDate ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasDate) ...[
          const SizedBox(width: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(null),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: dark ? Colors.white54 : _T.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Grouped record model ──────────────────────────────────────────────────────
// Represents all Sales_Records for a single order_id merged into one entry.
class _GroupedRecord {
  final String orderId;
  final String custName;
  final String custId;
  final double totalPaid; // sum of sale_amount across all records for this order
  final double orderTotal; // order_total field (same across records)
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
    List<QueryDocumentSnapshot> docs,
    ) async {
  // Accumulate per order_id
  final Map<String, List<Map<String, dynamic>>> byOrder = {};
  final Map<String, List<DocumentReference>> refsByOrder = {};

  for (final doc in docs) {
    final d = doc.data() as Map<String, dynamic>;
    final orderId = d['order_id']?.toString() ?? doc.id;
    byOrder.putIfAbsent(orderId, () => []).add(d);
    refsByOrder.putIfAbsent(orderId, () => []).add(doc.reference);
  }

  // Collect order IDs that are missing customer_id so we can batch-resolve them
  final missingCustIdOrders = <String>{};
  for (final orderId in byOrder.keys) {
    final records = byOrder[orderId]!;
    final hasCustId = records.any(
          (r) => (r['customer_id']?.toString() ?? '').isNotEmpty,
    );
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
          final d = doc.data();
          final ordId = d['order_id']?.toString() ?? '';
          final uid = d['customer_uid']?.toString() ?? '';
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
    final refs = refsByOrder[orderId]!;

    double totalPaid = 0;
    double orderTotal = 0;
    String custName = '—';
    String custId = '';
    String? lastMethod;
    Timestamp? latestTs;
    String derivedType = 'downpayment';

    for (final r in records) {
      totalPaid += (r['sale_amount'] as num?)?.toDouble() ?? 0;
      final ot = (r['order_total'] as num?)?.toDouble() ?? 0;
      if (ot > orderTotal) orderTotal = ot;
      if ((r['customer_name']?.toString() ?? '').isNotEmpty)
        custName = r['customer_name'];
      if ((r['customer_id']?.toString() ?? '').isNotEmpty)
        custId = r['customer_id'];
      if ((r['payment_method']?.toString() ?? '').isNotEmpty)
        lastMethod = r['payment_method'];

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

    groups.add(
      _GroupedRecord(
        orderId: orderId,
        custName: custName,
        custId: custId,
        totalPaid: totalPaid,
        orderTotal: orderTotal,
        paymentType: derivedType,
        paymentMethod: lastMethod,
        latestDate: latestTs,
        docRefs: refs,
      ),
    );
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
  DateTimeRange? _selectedRange;
  String _search = '';

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
      setState(() {
        _snapshot = snap;
        _groupsLoading = true;
      });
      final groups = await _groupRecordsAsync(snap.docs);
      if (mounted)
        setState(() {
          _allGroups = groups;
          _groupsLoading = false;
        });
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
    final d = ts.toDate().toLocal();
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${mo[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'downpayment':
        return 'Downpayment';
      case 'balance':
        return 'Balance';
      case 'full':
        return 'Full Payment';
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

  @override
  Widget build(BuildContext context) {
    if (_snapshot == null || _groupsLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: _T.textPrimary.withValues(alpha: 0.4),
        ),
      );
    }

    // Group all raw docs by order_id first
    final allGroups = _allGroups;

    // Period filter — use the group's latest payment date
    var filtered = allGroups.where((g) {
      final ts = g.latestDate;
      if (ts == null) return _selectedRange == null;
      return _isWithinDateRange(ts.toDate().toLocal(), _selectedRange);
    }).toList();

    // Type filter — match against derived paymentType
    if (_typeFilter != 'all') {
      filtered = filtered.where((g) => g.paymentType == _typeFilter).toList();
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
    final allTotal = allGroups.fold<double>(0, (s, g) => s + g.totalPaid);

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
                  label: _selectedRange == null ? 'Total' : 'Date Total',
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
            selectedRange: _selectedRange,
            activeType: _typeFilter,
            onDateChanged: (range) => setState(() => _selectedRange = range),
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
                    style: TextStyle(color: _T.textSecondary, fontSize: 13),
                  ),
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
            delegate: SliverChildBuilderDelegate((_, i) {
              final g = filtered[i];
              return _SalesRecordCard(
                index: i,
                orderId: g.orderId,
                custName: g.custName,
                custId: g.custId,
                type: g.paymentType,
                method: g.paymentMethod,
                totalPaid: g.totalPaid,
                orderTotal: g.orderTotal,
                date: _fmt(g.latestDate),
                typeFg: _typeFg(g.paymentType),
                typeBg: _typeBg(g.paymentType),
                typeBorder: _typeBorder(g.paymentType),
                typeLabel: _typeLabel(g.paymentType),
                methodLabel: _methodLabel(g.paymentMethod),
              );
            }, childCount: filtered.length),
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
  final double totalPaid; // cumulative total paid across all records
  final double orderTotal; // full order value
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
    final hasBalance = orderTotal > 0 && !isFullyPaid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
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
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: _T.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        orderId,
                        style: const TextStyle(
                          color: _T.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 10,
                            color: _T.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            date,
                            style: const TextStyle(
                              color: _T.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Total paid (cumulative across all payments for this order)
                    Text(
                      '₱${totalPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: _T.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (orderTotal > 0)
                      Text(
                        'of ₱${orderTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _T.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      methodLabel,
                      style: const TextStyle(
                        color: _T.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Paid ₱${totalPaid.toStringAsFixed(2)}',
                    style: const TextStyle(color: _T.textMuted, fontSize: 10),
                  ),
                  Text(
                    'Remaining ₱${(orderTotal - totalPaid).clamp(0, double.infinity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: _T.textMuted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        custName,
                        style: const TextStyle(
                          color: _T.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (custId.isNotEmpty)
                        Text(
                          'ID: $custId',
                          style: const TextStyle(
                            color: _T.textMuted,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: typeBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeBorder, width: 1),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: typeFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

// =============================================================================
// Unified Filter Bar
// =============================================================================
class _UnifiedFilterBar extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final String activeType;
  final ValueChanged<DateTimeRange?> onDateChanged;
  final ValueChanged<String> onTypeChanged;

  const _UnifiedFilterBar({
    required this.selectedRange,
    required this.activeType,
    required this.onDateChanged,
    required this.onTypeChanged,
  });

  static const _typeOptions = [
    ('all', 'All Types', Color(0xFF374151)),
    ('downpayment', 'Downpayment', Color(0xFF1D4ED8)),
    ('balance', 'Balance', Color(0xFFB45309)),
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
          // Date row
          Row(
            children: [
              SizedBox(
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
                      'Date',
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
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _DateFilterButton(
                    selectedRange: selectedRange,
                    onChanged: onDateChanged,
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

// ─ Summary chip ──────────────────────────────────────────────────────────────
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

// ─ Table header cell ─────────────────────────────────────────────────────────
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

// ─ Month bucket ──────────────────────────────────────────────────────────────
class _MonthBucket {
  final DateTime month;
  final String label;
  double total;
  _MonthBucket({required this.month, required this.label, required this.total});
}

// ─ Shared bucket builder ─────────────────────────────────────────────────────
String _shortMonth(int m) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[m - 1];
}

Map<String, _MonthBucket> _buildBucketMap(
    List<QueryDocumentSnapshot> allDocs,
    DateTimeRange? selectedRange,
    ) {
  final now = DateTime.now();
  if (selectedRange != null) {
    final map = <String, _MonthBucket>{};
    var m = DateTime(selectedRange.start.year, selectedRange.start.month);
    final end = DateTime(selectedRange.end.year, selectedRange.end.month);
    while (!m.isAfter(end)) {
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      map[key] = _MonthBucket(
        month: m,
        label: m.year == now.year
            ? _shortMonth(m.month)
            : '${_shortMonth(m.month)} \'${m.year.toString().substring(2)}',
        total: 0,
      );
      m = DateTime(m.year, m.month + 1);
    }
    return map;
  }

  // All Time: derive buckets from every document
  final map = <String, _MonthBucket>{};
  for (final doc in allDocs) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['sale_date'] as Timestamp?;
    if (ts == null) continue;
    final dt = ts.toDate();
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
      final m = DateTime(now.year, now.month - (5 - i));
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      map[key] = _MonthBucket(month: m, label: _shortMonth(m.month), total: 0);
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
  DateTimeRange? _selectedRange;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, salesSnap) {
        if (salesSnap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _T.textPrimary.withValues(alpha: 0.4),
            ),
          );
        }
        if (salesSnap.hasError) {
          return Center(
            child: Text(
              'Error: ${salesSnap.error}',
              style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Orders')
              .where(
            'status',
            whereIn: ['pending', 'in_production', 'ready', 'completed'],
          )
              .snapshots(),
          builder: (context, ordersSnap) {
            double outstandingBalance = 0;
            if (ordersSnap.hasData) {
              for (final doc in ordersSnap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                final remaining = (d['remaining_balance'] as num?)?.toDouble();
                if (remaining != null && remaining > 0.01) {
                  outstandingBalance += remaining;
                } else {
                  final total = (d['total_price'] as num?)?.toDouble() ?? 0;
                  final paid = (d['amount_paid'] as num?)?.toDouble() ?? 0;
                  final diff = total - paid;
                  if (diff > 0.01) outstandingBalance += diff;
                }
              }
            }

            final allDocs = salesSnap.data?.docs ?? [];

            // Period-filtered docs
            final docs = allDocs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final ts = d['sale_date'] as Timestamp?;
              if (ts == null) return _selectedRange == null;
              return _isWithinDateRange(ts.toDate().toLocal(), _selectedRange);
            }).toList();

            // Build buckets
            final bucketMap = _buildBucketMap(allDocs, _selectedRange);
            final monthBuckets = bucketMap.values.toList()
              ..sort((a, b) => a.month.compareTo(b.month));

            double totalRevenue = 0;
            double downpaymentTotal = 0;
            double balanceTotal = 0;
            final orderIds = <String>{};

            for (final doc in docs) {
              final d = doc.data() as Map<String, dynamic>;
              final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
              final type = d['payment_type']?.toString() ?? '';
              final ordId = d['order_id']?.toString() ?? '';

              totalRevenue += amount;
              if (type == 'downpayment') downpaymentTotal += amount;
              if (type == 'balance' || type == 'cash' || type == 'full')
                balanceTotal += amount;
              if (ordId.isNotEmpty) orderIds.add(ordId);

              final ts = d['sale_date'] as Timestamp?;
              if (ts != null) {
                final dt = ts.toDate();
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
                  const SizedBox(height: 12),

                  _DateFilterButton(
                    selectedRange: _selectedRange,
                    onChanged: (range) =>
                        setState(() => _selectedRange = range),
                  ),
                  const SizedBox(height: 20),

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
                          _AdminReportCard(
                            label: 'Balance to Collect',
                            value: '₱${outstandingBalance.toStringAsFixed(2)}',
                            color: const Color(0xFFDC2626),
                            bg: const Color(0xFFFEF2F2),
                            border: const Color(0xFFFECACA),
                            narrow: narrow,
                            tooltip:
                            'Total remaining balance on non-cancelled orders',
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

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
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: const Icon(
                                Icons.bar_chart_rounded,
                                color: Color(0xFF1D4ED8),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monthly Revenue',
                                  style: TextStyle(
                                    color: _T.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  _selectedRange == null
                                      ? 'All time by month'
                                      : 'Selected range by month',
                                  style: const TextStyle(
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
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.border,
    required this.narrow,
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
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip!,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 12,
                    color: color.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
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
    final stepX = n <= 1 ? size.width : size.width / (n - 1);

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

// SalesReportView
class SalesReportView extends StatefulWidget {
  const SalesReportView({super.key});

  @override
  State<SalesReportView> createState() => _SalesReportViewState();
}

class _SalesReportViewState extends State<SalesReportView> {
  DateTimeRange? _selectedRange;

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

        // Period-filtered docs
        final docs = allDocs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final ts = d['sale_date'] as Timestamp?;
          if (ts == null) return _selectedRange == null;
          return _isWithinDateRange(ts.toDate().toLocal(), _selectedRange);
        }).toList();

        // Build buckets
        final bucketMap = _buildBucketMap(allDocs, _selectedRange);
        final monthBuckets = bucketMap.values.toList()
          ..sort((a, b) => a.month.compareTo(b.month));

        double totalRevenue = 0;
        double downpaymentTotal = 0;
        double balanceTotal = 0;
        final orderIds = <String>{};

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final amount = (d['sale_amount'] as num?)?.toDouble() ?? 0;
          final type = d['payment_type']?.toString() ?? '';
          final ordId = d['order_id']?.toString() ?? '';

          totalRevenue += amount;
          if (type == 'downpayment') downpaymentTotal += amount;
          if (type == 'balance' || type == 'cash' || type == 'full')
            balanceTotal += amount;
          if (ordId.isNotEmpty) orderIds.add(ordId);

          final ts = d['sale_date'] as Timestamp?;
          if (ts != null) {
            final dt = ts.toDate();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            if (bucketMap.containsKey(key)) bucketMap[key]!.total += amount;
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

              _DateFilterButton(
                selectedRange: _selectedRange,
                onChanged: (range) => setState(() => _selectedRange = range),
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

              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.blueAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedRange == null
                        ? 'ALL TIME BY MONTH'
                        : 'SELECTED RANGE REVENUE',
                    style: const TextStyle(
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

class _ChartPainter extends CustomPainter {
  final List<_MonthBucket> buckets;
  _ChartPainter({required this.buckets});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1.0 : maxVal;
    final n = buckets.length;
    final stepX = n <= 1 ? size.width : size.width / (n - 1);

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