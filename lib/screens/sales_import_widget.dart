import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _G {
  static const Color primary    = Color(0xFF1A1A2E);
  static const Color textPrimary   = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textMuted     = Color(0xFF9CA3AF);
  static const Color green  = Color(0xFF16A34A);
  static const Color amber  = Color(0xFFB45309);
  static const Color red    = Color(0xFFDC2626);
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2),
  );
}

// ── Column mapping ────────────────────────────────────────────────────────────
const _kExpectedHeaders = [
  'invoice_number', 'sale_date',    'order_date',     'customer_name',
  'product_name',   'type',         'size',            'quantity',
  'unit_price',     'item_total',   'total_amount',    'order_status',
  'payment_status', 'source',       'is_historical',
];

// =============================================================================
// Public entry-point
// =============================================================================
class SalesImportButton extends StatelessWidget {
  const SalesImportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showSalesImportSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _G.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [_G.shadow],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_file_rounded, size: 14, color: Colors.white),
            SizedBox(width: 7),
            Text(
              'Import Records',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Show the import bottom sheet
// =============================================================================
Future<void> showSalesImportSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => const _SalesImportSheet(),
  );
}

// =============================================================================
// Import Sheet
// =============================================================================
enum _ImportStep { idle, parsing, preview, uploading, done, error }

class _SalesImportSheet extends StatefulWidget {
  const _SalesImportSheet();
  @override
  State<_SalesImportSheet> createState() => _SalesImportSheetState();
}

class _SalesImportSheetState extends State<_SalesImportSheet> {
  _ImportStep _step = _ImportStep.idle;
  String? _fileName;
  String? _errorMsg;
  List<_SalesRow> _rows = [];
  int _uploadedCount = 0;
  int _skippedCount  = 0;
  final Set<int> _selected = {};

  // ── Date string → Firestore Timestamp (date only) ─────────────────────────
  static Timestamp? _toTimestamp(String raw) {
    if (raw.isEmpty) return null;
    try {
      final d = DateTime.parse(raw);
      return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
    } catch (_) {
      final fmts = ['dd/MM/yyyy', 'MM-dd-yyyy', 'MM/dd/yyyy', 'd/M/yyyy'];
      for (final fmt in fmts) {
        try {
          final d = DateFormat(fmt).parseStrict(raw);
          return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
        } catch (_) {}
      }
      return null;
    }
  }

  // ── File pick + parse ──────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() {
      _step     = _ImportStep.parsing;
      _fileName = file.name;
      _errorMsg = null;
      _rows     = [];
    });

    try {
      List<_SalesRow> parsed;
      if (file.name.toLowerCase().endsWith('.csv')) {
        parsed = _parseCsv(utf8.decode(file.bytes!));
      } else {
        parsed = _parseXlsx(file.bytes!);
      }

      if (parsed.isEmpty) throw Exception('No valid data rows found.');

      setState(() {
        _rows = parsed;
        _step = _ImportStep.preview;
        _selected.addAll(List.generate(parsed.length, (i) => i));
      });
    } catch (e) {
      setState(() {
        _step     = _ImportStep.error;
        _errorMsg = e.toString();
      });
    }
  }

  // ── XLSX parser ────────────────────────────────────────────────────────────
  List<_SalesRow> _parseXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]!;
    final rows  = sheet.rows;
    if (rows.isEmpty) return [];

    int headerIdx = 0;
    Map<String, int> colMap = {};
    for (int r = 0; r < rows.length.clamp(0, 5); r++) {
      final map = _buildColMap(rows[r]);
      if (map.length >= 5) { headerIdx = r; colMap = map; break; }
    }
    if (colMap.isEmpty) {
      throw Exception(
        'Could not detect header row.\nExpected columns like: invoice_number, sale_date, customer_name …',
      );
    }

    final result = <_SalesRow>[];
    for (int r = headerIdx + 1; r < rows.length; r++) {
      final row = rows[r];
      final inv = _SalesRow._s(row, colMap['invoice_number']);
      if (inv.isEmpty) continue;
      result.add(_SalesRow.fromCells(row, colMap));
    }
    return result;
  }

  // ── CSV parser ─────────────────────────────────────────────────────────────
  List<_SalesRow> _parseCsv(String content) {
    final lines = const LineSplitter().convert(content);
    if (lines.isEmpty) return [];
    final headers = _splitCsvLine(lines[0]);
    final colMap  = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      final key = headers[i].trim().toLowerCase().replaceAll(' ', '_');
      colMap[key] = i;
    }
    if (colMap.length < 5) throw Exception('CSV header row not recognised.');

    final result = <_SalesRow>[];
    for (int i = 1; i < lines.length; i++) {
      final cells = _splitCsvLine(lines[i]);
      if (cells.isEmpty || cells.first.trim().isEmpty) continue;
      result.add(_SalesRow.fromList(cells, colMap));
    }
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Map<String, int> _buildColMap(List<Data?> row) {
    final map = <String, int>{};
    for (int i = 0; i < row.length; i++) {
      final val = _SalesRow._s(row, i).toLowerCase().replaceAll(' ', '_');
      if (_kExpectedHeaders.contains(val)) map[val] = i;
    }
    return map;
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') { inQuotes = !inQuotes; continue; }
      if (c == ',' && !inQuotes) { result.add(buffer.toString()); buffer.clear(); continue; }
      buffer.write(c);
    }
    result.add(buffer.toString());
    return result;
  }

  // ── Upload selected rows to Firestore ──────────────────────────────────────
  Future<void> _upload() async {
    setState(() { _step = _ImportStep.uploading; _uploadedCount = 0; _skippedCount = 0; });

    final fs = FirebaseFirestore.instance;
    final toUpload = _selected.map((i) => _rows[i]).toList();

    final invoiceMap = <String, List<_SalesRow>>{};
    for (final row in toUpload) {
      invoiceMap.putIfAbsent(row.invoiceNumber, () => []).add(row);
    }

    int uploaded = 0, skipped = 0;

    for (final entry in invoiceMap.entries) {
      final invoiceId = entry.key;
      final rows      = entry.value;
      final first     = rows.first;
      final orderId   = invoiceId.replaceFirst('INV-', 'ORD-');

      final existing = await fs.collection('Sales_Records')
          .where('invoice_number', isEqualTo: invoiceId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) { skipped += rows.length; continue; }

      final products = rows.map((r) => {
        'name'       : r.productName,
        'type'       : r.type,
        'size'       : r.size,
        'qty'        : r.quantity,
        'unit_price' : r.unitPrice,
        'item_total' : r.itemTotal,
      }).toList();

      await fs.collection('Sales_Records').doc(orderId).set({
        'order_id'              : orderId,
        'customer_name'         : first.customerName,
        'order_total'           : first.totalAmount,
        'sale_amount'           : first.totalAmount,
        'payment_method'        : first.source,
        'payment_type'          : 'full',
        'sale_date'             : _toTimestamp(first.saleDate),
        'order_status'          : first.orderStatus,
        'payment_status'        : first.paymentStatus,
        'is_historical'         : first.isHistorical,
        'products'              : products,
        'transaction_reference' : 'imported',
        'imported_at'           : FieldValue.serverTimestamp(),
        'import_source'         : 'manual_xlsx_import',
      });
      uploaded += rows.length;
    }

    setState(() {
      _uploadedCount = uploaded;
      _skippedCount  = skipped;
      _step          = _ImportStep.done;
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 36, height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 16, 14),
    child: Row(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _G.primary,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import Sales Records',
                  style: TextStyle(color: _G.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              SizedBox(height: 1),
              Text('Upload an XLSX or CSV file to inject historical records',
                  style: TextStyle(color: _G.textMuted, fontSize: 11)),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: _G.textMuted, size: 20),
        ),
      ],
    ),
  );

  Widget _buildBody() {
    switch (_step) {
      case _ImportStep.idle:      return _buildIdle();
      case _ImportStep.parsing:   return _buildLoading('Parsing file…');
      case _ImportStep.preview:   return _buildPreview();
      case _ImportStep.uploading: return _buildLoading('Uploading records…');
      case _ImportStep.done:      return _buildDone();
      case _ImportStep.error:     return _buildError();
    }
  }

  // ── Idle ──────────────────────────────────────────────────────────────────
  Widget _buildIdle() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          child: const Icon(Icons.table_chart_outlined, size: 36, color: _G.primary),
        ),
        const SizedBox(height: 22),
        const Text('No file selected',
            style: TextStyle(color: _G.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Supports .xlsx, .xls, and .csv files\nColumns: invoice_number, sale_date, customer_name …',
            style: TextStyle(color: _G.textMuted, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center),
        const SizedBox(height: 28),
        _PillButton(
          label: 'Choose File',
          icon: Icons.folder_open_rounded,
          onTap: _pickFile,
          color: _G.primary,
        ),
        const SizedBox(height: 12),
        _buildFormatHint(),
      ],
    ),
  );

  Widget _buildFormatHint() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 32),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: _G.amber),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Required columns (in any order):\ninvoice_number · sale_date · customer_name · product_name · total_amount · order_status',
            style: TextStyle(color: _G.amber, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );

  // ── Loading ────────────────────────────────────────────────────────────────
  Widget _buildLoading(String msg) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(strokeWidth: 2.5, color: _G.primary),
        const SizedBox(height: 20),
        Text(msg, style: const TextStyle(color: _G.textSecondary, fontSize: 13)),
      ],
    ),
  );

  // ── Preview ────────────────────────────────────────────────────────────────
  Widget _buildPreview() {
    final selectedCount = _selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 13, color: _G.textMuted),
                    const SizedBox(width: 5),
                    Text(_fileName ?? '', style: const TextStyle(color: _G.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Text('${_rows.length} rows found',
                    style: const TextStyle(color: _G.green, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _pickFile,
                child: const Text('Change file',
                    style: TextStyle(color: _G.primary, fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Checkbox(
                value: selectedCount == _rows.length
                    ? true
                    : selectedCount == 0 ? false : null,
                tristate: true,
                activeColor: _G.primary,
                onChanged: (_) {
                  setState(() {
                    if (selectedCount == _rows.length) {
                      _selected.clear();
                    } else {
                      _selected.addAll(List.generate(_rows.length, (i) => i));
                    }
                  });
                },
              ),
              Text('Select all  ($selectedCount / ${_rows.length} selected)',
                  style: const TextStyle(color: _G.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Duplicates will be skipped automatically',
                  style: const TextStyle(color: _G.textMuted, fontSize: 10)),
            ],
          ),
        ),

        _buildTableHeader(),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (_, i) => _buildPreviewRow(i),
          ),
        ),

        _buildImportBar(selectedCount),
      ],
    );
  }

  Widget _buildTableHeader() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: const Row(
      children: [
        SizedBox(width: 32),
        Expanded(flex: 2, child: _TH('Invoice')),
        Expanded(flex: 3, child: _TH('Customer')),
        Expanded(flex: 2, child: _TH('Date')),
        Expanded(flex: 2, child: _TH('Product')),
        SizedBox(width: 80, child: _TH('Total', right: true)),
        SizedBox(width: 70, child: _TH('Status', center: true)),
      ],
    ),
  );

  Widget _buildPreviewRow(int i) {
    final row = _rows[i];
    final isSelected = _selected.contains(i);
    return GestureDetector(
      onTap: () => setState(() => isSelected ? _selected.remove(i) : _selected.add(i)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F4FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFBFCFFF) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected, activeColor: _G.primary,
                onChanged: (_) => setState(() => isSelected ? _selected.remove(i) : _selected.add(i)),
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(flex: 2, child: _Cell(row.invoiceNumber, mono: true)),
            Expanded(flex: 3, child: _Cell(row.customerName)),
            Expanded(flex: 2, child: _Cell(row.saleDate)),
            Expanded(flex: 2, child: _Cell(row.productName, muted: true)),
            SizedBox(
              width: 80,
              child: Text(
                row.totalAmount > 0 ? '₱${row.totalAmount.toStringAsFixed(2)}' : '—',
                style: const TextStyle(color: _G.amber, fontSize: 12, fontWeight: FontWeight.w700),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(width: 70, child: _StatusPill(row.orderStatus)),
          ],
        ),
      ),
    );
  }

  Widget _buildImportBar(int count) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count record${count == 1 ? '' : 's'} selected',
                    style: const TextStyle(color: _G.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                const Text('Existing invoices will be skipped',
                    style: TextStyle(color: _G.textMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _PillButton(
            label: 'Import Now',
            icon: Icons.cloud_upload_rounded,
            onTap: count == 0 ? null : _upload,
            color: _G.green,
          ),
        ],
      ),
    ),
  );

  // ── Done ──────────────────────────────────────────────────────────────────
  Widget _buildDone() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
            ),
            child: const Icon(Icons.check_circle_rounded, color: _G.green, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Import Complete!',
              style: TextStyle(color: _G.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _StatRow(label: 'Records imported', value: '$_uploadedCount', color: _G.green),
          const SizedBox(height: 6),
          if (_skippedCount > 0)
            _StatRow(label: 'Duplicates skipped', value: '$_skippedCount', color: _G.amber),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PillButton(
                label: 'Import Another',
                icon: Icons.upload_file_rounded,
                onTap: () => setState(() { _step = _ImportStep.idle; _rows = []; _selected.clear(); }),
                color: _G.primary,
              ),
              const SizedBox(width: 10),
              _PillButton(
                label: 'Close',
                icon: Icons.close_rounded,
                onTap: () => Navigator.pop(context),
                color: _G.textMuted,
                outlined: true,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
            ),
            child: const Icon(Icons.error_outline_rounded, color: _G.red, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Parse Error',
              style: TextStyle(color: _G.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(_errorMsg ?? 'Unknown error',
              style: const TextStyle(color: _G.textSecondary, fontSize: 12, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _PillButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            onTap: () => setState(() { _step = _ImportStep.idle; _errorMsg = null; }),
            color: _G.primary,
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// Data model for a parsed row
// =============================================================================
class _SalesRow {
  final String invoiceNumber;
  final String saleDate;
  final String orderDate;
  final String customerName;
  final String productName;
  final String type;
  final String size;
  final int    quantity;
  final double unitPrice;
  final double itemTotal;
  final double totalAmount;
  final String orderStatus;
  final String paymentStatus;
  final String source;
  final bool   isHistorical;

  _SalesRow({
    required this.invoiceNumber,
    required this.saleDate,
    required this.orderDate,
    required this.customerName,
    required this.productName,
    required this.type,
    required this.size,
    required this.quantity,
    required this.unitPrice,
    required this.itemTotal,
    required this.totalAmount,
    required this.orderStatus,
    required this.paymentStatus,
    required this.source,
    required this.isHistorical,
  });

  // ── Unwrap CellValue → String ──────────────────────────────────────────────
  static String _s(List<Data?> row, int? idx) {
    if (idx == null || idx >= row.length) return '';
    final cell = row[idx];
    if (cell == null) return '';
    if (cell.value is IntCellValue)    return (cell.value as IntCellValue).value.toString();
    if (cell.value is DoubleCellValue) return (cell.value as DoubleCellValue).value.toString();
    if (cell.value is DateCellValue)   return (cell.value as DateCellValue).asDateTimeLocal().toIso8601String();
    // For TextCellValue and anything else, use the cell's own toString override
    final raw = cell.value?.toString() ?? '';
    // strip Flutter's TextSpan debug representation if present
    final match = RegExp(r'«(.*?)»').firstMatch(raw);
    return (match?.group(1) ?? raw).trim();
  }

  static double _num(List<Data?> row, int? idx) {
    if (idx == null || idx >= row.length) return 0;
    final cell = row[idx];
    if (cell == null) return 0;
    if (cell.value is IntCellValue)    return (cell.value as IntCellValue).value.toDouble();
    if (cell.value is DoubleCellValue) return (cell.value as DoubleCellValue).value;
    return double.tryParse(_s(row, idx).replaceAll(',', '')) ?? 0;
  }

  // ── CSV string cell ────────────────────────────────────────────────────────
  static String _sl(List<String> cells, int? idx) {
    if (idx == null || idx >= cells.length) return '';
    return cells[idx].trim();
  }

  factory _SalesRow.fromCells(List<Data?> row, Map<String, int> m) {
    return _SalesRow(
      invoiceNumber: _s(row, m['invoice_number']),
      saleDate     : _s(row, m['sale_date']),
      orderDate    : _s(row, m['order_date']),
      customerName : _s(row, m['customer_name']),
      productName  : _s(row, m['product_name']),
      type         : _s(row, m['type']),
      size         : _s(row, m['size']),
      quantity     : _num(row, m['quantity']).toInt(),
      unitPrice    : _num(row, m['unit_price']),
      itemTotal    : _num(row, m['item_total']),
      totalAmount  : _num(row, m['total_amount']),
      orderStatus  : _s(row, m['order_status']).isNotEmpty  ? _s(row, m['order_status'])  : 'completed',
      paymentStatus: _s(row, m['payment_status']).isNotEmpty ? _s(row, m['payment_status']) : 'paid',
      source       : _s(row, m['source']).isNotEmpty        ? _s(row, m['source'])         : 'walk-in',
      isHistorical : _s(row, m['is_historical']).toLowerCase() == 'true',
    );
  }

  factory _SalesRow.fromList(List<String> cells, Map<String, int> m) {
    return _SalesRow(
      invoiceNumber: _sl(cells, m['invoice_number']),
      saleDate     : _sl(cells, m['sale_date']),
      orderDate    : _sl(cells, m['order_date']),
      customerName : _sl(cells, m['customer_name']),
      productName  : _sl(cells, m['product_name']),
      type         : _sl(cells, m['type']),
      size         : _sl(cells, m['size']),
      quantity     : int.tryParse(_sl(cells, m['quantity'])) ?? 1,
      unitPrice    : double.tryParse(_sl(cells, m['unit_price']).replaceAll(',', '')) ?? 0,
      itemTotal    : double.tryParse(_sl(cells, m['item_total']).replaceAll(',', '')) ?? 0,
      totalAmount  : double.tryParse(_sl(cells, m['total_amount']).replaceAll(',', '')) ?? 0,
      orderStatus  : _sl(cells, m['order_status']).isNotEmpty  ? _sl(cells, m['order_status'])  : 'completed',
      paymentStatus: _sl(cells, m['payment_status']).isNotEmpty ? _sl(cells, m['payment_status']) : 'paid',
      source       : _sl(cells, m['source']).isNotEmpty        ? _sl(cells, m['source'])         : 'walk-in',
      isHistorical : _sl(cells, m['is_historical']).toLowerCase() == 'true',
    );
  }
}

// =============================================================================
// Small helper widgets
// =============================================================================
class _PillButton extends StatelessWidget {
  final String   label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color    color;
  final bool     outlined;

  const _PillButton({
    required this.label, required this.icon, required this.onTap,
    required this.color, this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.4 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(10),
            border: outlined ? Border.all(color: color, width: 1.5) : null,
            boxShadow: outlined ? null : const [_G.shadow],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: outlined ? color : Colors.white),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(
                color: outlined ? color : Colors.white,
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.1,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  final bool right;
  final bool center;
  const _TH(this.text, {this.right = false, this.center = false});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: Color(0xFF374151), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      textAlign: right ? TextAlign.right : center ? TextAlign.center : TextAlign.left);
}

class _Cell extends StatelessWidget {
  final String text;
  final bool mono;
  final bool muted;
  const _Cell(this.text, {this.mono = false, this.muted = false});
  @override
  Widget build(BuildContext context) => Text(
    text.isEmpty ? '—' : text,
    style: TextStyle(
      color: muted ? _G.textMuted : _G.textPrimary,
      fontSize: 11,
      fontWeight: mono ? FontWeight.w600 : FontWeight.w400,
      fontFamily: mono ? 'monospace' : null,
    ),
    overflow: TextOverflow.ellipsis,
    maxLines: 1,
  );
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  static Color _c(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return _G.green;
      case 'pending':   return _G.amber;
      case 'cancelled': return _G.red;
      case 'paid':      return _G.green;
      default:          return _G.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c(status);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          status.isEmpty ? '—' : status[0].toUpperCase() + status.substring(1),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatRow({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(label, style: const TextStyle(color: _G.textSecondary, fontSize: 13)),
      const SizedBox(width: 8),
      Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
    ],
  );
}