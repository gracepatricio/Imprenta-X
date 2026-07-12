// Shared widgets for Sales Record and Sales Report.
// Used by BOTH the employee and admin screens.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';

// ── Print Document / PDF report constants (Sales Report) ────────────────────
// Mirrors the business info block used by invoice_screen.dart and the Job
// Queue report for visual consistency across all generated PDFs.
const _srBizName    = 'IMPRENTA INC.';
const _srBizTagline = 'Professional Printing Services';
const _srBizAddr1   = '5th Street Pacita Avenue, Office 1 Rongavilla Building';
const _srBizAddr2   = 'San Pedro, Laguna, 4023, Philippines';
const _srBizTin     = '010-253-357-000';

// The first month of orders to scan for the Price Changes section.
final DateTime _priceChangeCutoff = DateTime(2026, 6, 1);

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

String _normalizedPaymentType(Map<String, dynamic> data) {
  final raw = data['payment_type']?.toString().toLowerCase() ?? '';
  if (raw == 'partial') return 'downpayment';
  if (raw == 'cash') return 'full';
  return raw;
}

Timestamp? _orderFilterTimestamp(Map<String, dynamic> data) {
  return data['paid_at'] as Timestamp? ??
      data['created_at'] as Timestamp? ??
      data['sale_date'] as Timestamp?;
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

  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;

  static String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  DateTime? _parse(String s) {
    try {
      final parts = s.trim().split(RegExp(r'[/\-]'));
      if (parts.length == 3) {
        final m = int.parse(parts[0]);
        final d = int.parse(parts[1]);
        final y = int.parse(parts[2]);
        if (m >= 1 && m <= 12 && d >= 1 && d <= 31 && y >= 2000) {
          return DateTime(y, m, d);
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    _pickingStart = true;
    _viewMonth = DateTime(_start.year, _start.month);
    _startCtrl = TextEditingController(text: _fmt(_start));
    _endCtrl = TextEditingController(text: _fmt(_end));
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  void _onStartTextSubmit(String val) {
    final d = _parse(val);
    if (d != null) {
      setState(() {
        _start = d;
        if (_start.isAfter(_end)) _end = _start;
        _endCtrl.text = _fmt(_end);
        _viewMonth = DateTime(_start.year, _start.month);
      });
    } else {
      _startCtrl.text = _fmt(_start);
    }
  }

  void _onEndTextSubmit(String val) {
    final d = _parse(val);
    if (d != null) {
      setState(() {
        _end = d;
        if (_end.isBefore(_start)) _start = _end;
        _startCtrl.text = _fmt(_start);
        _viewMonth = DateTime(_end.year, _end.month);
      });
    } else {
      _endCtrl.text = _fmt(_end);
    }
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
        _startCtrl.text = _fmt(_start);
        _endCtrl.text = _fmt(_end);
        _pickingStart = false;
      } else {
        _end = day;
        if (_end.isBefore(_start)) _start = _end;
        _startCtrl.text = _fmt(_start);
        _endCtrl.text = _fmt(_end);
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
        Expanded(
          child: _EditableDateBox(
            label: 'Start',
            controller: _startCtrl,
            active: _pickingStart,
            accent: _accent,
            textPrimary: _textPrimary,
            textMuted: _textMuted,
            surface: _surface,
            border: _border,
            onTap: () => setState(() => _pickingStart = true),
            onSubmit: _onStartTextSubmit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 14, color: _textMuted),
        ),
        Expanded(
          child: _EditableDateBox(
            label: 'End',
            controller: _endCtrl,
            active: !_pickingStart,
            accent: _accent,
            textPrimary: _textPrimary,
            textMuted: _textMuted,
            surface: _surface,
            border: _border,
            onTap: () => setState(() => _pickingStart = false),
            onSubmit: _onEndTextSubmit,
          ),
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
            // Parse any pending text edits before applying
            var s = _parse(_startCtrl.text) ?? _start;
            var e = _parse(_endCtrl.text) ?? _end;
            if (e.isBefore(s)) e = s;
            widget.onApply(s, e);
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

// ── Editable date box (type MM/DD/YYYY or pick from calendar) ─────────────────
class _EditableDateBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool active;
  final Color accent, textPrimary, textMuted, surface, border;
  final VoidCallback onTap;
  final ValueChanged<String> onSubmit;

  const _EditableDateBox({
    required this.label,
    required this.controller,
    required this.active,
    required this.accent,
    required this.textPrimary,
    required this.textMuted,
    required this.surface,
    required this.border,
    required this.onTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = accent.withValues(alpha: 0.07);
    final activeBorder = accent.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    width: 5, height: 5,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            TextField(
              controller: controller,
              onTap: onTap,
              onSubmitted: onSubmit,
              onEditingComplete: () => onSubmit(controller.text),
              style: TextStyle(
                color: textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: 'MM/DD/YYYY',
                hintStyle: TextStyle(color: textMuted, fontSize: 11),
              ),
            ),
          ],
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
            onTap: () => onChanged(_pLast31()),
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
  final bool isWalkIn;
  final bool isImported;    // true for historical_seed — excluded from everything
  final bool isXlsxImport; // true for manual_xlsx_import — counted in summary but hidden from list

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
    this.isWalkIn = false,
    this.isImported = false,
    this.isXlsxImport = false,
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

  // Collect order IDs that are missing customer_id so we can batch-resolve them.
  // Skip fully-imported orders — they have no matching Firestore user docs.
  final missingCustIdOrders = <String>{};
  for (final orderId in byOrder.keys) {
    final records = byOrder[orderId]!;
    final hasCustId = records.any(
          (r) => (r['customer_id']?.toString() ?? '').isNotEmpty,
    );
    if (!hasCustId) {
      final allImported = records.every(
            (r) => r['import_source'] == 'historical_seed',
      );
      if (!allImported) missingCustIdOrders.add(orderId);
    }
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
      final rAmt  = (r['sale_amount']  as num?)?.toDouble() ?? 0;
      final rType = _normalizedPaymentType(r);
      // Refunds are money returned — exclude from totalPaid so revenue stays correct
      if (rType != 'refund') totalPaid += rAmt;
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
        final t = _normalizedPaymentType(r);
        if (t.isNotEmpty) {
          derivedType = t;
        }
      }
    }

    // Fall back to resolved customer_id from Orders if still empty
    if (custId.isEmpty && resolvedCustId.containsKey(orderId)) {
      custId = resolvedCustId[orderId]!;
    }

    final isImported = records.any(
          (r) => r['import_source'] == 'historical_seed',
    );
    final isXlsxImport = !isImported && records.any(
          (r) => r['import_source'] == 'manual_xlsx_import',
    );
    final isWalkIn = records.any((r) => r['walk_in'] == true) ||
        (custId.isEmpty &&
            records.any(
                  (r) => (r['customer_name']?.toString() ?? '').isNotEmpty,
            ));

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
        isWalkIn: isWalkIn,
        isImported: isImported,
        isXlsxImport: isXlsxImport,
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
// Admin Sales Report — "Print Document" (PDF generation)
// =============================================================================
//
// The full Sales Report PDF (_buildSalesReportPdf / generateAdminSalesReportPdf)
// is the analytical companion to the lean Sales Records PDF further below
// (_buildSalesRecordsPdf / generateAdminSalesRecordsPdf). The line-item
// Sales Records table itself lives only in that companion PDF — this report
// focuses on analysis. It contains:
//   1. Sales Summary — headline totals (orders, revenue, paid/partial split).
//   2. Price Change Analysis — every product/service or add-on whose
//      per-unit price differs from the price it was sold at in its own most
//      recent prior order, where the changed price first appears in an
//      order dated June 1, 2026 or later. This app doesn't store a separate
//      product-catalog price, so "previous price" is derived by comparing
//      each product's price chronologically across every order rather than
//      against a fixed catalog value.
//   3. Revenue Impact from Price Changes — estimated net revenue effect of
//      those price changes on the orders sold at the new prices.
//   4. Best-Selling Products/Services — top items ranked by revenue.
//   5. Payment Breakdown — orders/revenue grouped by payment method.
//   6. Order Status Breakdown — orders/revenue grouped by order status.
//   7. Remarks & Analysis — a short narrative summary tying the above
//      together.
//
// Both PDFs are triggered from the admin Sales Record screen's "Print
// Document" button (admin_logs_screen.dart), depending on which sub-tab
// ("Sales Record" vs "Sales Report") is active.

class _SalesReportRow {
  final String salesRecordId;
  final String orderId;
  final String customer;
  final String orderDate;
  final Timestamp? orderDateRaw;
  final String product;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final String paymentStatus;
  final String orderStatus;
  final double orderTotal;
  const _SalesReportRow({
    required this.salesRecordId,
    required this.orderId,
    required this.customer,
    required this.orderDate,
    required this.orderDateRaw,
    required this.product,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    required this.paymentStatus,
    required this.orderStatus,
    required this.orderTotal,
  });
}

class _PriceChangeRow {
  final String orderId;
  final String orderDate;
  final Timestamp? orderDateRaw;
  final String product;
  // Add-on service name, if this price change applies to an add-on nested
  // under a product/service rather than the product/service itself.
  // Empty string when not applicable.
  final String addonName;
  final double previousPrice;
  final double changedPrice;
  final double difference;
  final String customer;
  // Every order (by order_id) sold at `changedPrice`, starting from the
  // order where the new price first appeared through to the order right
  // before the next detected change (or the most recent order, if none).
  final List<String> affectedOrderIds;
  const _PriceChangeRow({
    required this.orderId,
    required this.orderDate,
    required this.orderDateRaw,
    required this.product,
    required this.addonName,
    required this.previousPrice,
    required this.changedPrice,
    required this.difference,
    required this.customer,
    required this.affectedOrderIds,
  });

  bool get hasAddon => addonName.isNotEmpty;
  // Display label combining product/service with its add-on, when present.
  String get itemLabel => hasAddon ? '$product — $addonName' : product;
}

String _fmtSalesReportDate(Timestamp? ts) {
  if (ts == null) return '—';
  final d = ts.toDate().toLocal();
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

String _salesOrderStatusLabel(String st) {
  switch (st) {
    case 'in_production': return 'Active';
    case 'pending':        return 'Pending';
    case 'ready':          return 'Ready';
    case 'cancelled':      return 'Cancelled';
    case 'completed':      return 'Completed';
    default: return st.isEmpty ? '—' : st[0].toUpperCase() + st.substring(1);
  }
}

// Joins grouped Sales_Records with their Orders data and fans out one row
// per product line item (an order with 3 products yields 3 rows, all
// sharing the same Sales Record ID / Order ID / customer / status info).
List<_SalesReportRow> _buildSalesReportRows(
    List<_GroupedRecord> groups,
    Map<String, Map<String, dynamic>> ordersById,
    ) {
  final rows = <_SalesReportRow>[];

  for (final g in groups) {
    // Earliest Sales_Records doc for this order is treated as the
    // canonical "Sales Record ID" (groups is built from date-sorted docs).
    final salesRecordId = g.docRefs.isNotEmpty ? g.docRefs.first.id : g.orderId;
    final order = ordersById[g.orderId];

    final isFullyPaid = g.paymentType == 'full' ||
        (g.orderTotal > 0 && g.totalPaid >= g.orderTotal - 0.01);
    final paymentStatus = isFullyPaid ? 'Fully Paid' : 'Partial / Balance Due';

    final orderStatusRaw = order?['status']?.toString() ?? '';
    final orderStatus = orderStatusRaw.isEmpty ? '—' : _salesOrderStatusLabel(orderStatusRaw);

    final orderDateTs = (order?['created_at'] as Timestamp?) ?? g.latestDate;
    final orderTotal = (order?['total_price'] as num?)?.toDouble() ?? g.orderTotal;
    final custDisplay = (g.custName.isNotEmpty && g.custName != '—')
        ? g.custName
        : (g.custId.isNotEmpty ? g.custId : '—');

    final products = (order?['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (products.isEmpty) {
      // No matching Order product data (e.g. order doc missing) — still
      // surface the sales/payment info as a single row.
      rows.add(_SalesReportRow(
        salesRecordId: salesRecordId,
        orderId: g.orderId,
        customer: custDisplay,
        orderDate: _fmtSalesReportDate(orderDateTs),
        orderDateRaw: orderDateTs,
        product: '—',
        qty: 0,
        unitPrice: 0,
        lineTotal: 0,
        paymentStatus: paymentStatus,
        orderStatus: orderStatus,
        orderTotal: orderTotal,
      ));
      continue;
    }

    for (final p in products) {
      final qty = (p['qty'] as num?)?.toInt() ?? 1;
      final unit = (p['unit_price'] as num?)?.toDouble() ?? 0;
      final line = (p['price'] as num?)?.toDouble() ?? (unit * qty);
      rows.add(_SalesReportRow(
        salesRecordId: salesRecordId,
        orderId: g.orderId,
        customer: custDisplay,
        orderDate: _fmtSalesReportDate(orderDateTs),
        orderDateRaw: orderDateTs,
        product: (p['name']?.toString() ?? 'Item'),
        qty: qty,
        unitPrice: unit,
        lineTotal: line,
        paymentStatus: paymentStatus,
        orderStatus: orderStatus,
        orderTotal: orderTotal,
      ));
    }
  }

  // Most recent order first, matching the on-screen Sales Record list.
  rows.sort((a, b) {
    if (a.orderDateRaw == null && b.orderDateRaw == null) return 0;
    if (a.orderDateRaw == null) return 1;
    if (b.orderDateRaw == null) return -1;
    return b.orderDateRaw!.compareTo(a.orderDateRaw!);
  });

  return rows;
}

// Builds a chronological price-usage timeline per product/service — and,
// where present, per add-on nested under a product line item — across every
// order, then flags any change whose new price was first introduced in an
// order dated on/after `_priceChangeCutoff`. Add-ons are read defensively
// from an optional `addons` list on each product entry (each with `name`
// and `unit_price`/`price`); orders without that field are unaffected.
List<_PriceChangeRow> _buildPriceChangeRows(Map<String, Map<String, dynamic>> ordersById) {
  // key = 'product|||addon' ('' addon = the product/service itself).
  final byKey = <String, List<Map<String, dynamic>>>{};
  final keyMeta = <String, List<String>>{}; // key -> [product, addon]

  void addOccurrence(String product, String addon, Timestamp ts, double unit,
      String orderId, String cust) {
    final key = '$product|||$addon';
    keyMeta[key] = [product, addon];
    byKey.putIfAbsent(key, () => []).add({
      'ts': ts,
      'unit': unit,
      'orderId': orderId,
      'cust': cust,
    });
  }

  for (final order in ordersById.values) {
    final ts = order['created_at'] as Timestamp?;
    if (ts == null) continue;
    final products = (order['products'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final orderId = order['order_id']?.toString() ?? '';
    final custName = order['customer_name']?.toString() ?? '';
    for (final p in products) {
      final name = (p['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;
      final unit = (p['unit_price'] as num?)?.toDouble() ?? 0;
      addOccurrence(name, '', ts, unit, orderId, custName);

      final addons = (p['addons'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final a in addons) {
        final aName = (a['name']?.toString() ?? '').trim();
        if (aName.isEmpty) continue;
        final aUnit = (a['unit_price'] as num?)?.toDouble() ??
            (a['price'] as num?)?.toDouble() ?? 0;
        addOccurrence(name, aName, ts, aUnit, orderId, custName);
      }
    }
  }

  final changes = <_PriceChangeRow>[];
  for (final entry in byKey.entries) {
    final meta = keyMeta[entry.key]!;
    final occurrences = entry.value
      ..sort((a, b) => (a['ts'] as Timestamp).compareTo(b['ts'] as Timestamp));
    for (int i = 1; i < occurrences.length; i++) {
      final prev = occurrences[i - 1];
      final curr = occurrences[i];
      final prevPrice = prev['unit'] as double;
      final currPrice = curr['unit'] as double;
      final currTs = curr['ts'] as Timestamp;
      if ((currPrice - prevPrice).abs() < 0.01) continue; // not a real change
      if (currTs.toDate().isBefore(_priceChangeCutoff)) continue;

      // Orders affected: every occurrence from the change point onward that
      // was sold at the same new price, up to the next detected change.
      final affected = <String>{};
      for (int j = i; j < occurrences.length; j++) {
        final pj = occurrences[j]['unit'] as double;
        if ((pj - currPrice).abs() >= 0.01) break;
        final oid = occurrences[j]['orderId'] as String;
        if (oid.isNotEmpty) affected.add(oid);
      }

      changes.add(_PriceChangeRow(
        orderId: curr['orderId'] as String,
        orderDate: _fmtSalesReportDate(currTs),
        orderDateRaw: currTs,
        product: meta[0],
        addonName: meta[1],
        previousPrice: prevPrice,
        changedPrice: currPrice,
        difference: currPrice - prevPrice,
        customer: (curr['cust'] as String).isNotEmpty ? curr['cust'] as String : '—',
        affectedOrderIds: affected.toList(),
      ));
    }
  }

  changes.sort((a, b) {
    if (a.orderDateRaw == null && b.orderDateRaw == null) return 0;
    if (a.orderDateRaw == null) return 1;
    if (b.orderDateRaw == null) return -1;
    return b.orderDateRaw!.compareTo(a.orderDateRaw!);
  });

  return changes;
}

// =============================================================================
// Sales Report analysis aggregates — best sellers, payment breakdown, and
// order status breakdown. All computed from the same `rows`/`groups` data
// already assembled for the Sales Records table, so they always stay
// consistent with what's printed above them in the report.
// =============================================================================

class _BestSellerEntry {
  final String product;
  final int qty;
  final double revenue;
  const _BestSellerEntry(this.product, this.qty, this.revenue);
}

class _PaymentBreakdownEntry {
  final String label;
  final int orderCount;
  final double revenue;
  const _PaymentBreakdownEntry(this.label, this.orderCount, this.revenue);
}

class _StatusBreakdownEntry {
  final String label;
  final int orderCount;
  final double revenue;
  const _StatusBreakdownEntry(this.label, this.orderCount, this.revenue);
}

String _srMethodLabel(String? m) {
  switch (m) {
    case 'gcash': return 'GCash';
    case 'card': return 'Card';
    case 'maya': return 'Maya';
    case 'cash': return 'Cash';
    case 'online': return 'Online';
    default: return (m != null && m.isNotEmpty) ? m : 'Unspecified';
  }
}

// Ranks products/services (and add-ons folded into a line's total) by
// revenue across every fanned-out sales row.
List<_BestSellerEntry> _buildBestSellers(List<_SalesReportRow> rows, {int top = 10}) {
  final qty = <String, int>{};
  final revenue = <String, double>{};
  for (final r in rows) {
    if (r.product == '—' || r.qty <= 0) continue;
    qty[r.product] = (qty[r.product] ?? 0) + r.qty;
    revenue[r.product] = (revenue[r.product] ?? 0) + r.lineTotal;
  }
  final entries = qty.entries
      .map((e) => _BestSellerEntry(e.key, e.value, revenue[e.key] ?? 0))
      .toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  return entries.take(top).toList();
}

// Breaks down orders (not fanned-out line items) by the payment method
// recorded on their most recent Sales_Records entry.
List<_PaymentBreakdownEntry> _buildPaymentBreakdown(List<_GroupedRecord> groups) {
  final counts = <String, int>{};
  final revenue = <String, double>{};
  for (final g in groups) {
    final label = _srMethodLabel(g.paymentMethod);
    counts[label] = (counts[label] ?? 0) + 1;
    revenue[label] = (revenue[label] ?? 0) + g.totalPaid;
  }
  final entries = counts.entries
      .map((e) => _PaymentBreakdownEntry(e.key, e.value, revenue[e.key] ?? 0))
      .toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  return entries;
}

// Breaks down orders (deduplicated — one entry per order_id, not per line
// item) by their order status, alongside the revenue collected on each.
List<_StatusBreakdownEntry> _buildOrderStatusBreakdown(
    List<_SalesReportRow> rows, List<_GroupedRecord> groups) {
  final revenueByOrder = {for (final g in groups) g.orderId: g.totalPaid};
  final statusByOrder = <String, String>{};
  for (final r in rows) {
    statusByOrder.putIfAbsent(r.orderId, () => r.orderStatus);
  }
  final counts = <String, int>{};
  final revenue = <String, double>{};
  for (final entry in statusByOrder.entries) {
    final st = entry.value;
    counts[st] = (counts[st] ?? 0) + 1;
    revenue[st] = (revenue[st] ?? 0) + (revenueByOrder[entry.key] ?? 0);
  }
  final entries = counts.entries
      .map((e) => _StatusBreakdownEntry(e.key, e.value, revenue[e.key] ?? 0))
      .toList()
    ..sort((a, b) => b.orderCount.compareTo(a.orderCount));
  return entries;
}

// Generic bounded-height report table — every cell is capped to a fixed
// number of lines so no row can ever exceed a page (see the Job Queue report
// for the original bug this pattern was built to prevent).
pw.Widget _srTable({
  required List<String> headers,
  required List<List<String>> data,
  required Map<int, pw.TableColumnWidth> columnWidths,
  required pw.Font regular,
  required pw.Font bold,
  required PdfColor navy,
  required PdfColor gold,
  required PdfColor textDark,
  required PdfColor rowAlt,
  required PdfColor rowBorder,
  Set<int> rightAlign = const {},
  Set<int> wrapTwoLines = const {},
  PdfColor? Function(int rowIndex, int colIndex, String value)? cellColor,
}) {
  return pw.Table(
    border: null,
    columnWidths: columnWidths,
    children: [
      pw.TableRow(
        decoration: pw.BoxDecoration(color: navy),
        children: headers.asMap().entries.map((h) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: pw.Align(
              alignment: rightAlign.contains(h.key) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              child: pw.Text(h.value,
                  style: pw.TextStyle(font: bold, fontSize: 7.5, color: gold),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip),
            ),
          );
        }).toList(),
      ),
      ...data.asMap().entries.map((r) {
        final isAlt = r.key.isOdd;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isAlt ? rowAlt : null,
            border: pw.Border(bottom: pw.BorderSide(color: rowBorder, width: 0.5)),
          ),
          children: r.value.asMap().entries.map((c) {
            final color = cellColor?.call(r.key, c.key, c.value) ?? textDark;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: pw.Align(
                alignment: rightAlign.contains(c.key) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                child: pw.Text(c.value,
                    style: pw.TextStyle(font: regular, fontSize: 7.5, color: color),
                    maxLines: wrapTwoLines.contains(c.key) ? 2 : 1,
                    overflow: pw.TextOverflow.clip),
              ),
            );
          }).toList(),
        );
      }),
    ],
  );
}

Future<Uint8List> _buildSalesReportPdf({
  required List<_SalesReportRow> rows,
  required List<_PriceChangeRow> priceChanges,
  required List<_GroupedRecord> groups,
}) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final italic  = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document();
  final now = DateTime.now();

  const navy      = PdfColor.fromInt(0xFF0F1A2E);
  const gold      = PdfColor.fromInt(0xFFE8B84B);
  const white     = PdfColors.white;
  const textDark  = PdfColor.fromInt(0xFF0F172A);
  const textMid   = PdfColor.fromInt(0xFF475569);
  const textLight = PdfColor.fromInt(0xFF94A3B8);
  const rowAlt    = PdfColor.fromInt(0xFFF8FAFC);
  const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
  const accentBg  = PdfColor.fromInt(0xFFF0F9FF);
  const green     = PdfColor.fromInt(0xFF16A34A);
  const red       = PdfColor.fromInt(0xFFDC2626);

  pw.TextStyle s(pw.Font f, double sz, PdfColor c) => pw.TextStyle(font: f, fontSize: sz, color: c);
  String php(double v) => '₱ ${AppTheme.fmtAmt(v)}';
  String shorten(String text, [int maxLen = 22]) =>
      text.length > maxLen ? '${text.substring(0, maxLen)}…' : text;

  String fmtDateGenerated(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${mo[d.month - 1]} ${d.day}, ${d.year} · '
        '$h12:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  pw.Widget pdfMeta(String label, String value, PdfColor valueColor) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label  ', style: pw.TextStyle(font: regular, fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B))),
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor)),
    ],
  );

  pw.Widget summaryChip(String label, String value, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    margin: const pw.EdgeInsets.only(right: 6, bottom: 4),
    decoration: pw.BoxDecoration(
      color: white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
      border: pw.Border.all(color: color, width: 0.7),
    ),
    child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(
          color: color, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text(value, style: s(bold, 8, textDark)),
      pw.SizedBox(width: 2),
      pw.Text(label, style: s(regular, 7, textMid)),
    ]),
  );

  final totalOrders = groups.length;
  final totalRevenue = groups.fold<double>(0, (sum, g) => sum + g.totalPaid);
  final fullyPaidCount = groups.where((g) =>
  g.paymentType == 'full' || (g.orderTotal > 0 && g.totalPaid >= g.orderTotal - 0.01)).length;
  final partialCount = totalOrders - fullyPaidCount;

  // ── Sales period covered — earliest/latest order date among the rows ────
  DateTime? periodStart, periodEnd;
  for (final r in rows) {
    final d = r.orderDateRaw?.toDate();
    if (d == null) continue;
    if (periodStart == null || d.isBefore(periodStart)) periodStart = d;
    if (periodEnd == null || d.isAfter(periodEnd)) periodEnd = d;
  }
  final periodLabel = (periodStart != null && periodEnd != null)
      ? '${_fmtSalesReportDate(Timestamp.fromDate(periodStart))} – '
      '${_fmtSalesReportDate(Timestamp.fromDate(periodEnd))}'
      : 'No records';

  // ── Price Changes table ─────────────────────────────────────────────────
  final pcHeaders = ['PRODUCT / SERVICE', 'ADD-ON SERVICE', 'PREVIOUS PRICE',
    'UPDATED PRICE', 'CHANGE STARTED', 'DIFFERENCE', 'RELATED ORDERS'];

  final pcRows = priceChanges.map((c) => [
    shorten(c.product, 24),
    c.addonName.isEmpty ? '—' : shorten(c.addonName, 20),
    php(c.previousPrice),
    php(c.changedPrice),
    c.orderDate,
    '${c.difference >= 0 ? '+' : '-'}${php(c.difference.abs())}',
    c.affectedOrderIds.isEmpty
        ? '—'
        : '${c.affectedOrderIds.length} order${c.affectedOrderIds.length == 1 ? '' : 's'}',
  ]).toList();

  // ── Price-change impact analysis (narrative) ─────────────────────────────
  final increaseCount = priceChanges.where((c) => c.difference > 0).length;
  final decreaseCount = priceChanges.where((c) => c.difference < 0).length;
  final affectedOrdersTotal =
      priceChanges.expand((c) => c.affectedOrderIds).toSet().length;
  final estRevenueImpact = priceChanges.fold<double>(
      0, (sum, c) => sum + c.difference * c.affectedOrderIds.length);

  final String analysisText;
  if (priceChanges.isEmpty) {
    analysisText =
    'No product, service, or add-on price changes were detected in orders '
        'dated June 2026 or later. Sales performance in this report reflects '
        'pricing that was already in effect before that period.';
  } else {
    final direction = estRevenueImpact >= 0 ? 'increased' : 'decreased';
    analysisText =
    'Since June 2026, ${priceChanges.length} product/service and add-on '
        'price change${priceChanges.length == 1 ? '' : 's'} took effect — '
        '$increaseCount price increase${increaseCount == 1 ? '' : 's'} and '
        '$decreaseCount price decrease${decreaseCount == 1 ? '' : 's'}. '
        'These changes are reflected in $affectedOrdersTotal order'
        '${affectedOrdersTotal == 1 ? '' : 's'} sold at the new price, for '
        'an estimated net revenue $direction of ${php(estRevenueImpact.abs())} '
        'on those orders compared with pre-change pricing. See the table '
        'above for the specific products, services, and add-ons driving '
        'this shift, and the separate Sales Records PDF for the full '
        'order-level detail.';
  }

  // ── Best-selling products/services, payment breakdown, order status
  // breakdown — all derived from the same rows/groups as the tables above.
  final bestSellers = _buildBestSellers(rows);
  final paymentBreakdown = _buildPaymentBreakdown(groups);
  final orderStatusBreakdown = _buildOrderStatusBreakdown(rows, groups);

  // ── Remarks & Analysis (narrative synthesis of the whole report) ────────
  final fullyPaidPct = totalOrders > 0 ? (fullyPaidCount / totalOrders * 100) : 0;
  final topPaymentMethod = paymentBreakdown.isNotEmpty ? paymentBreakdown.first : null;
  final topSeller = bestSellers.isNotEmpty ? bestSellers.first : null;
  final cancelledEntry = orderStatusBreakdown.firstWhere(
        (e) => e.label == 'Cancelled',
    orElse: () => const _StatusBreakdownEntry('Cancelled', 0, 0),
  );
  final cancelledPct = totalOrders > 0 ? (cancelledEntry.orderCount / totalOrders * 100) : 0;

  final remarksText = StringBuffer()
    ..write('This report covers $totalOrders order${totalOrders == 1 ? '' : 's'} '
        'totaling ${php(totalRevenue)} in collected revenue over $periodLabel. ')
    ..write('$fullyPaidCount order${fullyPaidCount == 1 ? '' : 's'} '
        '(${fullyPaidPct.toStringAsFixed(1)}%) ${fullyPaidCount == 1 ? 'is' : 'are'} fully paid, '
        'while $partialCount remain${partialCount == 1 ? 's' : ''} partially paid or with a balance due. ');
  if (topPaymentMethod != null) {
    remarksText.write('${topPaymentMethod.label} is the most-used payment method, '
        'covering ${topPaymentMethod.orderCount} order${topPaymentMethod.orderCount == 1 ? '' : 's'} '
        'and ${php(topPaymentMethod.revenue)} in revenue. ');
  }
  if (topSeller != null) {
    remarksText.write('${topSeller.product} is the top-selling product/service by revenue, '
        'with ${topSeller.qty} unit${topSeller.qty == 1 ? '' : 's'} sold '
        'for ${php(topSeller.revenue)}. ');
  }
  if (cancelledEntry.orderCount > 0) {
    remarksText.write('${cancelledEntry.orderCount} order${cancelledEntry.orderCount == 1 ? '' : 's'} '
        '(${cancelledPct.toStringAsFixed(1)}%) ${cancelledEntry.orderCount == 1 ? 'was' : 'were'} cancelled. ');
  }
  if (priceChanges.isEmpty) {
    remarksText.write('No pricing changes were recorded from June 2026 onward, '
        'so current pricing has remained stable throughout this period.');
  } else {
    final direction = estRevenueImpact >= 0 ? 'a net revenue increase' : 'a net revenue decrease';
    remarksText.write('Pricing changes effective June 2026 onward ($increaseCount increase'
        '${increaseCount == 1 ? '' : 's'}, $decreaseCount decrease${decreaseCount == 1 ? '' : 's'}) '
        'have resulted in $direction of ${php(estRevenueImpact.abs())} on the '
        '$affectedOrdersTotal order${affectedOrdersTotal == 1 ? '' : 's'} sold at the new prices.');
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      // Generous cap — "all sales records" with no date limit can legitimately
      // span hundreds of pages once fanned out per product line.
      maxPages: 5000,
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
        width: double.infinity,
        color: navy,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: pw.Text('$_srBizName  ·  Sales Report', style: s(bold, 9, gold)),
      ),
      footer: (ctx) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        decoration: const pw.BoxDecoration(color: rowAlt),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$_srBizName  ·  TIN: $_srBizTin', style: s(bold, 7.5, textMid)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: s(regular, 7.5, textLight)),
          ],
        ),
      ),
      build: (ctx) => [
        // ── Header band ───────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: navy,
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 22),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_srBizName, style: pw.TextStyle(
                        font: bold, fontSize: 22, color: gold, letterSpacing: 1.5)),
                    pw.SizedBox(height: 3),
                    pw.Text(_srBizTagline, style: s(regular, 9, textLight)),
                    pw.SizedBox(height: 9),
                    pw.Container(height: 1, width: 160,
                        color: const PdfColor.fromInt(0xFF334155)),
                    pw.SizedBox(height: 9),
                    pw.Text(_srBizAddr1, style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.Text(_srBizAddr2, style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.SizedBox(height: 5),
                    pw.Text('TIN: $_srBizTin', style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SALES REPORT', style: pw.TextStyle(
                      font: bold, fontSize: 17, color: gold, letterSpacing: 1.1)),
                  pw.SizedBox(height: 10),
                  pdfMeta('Date Generated', fmtDateGenerated(now), white),
                  pw.SizedBox(height: 4),
                  pdfMeta('Generated By', 'Admin', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Report Scope', 'All Sales Records', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Sales Period Covered', periodLabel, const PdfColor.fromInt(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),

        // ── Summary strip ────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: accentBg,
          padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SUMMARY', style: s(bold, 7.5, textLight)),
              pw.SizedBox(height: 6),
              pw.Wrap(spacing: 0, runSpacing: 0, children: [
                summaryChip('Total Orders', '$totalOrders', navy),
                summaryChip('Fully Paid', '$fullyPaidCount', green),
                summaryChip('Partial / Balance Due', '$partialCount', const PdfColor.fromInt(0xFFD97706)),
                summaryChip('Price Changes (Jun 2026+)', '${priceChanges.length}', red),
              ]),
              pw.SizedBox(height: 8),
              pw.Text('Total Revenue Collected: ${php(totalRevenue)}', style: s(bold, 9, textDark)),
            ],
          ),
        ),

        pw.SizedBox(height: 18),

        // ── Price Change Analysis ────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PRICE CHANGE ANALYSIS — JUNE 2026 ONWARD', style: pw.TextStyle(
                  font: bold, fontSize: 13, color: navy, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Products, services, and add-on services whose per-unit price differs from the price '
                    'they were previously sold at, first appearing in an order dated June 2026 or later, '
                    'together with the orders sold at each new price.',
                style: s(regular, 8, textMid),
              ),
              pw.SizedBox(height: 14),
            ],
          ),
        ),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: priceChanges.isEmpty
              ? pw.Text('No price changes detected from June 2026 onward.',
              style: s(italic, 9, textMid))
              : _srTable(
            headers: pcHeaders,
            data: pcRows,
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            rightAlign: const {2, 3, 5},
            wrapTwoLines: const {0, 1},
            cellColor: (rowIndex, colIndex, value) {
              if (colIndex != 5) return null;
              return value.startsWith('+') ? red : green;
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(1.9),
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(1.2),
              5: pw.FlexColumnWidth(1.0),
              6: pw.FlexColumnWidth(1.1),
            },
          ),
        ),

        // ── Revenue Impact from Price Changes — its own section, forced
        // onto a fresh page so the heading and stat chips stay together.
        pw.NewPage(),

        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 30),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('REVENUE IMPACT FROM PRICE CHANGES', style: pw.TextStyle(
                  font: bold, fontSize: 13, color: navy, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Estimated effect of the price changes above on revenue, based on the orders sold at each new price.',
                style: s(regular, 8, textMid),
              ),
              pw.SizedBox(height: 14),
              pw.Wrap(spacing: 8, runSpacing: 8, children: [
                summaryChip('Price Increases', '$increaseCount', red),
                summaryChip('Price Decreases', '$decreaseCount', green),
                summaryChip('Orders Affected', '$affectedOrdersTotal', navy),
                summaryChip(
                  'Net Revenue Impact',
                  '${estRevenueImpact >= 0 ? '+' : '-'}${php(estRevenueImpact.abs())}',
                  estRevenueImpact >= 0 ? green : red,
                ),
              ]),
              pw.SizedBox(height: 14),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: accentBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: rowBorder, width: 0.7),
                ),
                child: pw.Text(analysisText, style: s(regular, 8.5, textMid)),
              ),
            ],
          ),
        ),

        // ── Best-Selling Products/Services ────────────────────────────────
        pw.NewPage(),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 26),
              pw.Text('BEST-SELLING PRODUCTS / SERVICES', style: pw.TextStyle(
                  font: bold, fontSize: 13, color: navy, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Top products and services in this report, ranked by revenue.',
                style: s(regular, 8, textMid),
              ),
              pw.SizedBox(height: 14),
            ],
          ),
        ),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: bestSellers.isEmpty
              ? pw.Text('No product/service sales data available.',
              style: s(italic, 9, textMid))
              : _srTable(
            headers: const ['#', 'PRODUCT / SERVICE', 'QTY SOLD', 'REVENUE', '% OF TOTAL REVENUE'],
            data: bestSellers.asMap().entries.map((e) {
              final i = e.key;
              final b = e.value;
              final pct = totalRevenue > 0 ? (b.revenue / totalRevenue * 100) : 0.0;
              return [
                '${i + 1}',
                shorten(b.product, 40),
                '${b.qty}',
                php(b.revenue),
                '${pct.toStringAsFixed(1)}%',
              ];
            }).toList(),
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            rightAlign: const {2, 3, 4},
            wrapTwoLines: const {1},
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FlexColumnWidth(2.6),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.2),
              4: pw.FlexColumnWidth(1.4),
            },
          ),
        ),

        // ── Payment Breakdown ──────────────────────────────────────────────
        pw.NewPage(),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 26),
              pw.Text('PAYMENT BREAKDOWN', style: pw.TextStyle(
                  font: bold, fontSize: 13, color: navy, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Orders and revenue in this report grouped by payment method.',
                style: s(regular, 8, textMid),
              ),
              pw.SizedBox(height: 14),
            ],
          ),
        ),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: paymentBreakdown.isEmpty
              ? pw.Text('No payment data available.', style: s(italic, 9, textMid))
              : _srTable(
            headers: const ['PAYMENT METHOD', 'ORDERS', 'REVENUE', '% OF TOTAL REVENUE'],
            data: paymentBreakdown.map((p) {
              final pct = totalRevenue > 0 ? (p.revenue / totalRevenue * 100) : 0.0;
              return [
                p.label,
                '${p.orderCount}',
                php(p.revenue),
                '${pct.toStringAsFixed(1)}%',
              ];
            }).toList(),
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            rightAlign: const {1, 2, 3},
            columnWidths: const {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(1.3),
              3: pw.FlexColumnWidth(1.4),
            },
          ),
        ),

        // ── Order Status Breakdown ─────────────────────────────────────────
        pw.NewPage(),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 26),
              pw.Text('ORDER STATUS BREAKDOWN', style: pw.TextStyle(
                  font: bold, fontSize: 13, color: navy, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Orders in this report grouped by current order status.',
                style: s(regular, 8, textMid),
              ),
              pw.SizedBox(height: 14),
            ],
          ),
        ),

        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: orderStatusBreakdown.isEmpty
              ? pw.Text('No order status data available.', style: s(italic, 9, textMid))
              : _srTable(
            headers: const ['ORDER STATUS', 'ORDERS', '% OF ORDERS', 'REVENUE'],
            data: orderStatusBreakdown.map((o) {
              final pct = totalOrders > 0 ? (o.orderCount / totalOrders * 100) : 0.0;
              return [
                o.label,
                '${o.orderCount}',
                '${pct.toStringAsFixed(1)}%',
                php(o.revenue),
              ];
            }).toList(),
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            rightAlign: const {1, 2, 3},
            cellColor: (rowIndex, colIndex, value) {
              if (colIndex != 0) return null;
              if (value == 'Cancelled') return red;
              if (value == 'Completed') return green;
              return null;
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(1.6),
              1: pw.FlexColumnWidth(1.0),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(1.3),
            },
          ),
        ),

        // ── Remarks & Analysis — final section, synthesizes the report ─────
        pw.NewPage(),

        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 30),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('REMARKS & ANALYSIS', style: pw.TextStyle(
                  font: bold, fontSize: 13, color: navy, letterSpacing: 0.5)),
              pw.SizedBox(height: 4),
              pw.Text(
                'A brief narrative summary of overall sales performance covered by this report.',
                style: s(regular, 8, textMid),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: accentBg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: rowBorder, width: 0.7),
                ),
                child: pw.Text(remarksText.toString(), style: s(regular, 8.5, textMid)),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

Future<void> generateAdminSalesReportPdf(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing sales report…'), duration: Duration(seconds: 2)),
  );

  try {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('Sales_Records').get(),
      db.collection('Orders').get(),
      db.collection('Order_Queue').get(),
    ]);
    final srSnap = results[0];
    final ordSnap = results[1];
    final oqSnap = results[2];

    // Merge Orders + Order_Queue, de-duplicated by order_id (Orders preferred)
    // so price history covers both current and archived orders.
    final seenOrderIds = <String>{};
    final orderDocs = [...ordSnap.docs, ...oqSnap.docs].where((d) {
      final oid = (d.data() as Map<String, dynamic>)['order_id']?.toString() ?? d.id;
      return seenOrderIds.add(oid);
    }).toList();
    final ordersById = <String, Map<String, dynamic>>{
      for (final d in orderDocs)
        ((d.data() as Map<String, dynamic>)['order_id']?.toString() ?? d.id):
        d.data() as Map<String, dynamic>,
    };

    // Sort ascending by sale_date so, per order_id, the first doc encountered
    // by _groupRecordsAsync is the earliest — used as the canonical
    // "Sales Record ID" for that order.
    final sortedDocs = [...srSnap.docs]..sort((a, b) {
      final ta = (a.data() as Map<String, dynamic>)['sale_date'] as Timestamp?;
      final tb = (b.data() as Map<String, dynamic>)['sale_date'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1;
      if (tb == null) return 1;
      return ta.compareTo(tb);
    });

    final groups = await _groupRecordsAsync(sortedDocs);
    // Same "real records only" rule the on-screen Sales Record list uses.
    final realGroups = groups.where((g) => !g.isImported && !g.isXlsxImport).toList();

    final rows = _buildSalesReportRows(realGroups, ordersById);
    final priceChanges = _buildPriceChangeRows(ordersById);

    final bytes = await _buildSalesReportPdf(
      rows: rows,
      priceChanges: priceChanges,
      groups: realGroups,
    );

    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final filename = 'sales_report_$stamp.pdf';

    if (kIsWeb) {
      await file_utils.downloadBytes(bytes, 'application/pdf', filename);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to generate sales report: $e')),
    );
  }
}

// =============================================================================
// Admin Sales Records — "Print Document" (PDF generation)
// =============================================================================
// A lean companion to the Sales Report PDF above: just the business header,
// a compact summary strip, and the full Sales Records table — no Price
// Change Analysis, Best-Sellers, Payment/Order-Status breakdowns, or
// Remarks. Intended for a quick, printable listing of the raw records
// rather than the full analytical report.
//
// Triggered from the admin Sales Record screen's "Print Document" button
// while the "Sales Record" sub-tab is active (admin_logs_screen.dart).
Future<Uint8List> _buildSalesRecordsPdf({
  required List<_SalesReportRow> rows,
  required List<_GroupedRecord> groups,
}) async {
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold    = await PdfGoogleFonts.notoSansBold();
  final italic  = await PdfGoogleFonts.notoSansItalic();

  final doc = pw.Document();
  final now = DateTime.now();

  const navy      = PdfColor.fromInt(0xFF0F1A2E);
  const gold      = PdfColor.fromInt(0xFFE8B84B);
  const white     = PdfColors.white;
  const textDark  = PdfColor.fromInt(0xFF0F172A);
  const textMid   = PdfColor.fromInt(0xFF475569);
  const textLight = PdfColor.fromInt(0xFF94A3B8);
  const rowAlt    = PdfColor.fromInt(0xFFF8FAFC);
  const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
  const accentBg  = PdfColor.fromInt(0xFFF0F9FF);
  const green     = PdfColor.fromInt(0xFF16A34A);

  pw.TextStyle s(pw.Font f, double sz, PdfColor c) => pw.TextStyle(font: f, fontSize: sz, color: c);
  String php(double v) => '₱ ${AppTheme.fmtAmt(v)}';
  String shorten(String text, [int maxLen = 22]) =>
      text.length > maxLen ? '${text.substring(0, maxLen)}…' : text;

  String fmtDateGenerated(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${mo[d.month - 1]} ${d.day}, ${d.year} · '
        '$h12:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  pw.Widget pdfMeta(String label, String value, PdfColor valueColor) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('$label  ', style: pw.TextStyle(font: regular, fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B))),
      pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor)),
    ],
  );

  pw.Widget summaryChip(String label, String value, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    margin: const pw.EdgeInsets.only(right: 6, bottom: 4),
    decoration: pw.BoxDecoration(
      color: white,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(9)),
      border: pw.Border.all(color: color, width: 0.7),
    ),
    child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
      pw.Container(width: 9, height: 9, decoration: pw.BoxDecoration(
          color: color, shape: pw.BoxShape.circle)),
      pw.SizedBox(width: 4),
      pw.Text(value, style: s(bold, 8, textDark)),
      pw.SizedBox(width: 2),
      pw.Text(label, style: s(regular, 7, textMid)),
    ]),
  );

  final totalOrders = groups.length;
  final totalRevenue = groups.fold<double>(0, (sum, g) => sum + g.totalPaid);
  final fullyPaidCount = groups.where((g) =>
  g.paymentType == 'full' || (g.orderTotal > 0 && g.totalPaid >= g.orderTotal - 0.01)).length;
  final partialCount = totalOrders - fullyPaidCount;

  // ── Sales period covered — earliest/latest order date among the rows ────
  DateTime? periodStart, periodEnd;
  for (final r in rows) {
    final d = r.orderDateRaw?.toDate();
    if (d == null) continue;
    if (periodStart == null || d.isBefore(periodStart)) periodStart = d;
    if (periodEnd == null || d.isAfter(periodEnd)) periodEnd = d;
  }
  final periodLabel = (periodStart != null && periodEnd != null)
      ? '${_fmtSalesReportDate(Timestamp.fromDate(periodStart))} – '
      '${_fmtSalesReportDate(Timestamp.fromDate(periodEnd))}'
      : 'No records';

  final headers = ['#', 'RECORD ID', 'ORDER ID', 'CUSTOMER', 'ORDER DATE', 'PRODUCT/SERVICE',
    'QTY', 'UNIT PRICE', 'LINE TOTAL', 'PAYMENT', 'ORDER STATUS', 'ORDER TOTAL'];

  final tableRows = rows.asMap().entries.map((e) {
    final i = e.key;
    final r = e.value;
    return [
      '${i + 1}',
      shorten(r.salesRecordId, 14),
      shorten(r.orderId, 14),
      shorten(r.customer, 18),
      r.orderDate,
      shorten(r.product, 26),
      r.qty > 0 ? '${r.qty}' : '—',
      r.qty > 0 ? php(r.unitPrice) : '—',
      r.qty > 0 ? php(r.lineTotal) : '—',
      r.paymentStatus,
      r.orderStatus,
      php(r.orderTotal),
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      // Generous cap — "all sales records" with no date limit can legitimately
      // span hundreds of pages once fanned out per product line.
      maxPages: 5000,
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
        width: double.infinity,
        color: navy,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        child: pw.Text('$_srBizName  ·  Sales Records', style: s(bold, 9, gold)),
      ),
      footer: (ctx) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
        decoration: const pw.BoxDecoration(color: rowAlt),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('$_srBizName  ·  TIN: $_srBizTin', style: s(bold, 7.5, textMid)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: s(regular, 7.5, textLight)),
          ],
        ),
      ),
      build: (ctx) => [
        // ── Header band ───────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: navy,
          padding: const pw.EdgeInsets.fromLTRB(36, 26, 36, 22),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_srBizName, style: pw.TextStyle(
                        font: bold, fontSize: 22, color: gold, letterSpacing: 1.5)),
                    pw.SizedBox(height: 3),
                    pw.Text(_srBizTagline, style: s(regular, 9, textLight)),
                    pw.SizedBox(height: 9),
                    pw.Container(height: 1, width: 160,
                        color: const PdfColor.fromInt(0xFF334155)),
                    pw.SizedBox(height: 9),
                    pw.Text(_srBizAddr1, style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.Text(_srBizAddr2, style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                    pw.SizedBox(height: 5),
                    pw.Text('TIN: $_srBizTin', style: s(regular, 8.5,
                        const PdfColor.fromInt(0xFFCBD5E1))),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SALES RECORDS', style: pw.TextStyle(
                      font: bold, fontSize: 17, color: gold, letterSpacing: 1.1)),
                  pw.SizedBox(height: 10),
                  pdfMeta('Date Generated', fmtDateGenerated(now), white),
                  pw.SizedBox(height: 4),
                  pdfMeta('Generated By', 'Admin', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Report Scope', 'All Sales Records', const PdfColor.fromInt(0xFFCBD5E1)),
                  pw.SizedBox(height: 4),
                  pdfMeta('Period Covered', periodLabel, const PdfColor.fromInt(0xFFCBD5E1)),
                ],
              ),
            ],
          ),
        ),

        // ── Summary strip ────────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: accentBg,
          padding: const pw.EdgeInsets.fromLTRB(36, 10, 36, 10),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SUMMARY', style: s(bold, 7.5, textLight)),
              pw.SizedBox(height: 6),
              pw.Wrap(spacing: 0, runSpacing: 0, children: [
                summaryChip('Total Orders', '$totalOrders', navy),
                summaryChip('Fully Paid', '$fullyPaidCount', green),
                summaryChip('Partial / Balance Due', '$partialCount', const PdfColor.fromInt(0xFFD97706)),
              ]),
              pw.SizedBox(height: 8),
              pw.Text('Total Revenue Collected: ${php(totalRevenue)}', style: s(bold, 9, textDark)),
            ],
          ),
        ),

        pw.SizedBox(height: 18),

        // ── Sales Records table ─────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 36),
          child: rows.isEmpty
              ? pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 20),
            child: pw.Text('No sales records found.', style: s(italic, 9, textMid)),
          )
              : _srTable(
            headers: headers,
            data: tableRows,
            regular: regular,
            bold: bold,
            navy: navy,
            gold: gold,
            textDark: textDark,
            rowAlt: rowAlt,
            rowBorder: rowBorder,
            rightAlign: const {7, 8, 11},
            wrapTwoLines: const {5},
            columnWidths: const {
              0: pw.FixedColumnWidth(20),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.0),
              5: pw.FlexColumnWidth(1.8),
              6: pw.FixedColumnWidth(30),
              7: pw.FlexColumnWidth(0.9),
              8: pw.FlexColumnWidth(0.9),
              9: pw.FlexColumnWidth(1.0),
              10: pw.FlexColumnWidth(0.9),
              11: pw.FlexColumnWidth(1.0),
            },
          ),
        ),
      ],
    ),
  );

  return Uint8List.fromList(await doc.save());
}

Future<void> generateAdminSalesRecordsPdf(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing sales records…'), duration: Duration(seconds: 2)),
  );

  try {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db.collection('Sales_Records').get(),
      db.collection('Orders').get(),
      db.collection('Order_Queue').get(),
    ]);
    final srSnap = results[0];
    final ordSnap = results[1];
    final oqSnap = results[2];

    // Merge Orders + Order_Queue, de-duplicated by order_id (Orders preferred).
    final seenOrderIds = <String>{};
    final orderDocs = [...ordSnap.docs, ...oqSnap.docs].where((d) {
      final oid = (d.data() as Map<String, dynamic>)['order_id']?.toString() ?? d.id;
      return seenOrderIds.add(oid);
    }).toList();
    final ordersById = <String, Map<String, dynamic>>{
      for (final d in orderDocs)
        ((d.data() as Map<String, dynamic>)['order_id']?.toString() ?? d.id):
        d.data() as Map<String, dynamic>,
    };

    // Sort ascending by sale_date so, per order_id, the first doc encountered
    // by _groupRecordsAsync is the earliest — used as the canonical
    // "Sales Record ID" for that order.
    final sortedDocs = [...srSnap.docs]..sort((a, b) {
      final ta = (a.data() as Map<String, dynamic>)['sale_date'] as Timestamp?;
      final tb = (b.data() as Map<String, dynamic>)['sale_date'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1;
      if (tb == null) return 1;
      return ta.compareTo(tb);
    });

    final groups = await _groupRecordsAsync(sortedDocs);
    // Same "real records only" rule the on-screen Sales Record list uses.
    final realGroups = groups.where((g) => !g.isImported && !g.isXlsxImport).toList();

    final rows = _buildSalesReportRows(realGroups, ordersById);

    final bytes = await _buildSalesRecordsPdf(
      rows: rows,
      groups: realGroups,
    );

    final now = DateTime.now();
    final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final filename = 'sales_records_$stamp.pdf';

    if (kIsWeb) {
      await file_utils.downloadBytes(bytes, 'application/pdf', filename);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to generate sales records: $e')),
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
  DateTimeRange? _selectedRange;
  String _search = '';

  List<_GroupedRecord> _allGroups = [];
  double _totalOutstanding = 0;
  bool _groupsLoading = false;
  // True when no date filter is active and we're showing a limited window
  bool _isLimited = false;
  final _searchCtrl = TextEditingController();

  StreamSubscription? _liveSubscription;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedRange = _pLast31();
    _loadRecords();
    _startLiveSubscription();
  }

  void _startLiveSubscription() {
    _liveSubscription = FirebaseFirestore.instance
        .collection('Sales_Records')
        .orderBy('sale_date', descending: true)
        .limit(1)
        .snapshots()
        .skip(1) // skip the immediate initial emission; _loadRecords() handles first load
        .listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 800), _loadRecords);
    });
  }

  Future<void> _loadRecords() async {
    if (!mounted) return;
    setState(() => _groupsLoading = true);
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: true);

      if (_selectedRange != null) {
        // Server-side date filter: query only the selected window
        q = q
            .where('sale_date',
            isGreaterThanOrEqualTo:
            Timestamp.fromDate(_selectedRange!.start))
            .where('sale_date',
            isLessThanOrEqualTo: Timestamp.fromDate(
                _selectedRange!.end.add(const Duration(days: 1))));
        _isLimited = false;
      } else {
        // No filter: limit to 500 most recent records for fast load
        q = q.limit(500);
        _isLimited = true;
      }

      final snap = await q.get();
      final groups = await _groupRecordsAsync(snap.docs);

      // Outstanding: non-cancelled orders filtered by paid_at within the selected range.
      // When no date filter, all active orders are included (same as Sales Report).
      double outstanding = 0;
      try {
        final ordSnap = await FirebaseFirestore.instance
            .collection('Orders')
            .where('status', whereIn: [
          'pending', 'in_production', 'ready', 'completed',
        ])
            .get();
        for (final doc in ordSnap.docs) {
          final d = doc.data();
          if (_selectedRange != null) {
            final filterTs = _orderFilterTimestamp(d);
            if (filterTs == null) continue;
            if (!_isWithinDateRange(filterTs.toDate().toLocal(), _selectedRange)) continue;
          }
          final rem  = (d['remaining_balance'] as num?)?.toDouble() ?? 0;
          final diff = ((d['total_price']  as num?)?.toDouble() ?? 0) -
              ((d['amount_paid']  as num?)?.toDouble() ?? 0);
          final owed = rem > 0.01 ? rem : (diff > 0.01 ? diff : 0.0);
          if (owed > 0.01) outstanding += owed;
        }
      } catch (_) {}

      if (mounted)
        setState(() {
          _allGroups = groups;
          _totalOutstanding = outstanding;
          _groupsLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _groupsLoading = false);
    }
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    _debounce?.cancel();
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
        return 'Upfront Payment';
      case 'refund':
        return 'Refund';
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
      case 'refund':
        return const Color(0xFFDC2626);
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
      case 'refund':
        return const Color(0xFFFEF2F2);
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
      case 'refund':
        return const Color(0xFFFECACA);
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
    if (_groupsLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: _T.textPrimary.withValues(alpha: 0.4),
        ),
      );
    }

    // All records already scoped to server-side query (date range or limit 500)
    final allGroups = _allGroups;
    final allDateFiltered = allGroups.toList();

    // Exclude historical_seed AND xlsx imports — Sales Records shows only real app records.
    final nonSeed = allDateFiltered
        .where((g) => !g.isImported && !g.isXlsxImport)
        .toList();

    var filtered = nonSeed.toList();

    if (_typeFilter != 'all') {
      filtered = filtered.where((g) => g.paymentType == _typeFilter).toList();
    }

    if (_search.isNotEmpty) {
      filtered = filtered.where((g) {
        final custIdLower = g.custId.toLowerCase();
        final custIdSuffix = custIdLower.contains('-')
            ? custIdLower.split('-').last
            : custIdLower;
        return g.orderId.toLowerCase().contains(_search) ||
            g.custName.toLowerCase().contains(_search) ||
            custIdLower.contains(_search) ||
            custIdSuffix.contains(_search);
      }).toList();
    }

    // Records count and revenue: real app records only (type filter applied, search not applied)
    var countFiltered = nonSeed;
    if (_typeFilter != 'all') {
      countFiltered = countFiltered.where((g) => g.paymentType == _typeFilter).toList();
    }

    final totalRevenue = nonSeed.fold<double>(0, (s, g) => s + g.totalPaid);


    final headerContent = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_isLimited) ...[
                  _SummaryChip(
                    label: '500 most recent',
                    value: 'Pick a date range for full history',
                    fg: const Color(0xFF64748B),
                    bg: const Color(0xFFF1F5F9),
                    border: const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 8),
                ],
                _SummaryChip(
                  label: _selectedRange == null ? 'Total' : 'Date Total',
                  value: '₱${AppTheme.fmtAmt(totalRevenue)}',
                  fg: _T.gold,
                  bg: const Color(0xFFFFFBEB),
                  border: const Color(0xFFFDE68A),
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'Records',
                  value: '${countFiltered.length}',
                  fg: const Color(0xFF374151),
                  bg: _T.headerBg,
                  border: _T.divider,
                ),
                const SizedBox(width: 8),
                _SummaryChip(
                  label: 'To Collect',
                  value: '₱${AppTheme.fmtAmt(_totalOutstanding)}',
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
            onDateChanged: (range) {
              setState(() => _selectedRange = range);
              _loadRecords();
            },
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
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _search = '');
                },
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
              // A 'balance' record where totalPaid >= orderTotal means
              // the customer has now fully settled their order.
              final isBalFully = g.paymentType == 'balance' &&
                  g.orderTotal > 0 &&
                  g.totalPaid >= g.orderTotal - 0.01;
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
                typeFg: isBalFully
                    ? const Color(0xFF15803D)
                    : _typeFg(g.paymentType),
                typeBg: isBalFully
                    ? const Color(0xFFF0FDF4)
                    : _typeBg(g.paymentType),
                typeBorder: isBalFully
                    ? const Color(0xFFBBF7D0)
                    : _typeBorder(g.paymentType),
                typeLabel: isBalFully
                    ? 'Balance Fully Paid'
                    : _typeLabel(g.paymentType),
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
    final isFullyPaid = type == 'full' ||
        (orderTotal > 0 && totalPaid >= orderTotal - 0.01);
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
                    const Text(
                      'Amount Paid',
                      style: TextStyle(
                        color: _T.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '₱${AppTheme.fmtAmt(totalPaid)}',
                      style: const TextStyle(
                        color: _T.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (orderTotal > 0)
                      Text(
                        'of ₱${AppTheme.fmtAmt(orderTotal)}',
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
                    'Paid ₱${AppTheme.fmtAmt(totalPaid)}',
                    style: const TextStyle(color: _T.textMuted, fontSize: 10),
                  ),
                  Text(
                    'Remaining ₱${AppTheme.fmtAmt((orderTotal - totalPaid).clamp(0, double.infinity))}',
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
    ('full', 'Upfront', Color(0xFF6D28D9)),
    ('refund', 'Refund', Color(0xFFDC2626)),
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
                  child: Row(
                    children: [
                      _PresetChip(
                        label: 'Last 31 days',
                        active: _rangesMatch(selectedRange, _pLast31()),
                        onTap: () => onDateChanged(_pLast31()),
                      ),
                      const SizedBox(width: 6),
                      _PresetChip(
                        label: 'Last 6 months',
                        active: _rangesMatch(selectedRange, _pLast180()),
                        onTap: () => onDateChanged(_pLast180()),
                      ),
                      const SizedBox(width: 6),
                      _PresetChip(
                        label: 'This year',
                        active: _rangesMatch(selectedRange, _pThisYear()),
                        onTap: () => onDateChanged(_pThisYear()),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 28, color: _T.divider),
                      const SizedBox(width: 10),
                      _DateFilterButton(
                        selectedRange: selectedRange,
                        onChanged: onDateChanged,
                      ),
                    ],
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

// ─ Bucket types & granularity ────────────────────────────────────────────────
enum _BucketType { daily, biweekly, triweekly, monthly }

class _Bucket {
  final DateTime start;
  final DateTime end;
  final String label;
  double total;
  _Bucket({
    required this.start,
    required this.end,
    required this.label,
    this.total = 0,
  });
}

String _shortMonth(int m) {
  const n = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return n[m - 1];
}

_BucketType _decideBucketType(int days) {
  if (days <= 31) return _BucketType.daily;
  if (days <= 180) return _BucketType.biweekly;
  if (days <= 330) return _BucketType.triweekly;
  return _BucketType.monthly;
}

// Build dynamic bucket list. If range is null, derives span from data.
List<_Bucket> _buildBuckets(
    List<QueryDocumentSnapshot> allDocs,
    DateTimeRange? range,
    ) {
  final now = _dateOnly(DateTime.now());

  DateTime start, end;
  if (range != null) {
    start = _dateOnly(range.start);
    end = _dateOnly(range.end);
  } else {
    DateTime? earliest, latest;
    for (final doc in allDocs) {
      final ts =
      (doc.data() as Map<String, dynamic>)['sale_date'] as Timestamp?;
      if (ts == null) continue;
      final dt = _dateOnly(ts.toDate().toLocal());
      if (earliest == null || dt.isBefore(earliest)) earliest = dt;
      if (latest == null || dt.isAfter(latest)) latest = dt;
    }
    start = earliest ?? _dateOnly(DateTime(now.year, now.month - 5, 1));
    end = latest ?? now;
  }
  if (end.isBefore(start)) end = start;

  final days = end.difference(start).inDays + 1;
  final type = _decideBucketType(days);
  final buckets = <_Bucket>[];

  if (type == _BucketType.monthly) {
    var m = DateTime(start.year, start.month);
    final endM = DateTime(end.year, end.month);
    while (!m.isAfter(endM)) {
      final nextM = DateTime(m.year, m.month + 1);
      final bEnd = _dateOnly(nextM.subtract(const Duration(days: 1)));
      final label = m.year == DateTime.now().year
          ? _shortMonth(m.month)
          : "${_shortMonth(m.month)}'${m.year.toString().substring(2)}";
      buckets.add(_Bucket(start: m, end: bEnd, label: label));
      m = nextM;
    }
  } else if (type == _BucketType.daily) {
    var d = start;
    while (!d.isAfter(end)) {
      buckets.add(_Bucket(
        start: d,
        end: d,
        label: '${_shortMonth(d.month)} ${d.day}',
      ));
      d = d.add(const Duration(days: 1));
    }
  } else {
    final step = type == _BucketType.biweekly ? 14 : 21;
    var s = start;
    while (!s.isAfter(end)) {
      final raw = s.add(Duration(days: step - 1));
      final e = raw.isAfter(end) ? end : raw;
      buckets.add(_Bucket(
        start: s,
        end: e,
        label: '${_shortMonth(s.month)} ${s.day}',
      ));
      s = s.add(Duration(days: step));
    }
  }
  return buckets;
}

String _granularityLabel(_BucketType type) {
  switch (type) {
    case _BucketType.daily:     return 'Daily Revenue';
    case _BucketType.biweekly:  return 'Revenue per 2 weeks';
    case _BucketType.triweekly: return 'Revenue per 3 weeks';
    case _BucketType.monthly:   return 'Monthly Revenue';
  }
}

// ─ Preset range helpers ───────────────────────────────────────────────────────
DateTimeRange _pLast31() {
  final now = _dateOnly(DateTime.now());
  return DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
}

DateTimeRange _pLast180() {
  final now = _dateOnly(DateTime.now());
  return DateTimeRange(
      start: now.subtract(const Duration(days: 179)), end: now);
}

DateTimeRange _pThisYear() {
  final now = _dateOnly(DateTime.now());
  return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
}

bool _rangesMatch(DateTimeRange? a, DateTimeRange? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return _dateOnly(a.start) == _dateOnly(b.start) &&
      _dateOnly(a.end) == _dateOnly(b.end);
}

// =============================================================================
// Shared Sales Report Content (used by both admin and employee)
// =============================================================================
class _SalesReportContent extends StatefulWidget {
  const _SalesReportContent();

  @override
  State<_SalesReportContent> createState() => _SalesReportContentState();
}

class _SalesReportContentState extends State<_SalesReportContent> {
  DateTimeRange? _range;

  // Price-change analysis (product/service + add-on prices changed from
  // June 2026 onward). Loaded once — same source data the printable Sales
  // Report PDF uses — and filtered client-side by the selected date range.
  List<_PriceChangeRow>? _priceChanges;
  bool _priceChangesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPriceChanges();
  }

  Future<void> _loadPriceChanges() async {
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('Orders').get(),
        db.collection('Order_Queue').get(),
      ]);
      final ordSnap = results[0];
      final oqSnap = results[1];

      // Merge Orders + Order_Queue, de-duplicated by order_id, so the price
      // history covers both current and archived orders — same approach as
      // the PDF's generateAdminSalesReportPdf.
      final seenOrderIds = <String>{};
      final orderDocs = [...ordSnap.docs, ...oqSnap.docs].where((d) {
        final oid = (d.data() as Map<String, dynamic>)['order_id']?.toString() ?? d.id;
        return seenOrderIds.add(oid);
      }).toList();
      final ordersById = <String, Map<String, dynamic>>{
        for (final d in orderDocs)
          ((d.data() as Map<String, dynamic>)['order_id']?.toString() ?? d.id):
          d.data() as Map<String, dynamic>,
      };

      final changes = _buildPriceChangeRows(ordersById);
      if (mounted) {
        setState(() {
          _priceChanges = changes;
          _priceChangesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _priceChangesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Sales_Records')
          .orderBy('sale_date', descending: false)
          .snapshots(),
      builder: (context, salesSnap) {
        if (!salesSnap.hasData) {
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

        // ── Balance to Collect: from Orders (authoritative, excludes cancelled) ──
        // whereIn already drops 'cancelled'. Client-side date filter via paid_at.
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Orders')
              .where('status', whereIn: [
            'pending', 'in_production', 'ready', 'completed',
          ])
              .snapshots(),
          builder: (context, ordSnap) {
            // Non-cancelled orders filtered by paid_at within the selected date range.
            // When _range == null (All time), all active orders are included.
            double outstanding = 0;
            if (ordSnap.hasData) {
              for (final doc in ordSnap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                if (_range != null) {
                  final filterTs = _orderFilterTimestamp(d);
                  if (filterTs == null) continue;
                  if (!_isWithinDateRange(filterTs.toDate().toLocal(), _range)) continue;
                }
                final rem  = (d['remaining_balance'] as num?)?.toDouble() ?? 0;
                final diff = ((d['total_price'] as num?)?.toDouble() ?? 0) -
                    ((d['amount_paid'] as num?)?.toDouble() ?? 0);
                final owed = rem > 0.01 ? rem : (diff > 0.01 ? diff : 0.0);
                if (owed > 0.01) outstanding += owed;
              }
            }

            final allDocs = salesSnap.data!.docs;

            // Date-range filter on Sales_Records
            final filtered = allDocs.where((doc) {
              final ts = (doc.data() as Map<String, dynamic>)['sale_date'] as Timestamp?;
              if (ts == null) return _range == null;
              return _isWithinDateRange(ts.toDate().toLocal(), _range);
            }).toList();

            // Exclude only historical_seed; Excel imports count as real sales
            final appFiltered = filtered.where((doc) {
              final src = (doc.data() as Map<String, dynamic>)['import_source']?.toString() ?? '';
              return src != 'historical_seed';
            }).toList();

            // Chart buckets (refunds excluded from revenue bars)
            final buckets = _buildBuckets(allDocs, _range);
            for (final b in buckets) b.total = 0;
            for (final doc in appFiltered) {
              final d = doc.data() as Map<String, dynamic>;
              final ts = d['sale_date'] as Timestamp?;
              if (ts == null) continue;
              if (_normalizedPaymentType(d) == 'refund') continue;
              final dt = _dateOnly(ts.toDate().toLocal());
              final amt = (d['sale_amount'] as num?)?.toDouble() ?? 0;
              for (final b in buckets) {
                if (!dt.isBefore(b.start) && !dt.isAfter(b.end)) {
                  b.total += amt;
                  break;
                }
              }
            }

            // Revenue breakdown — refunds separate so dp+bal+upt always = totalRevenue
            double totalRevenue = 0, dpTotal = 0, balTotal = 0, uptTotal = 0, refundTotal = 0;
            final orderIds = <String>{};

            for (final doc in appFiltered) {
              final d = doc.data() as Map<String, dynamic>;
              final amt = (d['sale_amount'] as num?)?.toDouble() ?? 0;
              final type = _normalizedPaymentType(d);
              final oid = d['order_id']?.toString() ?? '';

              if (type == 'refund') {
                refundTotal += amt;
              } else {
                totalRevenue += amt;
                if (type == 'downpayment') dpTotal += amt;
                else if (type == 'balance') balTotal += amt;
                else if (type == 'full') uptTotal += amt;
              }
              if (oid.isNotEmpty) orderIds.add(oid);
            }

            final spanDays = _range != null
                ? _range!.end.difference(_range!.start).inDays + 1
                : (buckets.length > 1
                ? buckets.last.end.difference(buckets.first.start).inDays + 1
                : 31);
            final granLabel = _granularityLabel(_decideBucketType(spanDays));

            return _buildBody(
              buckets: buckets,
              granLabel: granLabel,
              totalRevenue: totalRevenue,
              orderCount: orderIds.length,
              dpTotal: dpTotal,
              balTotal: balTotal,
              uptTotal: uptTotal,
              refundTotal: refundTotal,
              outstanding: outstanding,
              priceChanges: _priceChanges,
              priceChangesLoading: _priceChangesLoading,
            );
          },
        );
      },
    );
  }

  Widget _buildBody({
    required List<_Bucket> buckets,
    required String granLabel,
    required double totalRevenue,
    required int orderCount,
    required double dpTotal,
    required double balTotal,
    required double uptTotal,
    required double refundTotal,
    required double outstanding,
    required List<_PriceChangeRow>? priceChanges,
    required bool priceChangesLoading,
  }) {
    final l31  = _pLast31();
    final l180 = _pLast180();
    final tyr  = _pThisYear();

    // Price changes whose start date falls within the selected date range
    // (same filter the rest of the report uses); "All time" shows everything.
    final filteredPriceChanges = (priceChanges ?? []).where((c) {
      if (_range == null) return true;
      if (c.orderDateRaw == null) return false;
      return _isWithinDateRange(c.orderDateRaw!.toDate().toLocal(), _range);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Report',
            style: TextStyle(
              color: _T.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Revenue breakdown and trends',
            style: TextStyle(color: _T.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // ── Quick presets + date picker ──────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _PresetChip(
                  label: 'All time',
                  active: _range == null,
                  onTap: () => setState(() => _range = null),
                ),
                const SizedBox(width: 6),
                _PresetChip(
                  label: 'Last 31 days',
                  active: _rangesMatch(_range, l31),
                  onTap: () => setState(() => _range = l31),
                ),
                const SizedBox(width: 6),
                _PresetChip(
                  label: 'Last 6 months',
                  active: _rangesMatch(_range, l180),
                  onTap: () => setState(() => _range = l180),
                ),
                const SizedBox(width: 6),
                _PresetChip(
                  label: 'This year',
                  active: _rangesMatch(_range, tyr),
                  onTap: () => setState(() => _range = tyr),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 28, color: _T.divider),
                const SizedBox(width: 10),
                _DateFilterButton(
                  selectedRange: _range,
                  onChanged: (r) => setState(() => _range = r),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Summary cards ────────────────────────────────────────────────
          LayoutBuilder(builder: (_, c) {
            final narrow = c.maxWidth < 460;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminReportCard(
                  label: 'Total Revenue',
                  value: '₱${AppTheme.fmtAmt(totalRevenue)}',
                  color: _T.gold,
                  bg: const Color(0xFFFFFBEB),
                  border: const Color(0xFFFDE68A),
                  narrow: narrow,
                ),
                _AdminReportCard(
                  label: 'Orders',
                  value: '$orderCount',
                  color: const Color(0xFF1D4ED8),
                  bg: const Color(0xFFEFF6FF),
                  border: const Color(0xFFBFDBFE),
                  narrow: narrow,
                ),
                _AdminReportCard(
                  label: 'Downpayments',
                  value: '₱${AppTheme.fmtAmt(dpTotal)}',
                  color: const Color(0xFF1D4ED8),
                  bg: const Color(0xFFEFF6FF),
                  border: const Color(0xFFBFDBFE),
                  narrow: narrow,
                  tooltip: 'Partial first payments (At least 50% deposits)',
                ),
                _AdminReportCard(
                  label: 'Balance Collected',
                  value: '₱${AppTheme.fmtAmt(balTotal)}',
                  color: const Color(0xFFB45309),
                  bg: const Color(0xFFFFFBEB),
                  border: const Color(0xFFFDE68A),
                  narrow: narrow,
                  tooltip: 'Remaining balance payments collected',
                ),
                _AdminReportCard(
                  label: 'Upfront Payments',
                  value: '₱${AppTheme.fmtAmt(uptTotal)}',
                  color: const Color(0xFF6D28D9),
                  bg: const Color(0xFFF5F3FF),
                  border: const Color(0xFFDDD6FE),
                  narrow: narrow,
                  tooltip: 'Orders paid 100% at the time of ordering',
                ),
                if (refundTotal > 0)
                  _AdminReportCard(
                    label: 'Refunds',
                    value: '−₱${AppTheme.fmtAmt(refundTotal)}',
                    color: const Color(0xFF9D174D),
                    bg: const Color(0xFFFFF1F2),
                    border: const Color(0xFFFFCDD2),
                    narrow: narrow,
                    tooltip: 'Total refunds paid out in this period',
                  ),
                _AdminReportCard(
                  label: 'Balance to Collect',
                  value: '₱${AppTheme.fmtAmt(outstanding)}',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  narrow: narrow,
                  tooltip: 'Unpaid balance on downpayment orders within the selected period',
                ),
              ],
            );
          }),
          const SizedBox(height: 24),

          // ── Chart card ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.divider),
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
                Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border:
                      Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: Color(0xFF1D4ED8), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          granLabel,
                          style: const TextStyle(
                            color: _T.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _range == null
                              ? 'All time'
                              : '${_formatDateLabel(_range!.start)} – '
                              '${_formatDateLabel(_range!.end)}',
                          style: const TextStyle(
                              color: _T.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                if (buckets.isEmpty)
                  const SizedBox(
                    height: 80,
                    child: Center(
                      child: Text('No data for this period',
                          style: TextStyle(
                              color: _T.textMuted, fontSize: 13)),
                    ),
                  )
                else
                  _InteractiveChart(buckets: buckets),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Price Changes card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _T.divider),
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
                Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(Icons.price_change_rounded,
                        color: Color(0xFFDC2626), size: 15),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price Changes — June 2026 Onward',
                          style: TextStyle(
                            color: _T.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Product, service, and add-on prices updated since June 2026',
                          style: TextStyle(color: _T.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (!priceChangesLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Text(
                        '${filteredPriceChanges.length}',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 16),
                if (priceChangesLoading)
                  const SizedBox(
                    height: 80,
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  _priceChangeTable(filteredPriceChanges),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Price Changes table (web view) ──────────────────────────────────────
  Widget _priceChangeTable(List<_PriceChangeRow> changes) {
    if (changes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No price changes detected for this period.',
            style: TextStyle(color: _T.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    const headerStyle = TextStyle(
      color: _T.textMuted,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    Widget headCell(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(text, style: headerStyle),
    );

    Widget cell(String text, {bool bold = false, Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? _T.textPrimary,
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );

    // Shows just the affected-order count as a compact chip — hover (or
    // long-press on touch) reveals the full list of order IDs via tooltip,
    // so the row height stays consistent instead of stretching to fit
    // dozens of comma-separated order IDs.
    Widget ordersCountCell(List<String> ids) {
      if (ids.isEmpty) return cell('—');
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: ids.join(', '),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                '${ids.length} order${ids.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 780),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(1.3),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.0),
            6: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _T.divider, width: 1.5)),
              ),
              children: [
                headCell('PRODUCT / SERVICE'),
                headCell('ADD-ON SERVICE'),
                headCell('PREVIOUS PRICE'),
                headCell('UPDATED PRICE'),
                headCell('CHANGE STARTED'),
                headCell('DIFFERENCE'),
                headCell('RELATED ORDERS'),
              ],
            ),
            ...changes.map((c) {
              final isIncrease = c.difference > 0;
              final diffColor =
              isIncrease ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
              final diffText =
                  '${isIncrease ? '+' : '-'}₱${AppTheme.fmtAmt(c.difference.abs())}';
              return TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _T.divider, width: 0.7)),
                ),
                children: [
                  cell(c.product, bold: true),
                  cell(c.addonName.isEmpty ? '—' : c.addonName),
                  cell('₱${AppTheme.fmtAmt(c.previousPrice)}'),
                  cell('₱${AppTheme.fmtAmt(c.changedPrice)}'),
                  cell(c.orderDate),
                  cell(diffText, bold: true, color: diffColor),
                  ordersCountCell(c.affectedOrderIds),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─ Preset pill chip ───────────────────────────────────────────────────────────
class _PresetChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PresetChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _T.navy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _T.navy : _T.divider),
          boxShadow: active
              ? const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : _T.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Admin Sales Report View
// =============================================================================
class AdminSalesReportView extends StatelessWidget {
  const AdminSalesReportView({super.key});

  @override
  Widget build(BuildContext context) => const _SalesReportContent();
}

// ─ Report summary card ────────────────────────────────────────────────────────
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
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
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
                child: Icon(Icons.info_outline_rounded,
                    size: 12, color: color.withValues(alpha: 0.5)),
              ),
            ],
          ]),
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

// =============================================================================
// Interactive Chart
// =============================================================================
class _InteractiveChart extends StatefulWidget {
  final List<_Bucket> buckets;
  const _InteractiveChart({required this.buckets});

  @override
  State<_InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<_InteractiveChart> {
  int? _hoverIdx;

  void _updateHover(double dx, double width) {
    final n = widget.buckets.length;
    if (n == 0) return;
    final idx = n == 1
        ? 0
        : (dx / (width / (n - 1))).round().clamp(0, n - 1);
    if (idx != _hoverIdx) setState(() => _hoverIdx = idx);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final width = c.maxWidth;
      final n = widget.buckets.length;

      _Bucket? hov;
      double? hovX;
      if (_hoverIdx != null && _hoverIdx! < n) {
        hov = widget.buckets[_hoverIdx!];
        hovX = n <= 1 ? width / 2 : (_hoverIdx! * width / (n - 1));
      }

      // Show at most 8 x-axis labels to avoid crowding
      final stride = n <= 8 ? 1 : (n / 8).ceil();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            onHover: (e) => _updateHover(e.localPosition.dx, width),
            onExit: (_) => setState(() => _hoverIdx = null),
            child: GestureDetector(
              onTapDown: (d) => _updateHover(d.localPosition.dx, width),
              onPanUpdate: (d) => _updateHover(d.localPosition.dx, width),
              child: SizedBox(
                height: 160,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: Size(width, 160),
                      painter: _ChartPainter(
                        buckets: widget.buckets,
                        hoverIndex: _hoverIdx,
                      ),
                    ),
                    if (hov != null && hovX != null)
                      _buildTooltip(hov, hovX, width),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // X-axis labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(n, (i) {
              final show = i % stride == 0 || i == n - 1;
              final isH = i == _hoverIdx;
              return Expanded(
                child: show
                    ? Text(
                  widget.buckets[i].label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isH ? _T.textPrimary : _T.textMuted,
                    fontSize: 9,
                    fontWeight:
                    isH ? FontWeight.w700 : FontWeight.normal,
                  ),
                )
                    : const SizedBox.shrink(),
              );
            }),
          ),
        ],
      );
    });
  }

  Widget _buildTooltip(_Bucket b, double x, double width) {
    const tw = 140.0;
    var left = x - tw / 2;
    if (left < 0) left = 0;
    if (left + tw > width) left = width - tw;

    final sameDay = b.start == b.end;
    final dateStr = sameDay
        ? '${_shortMonth(b.start.month)} ${b.start.day}'
        : '${_shortMonth(b.start.month)} ${b.start.day}'
        ' – '
        '${_shortMonth(b.end.month)} ${b.end.day}';

    return Positioned(
      left: left,
      top: -6,
      child: Container(
        width: tw,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1A2E),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 10),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            b.total == 0
                ? 'No sales'
                : '₱${AppTheme.fmtAmt(b.total)}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            dateStr,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}

// ─ Chart painter ──────────────────────────────────────────────────────────────
class _ChartPainter extends CustomPainter {
  final List<_Bucket> buckets;
  final int? hoverIndex;
  _ChartPainter({required this.buckets, this.hoverIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (buckets.isEmpty) return;
    final maxVal =
    buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);
    final effMax = maxVal == 0 ? 1.0 : maxVal;
    final n = buckets.length;
    final stepX = n <= 1 ? size.width / 2 : size.width / (n - 1);

    // Horizontal grid lines
    final gPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gPaint);
    }

    // Compute data points
    final pts = List.generate(n, (i) {
      final x = n == 1 ? size.width / 2 : i * stepX;
      return Offset(
        x,
        size.height -
            (buckets[i].total / effMax) * size.height * 0.85,
      );
    });

    // Filled area under line
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) fillPath.lineTo(p.dx, p.dy);
    fillPath
      ..lineTo(pts.last.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x261D4ED8), Color(0x001D4ED8)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Hover vertical guide line
    if (hoverIndex != null && hoverIndex! < pts.length) {
      final hx = pts[hoverIndex!].dx;
      canvas.drawLine(
        Offset(hx, 0),
        Offset(hx, size.height),
        Paint()
          ..color = const Color(0x401D4ED8)
          ..strokeWidth = 1.5,
      );
    }

    // Smooth cubic bezier line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      linePath.cubicTo(
        (prev.dx + curr.dx) / 2, prev.dy,
        (prev.dx + curr.dx) / 2, curr.dy,
        curr.dx, curr.dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF1D4ED8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // Data point dots
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      final isH = i == hoverIndex;
      canvas.drawCircle(p, isH ? 7 : 5, Paint()..color = Colors.white);
      canvas.drawCircle(
          p, isH ? 5 : 3.5, Paint()..color = const Color(0xFF1D4ED8));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter o) =>
      o.buckets != buckets || o.hoverIndex != hoverIndex;
}

// =============================================================================
// Employee Sales Report View  (same content as admin)
// =============================================================================
class SalesReportView extends StatelessWidget {
  const SalesReportView({super.key});

  @override
  Widget build(BuildContext context) => const _SalesReportContent();
}