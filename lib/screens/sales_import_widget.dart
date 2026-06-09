import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import '../services/sales_file_picker.dart';

const kSalesExcelStoragePath = 'sales_records/historical_sales.xlsx';

const _kExpectedHeaders = [
  'invoice_number', 'sale_date',    'order_date',     'customer_name',
  'product_name',   'type',         'size',            'quantity',
  'unit_price',     'item_total',   'total_amount',    'order_status',
  'payment_status', 'source',       'is_historical',  'width_ft',
  'height_ft',
];

// ── Design tokens ─────────────────────────────────────────────────────────────
class _G {
  static const Color primary       = Color(0xFF1A1A2E);
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

// ── Cell helpers (top-level, shared) ──────────────────────────────────────────
String _cellStr(List<Data?> row, int? idx) {
  if (idx == null || idx >= row.length) return '';
  final cell = row[idx];
  if (cell == null) return '';
  try {
    if (cell.value is IntCellValue)    return (cell.value as IntCellValue).value.toString();
    if (cell.value is DoubleCellValue) return (cell.value as DoubleCellValue).value.toString();
    if (cell.value is DateCellValue) {
      // asDateTimeLocal() can throw if the cell was constructed without a valid date
      try {
        return (cell.value as DateCellValue).asDateTimeLocal().toIso8601String();
      } catch (_) {
        return cell.value.toString();
      }
    }
    final raw   = cell.value?.toString() ?? '';
    final match = RegExp(r'«(.*?)»').firstMatch(raw);
    return (match?.group(1) ?? raw).trim();
  } catch (_) {
    return '';
  }
}

double _cellNum(List<Data?> row, int? idx) {
  if (idx == null || idx >= row.length) return 0;
  final cell = row[idx];
  if (cell == null) return 0;
  if (cell.value is IntCellValue)    return (cell.value as IntCellValue).value.toDouble();
  if (cell.value is DoubleCellValue) return (cell.value as DoubleCellValue).value;
  return double.tryParse(_cellStr(row, idx).replaceAll(',', '')) ?? 0;
}

Map<String, int> _buildColMap(List<Data?> row) {
  final map = <String, int>{};
  for (int i = 0; i < row.length; i++) {
    final val = _cellStr(row, i).toLowerCase().replaceAll(' ', '_');
    if (_kExpectedHeaders.contains(val)) map[val] = i;
  }
  return map;
}

Timestamp? _toTimestamp(String raw) {
  if (raw.isEmpty) return null;
  try {
    final d = DateTime.parse(raw);
    return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
  } catch (_) {}
  for (final fmt in ['dd/MM/yyyy', 'MM-dd-yyyy', 'MM/dd/yyyy', 'd/M/yyyy']) {
    try {
      final d = DateFormat(fmt).parseStrict(raw);
      return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
    } catch (_) {}
  }
  return null;
}

// =============================================================================
// Invoice data model (one entry per unique invoice_number)
// =============================================================================
class _InvoiceData {
  final String   orderId;
  final String   invoiceNumber;
  final String   customerName;
  final double   totalAmount;
  final String   saleDate;
  final String   orderStatus;
  final String   paymentStatus;
  final String   source;
  final bool     isHistorical;
  final List<Map<String, dynamic>> products;

  _InvoiceData({
    required this.orderId,
    required this.invoiceNumber,
    required this.customerName,
    required this.totalAmount,
    required this.saleDate,
    required this.orderStatus,
    required this.paymentStatus,
    required this.source,
    required this.isHistorical,
    required this.products,
  });

  Map<String, dynamic> toFirestoreMap() => {
    'order_id'              : orderId,
    'invoice_number'        : invoiceNumber,
    'customer_name'         : customerName,
    'order_total'           : totalAmount,
    'sale_amount'           : totalAmount,
    'payment_method'        : source,
    'payment_type'          : 'full',
    'sale_date'             : _toTimestamp(saleDate) ?? Timestamp.now(),
    'order_status'          : orderStatus,
    'payment_status'        : paymentStatus,
    'is_historical'         : isHistorical,
    'products'              : products,
    'transaction_reference' : 'imported',
    'imported_at'           : FieldValue.serverTimestamp(),
    'import_source'         : 'manual_xlsx_import',
  };
}

// =============================================================================
// Public entry-point button
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
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
// Import sheet — upload to Storage then batch-write to Firestore
// =============================================================================
enum _UploadStep { idle, uploading, processing, done, clearing, cleared, error }

class _SalesImportSheet extends StatefulWidget {
  const _SalesImportSheet();
  @override
  State<_SalesImportSheet> createState() => _SalesImportSheetState();
}

class _SalesImportSheetState extends State<_SalesImportSheet> {
  _UploadStep _step           = _UploadStep.idle;
  String?     _fileName;
  String?     _errorMsg;
  double?     _uploadProgress;
  int         _processedCount = 0;
  int         _totalCount     = 0;
  int         _deletedCount   = 0;
  bool?       _hasExistingFile;   // null = still checking
  String?     _existingFileName;

  @override
  void initState() {
    super.initState();
    _checkExistingFile();
  }

  Future<void> _checkExistingFile() async {
    try {
      final meta = await FirebaseStorage.instance
          .ref(kSalesExcelStoragePath)
          .getMetadata();
      if (mounted) setState(() {
        _hasExistingFile   = true;
        _existingFileName  = meta.customMetadata?['originalName'] ?? 'historical_sales.xlsx';
      });
    } catch (_) {
      if (mounted) setState(() => _hasExistingFile = false);
    }
  }

  // ── Download existing file from Storage → Import to Firestore ──────────────
  Future<void> _processExistingFile() async {
    setState(() {
      _step           = _UploadStep.processing;
      _errorMsg       = null;
      _processedCount = 0;
      _totalCount     = 0;
    });
    try {
      final bytes = await FirebaseStorage.instance
          .ref(kSalesExcelStoragePath)
          .getData(50 * 1024 * 1024);
      if (bytes == null) throw Exception('Could not download file from storage.');
      await _importToFirestore(bytes);
    } catch (e) {
      if (mounted) setState(() {
        _step     = _UploadStep.error;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Pick → Upload to Storage → Import to Firestore ─────────────────────────
  Future<void> _pickAndUpload() async {
    final picked = await pickSalesFile();
    if (picked == null) return;

    final (fileName, bytes) = picked;
    setState(() {
      _step           = _UploadStep.uploading;
      _fileName       = fileName;
      _errorMsg       = null;
      _uploadProgress = null;
    });

    try {
      // 1 ─ Upload raw file to Storage (backup + source of truth)
      final ref  = FirebaseStorage.instance.ref(kSalesExcelStoragePath);
      final task = ref.putData(
        bytes,
        SettableMetadata(
          contentType: fileName.endsWith('.csv') ? 'text/csv'
              : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          customMetadata: {'originalName': fileName},
        ),
      );
      task.snapshotEvents.listen((snap) {
        if (!mounted) return;
        setState(() {
          _uploadProgress = snap.totalBytes > 0
              ? snap.bytesTransferred / snap.totalBytes
              : null;
        });
      });
      await task;

      // 2 ─ Parse bytes and batch-write to Firestore
      if (mounted) {
        setState(() {
          _step           = _UploadStep.processing;
          _processedCount = 0;
          _totalCount     = 0;
        });
      }
      await _importToFirestore(bytes);
    } catch (e) {
      if (mounted) setState(() {
        _step     = _UploadStep.error;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Parse bytes → group by invoice → batch write ───────────────────────────
  Future<void> _importToFirestore(List<int> bytes) async {
    final invoiceMap = _parseBytesForImport(bytes);
    if (invoiceMap.isEmpty) throw Exception('No valid invoice data found in file.');

    final invoices = invoiceMap.values.toList();
    if (mounted) setState(() => _totalCount = invoices.length);

    final fs        = FirebaseFirestore.instance;
    const batchSize = 400;
    int done        = 0;

    while (done < invoices.length) {
      final batch = fs.batch();
      final slice = invoices.skip(done).take(batchSize);
      for (final inv in slice) {
        batch.set(
          fs.collection('Sales_Records').doc(inv.orderId),
          inv.toFirestoreMap(),
        );
      }
      await batch.commit();
      done += slice.length;
      if (mounted) setState(() => _processedCount = done);
    }

    if (mounted) setState(() => _step = _UploadStep.done);
  }

  // ── Delete all imported records from Firestore ────────────────────────────
  Future<void> _clearImportedRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Imported Records',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        content: const Text(
          'This will permanently delete all records imported from Excel/CSV.\n\n'
          'Sales totals and revenue figures will revert to system orders only.',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Color(0xFFDC2626)),
            child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _step = _UploadStep.clearing; _deletedCount = 0; _errorMsg = null; });

    try {
      final fs = FirebaseFirestore.instance;
      int deleted = 0;
      while (true) {
        final snap = await fs.collection('Sales_Records')
            .where('import_source', isEqualTo: 'manual_xlsx_import')
            .limit(400)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = fs.batch();
        for (final doc in snap.docs) batch.delete(doc.reference);
        await batch.commit();
        deleted += snap.docs.length;
        if (mounted) setState(() => _deletedCount = deleted);
      }
      if (mounted) setState(() { _step = _UploadStep.cleared; _deletedCount = deleted; });
    } catch (e) {
      if (mounted) setState(() { _step = _UploadStep.error; _errorMsg = e.toString(); });
    }
  }

  // ── Parse bytes → auto-detect XLSX (PK magic) vs CSV ─────────────────────
  Map<String, _InvoiceData> _parseBytesForImport(List<int> bytes) {
    final isXlsx = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    return isXlsx ? _parseXlsx(bytes) : _parseCsv(bytes);
  }

  Map<String, _InvoiceData> _parseXlsx(List<int> bytes) {
    Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (_) {
      throw Exception(
        'Could not read the Excel file.\n\n'
        'Please open the file in Excel and save it as CSV:\n'
        'File → Save As → CSV (Comma delimited)\n'
        'Then upload the .csv file instead.',
      );
    }

    if (excel.tables.isEmpty) throw Exception('Excel file has no sheets.');
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) throw Exception('Excel file has no sheets.');
    final rows = sheet.rows;
    if (rows.isEmpty) return {};

    int headerIdx = 0;
    Map<String, int> colMap = {};
    for (int r = 0; r < rows.length.clamp(0, 5); r++) {
      try {
        final map = _buildColMap(rows[r]);
        if (map.length >= 3) { headerIdx = r; colMap = map; break; }
      } catch (_) {}
    }
    if (colMap.isEmpty) {
      throw Exception(
        'Could not detect header row.\n'
        'Expected columns: invoice_number, sale_date, customer_name, product_name, total_amount',
      );
    }

    return _groupInvoices(
      rowCount     : rows.length,
      headerIdx    : headerIdx,
      getInvoiceNo : (r) => _cellStr(rows[r], colMap['invoice_number']),
      makeProduct  : (r) {
        final wft = _cellNum(rows[r], colMap['width_ft']);
        final hft = _cellNum(rows[r], colMap['height_ft']);
        return {
          'name'      : _cellStr(rows[r], colMap['product_name']),
          'type'      : _cellStr(rows[r], colMap['type']),
          'size'      : _cellStr(rows[r], colMap['size']),
          'qty'       : _cellNum(rows[r], colMap['quantity']).toInt(),
          'unit_price': _cellNum(rows[r], colMap['unit_price']),
          'item_total': _cellNum(rows[r], colMap['item_total']),
          if (wft > 0 && hft > 0) 'width_ft':  wft,
          if (wft > 0 && hft > 0) 'height_ft': hft,
        };
      },
      makeInvoice  : (r, orderId, inv, prod) => _InvoiceData(
        orderId      : orderId,
        invoiceNumber: inv,
        customerName : _cellStr(rows[r], colMap['customer_name']),
        totalAmount  : _cellNum(rows[r], colMap['total_amount']),
        saleDate     : _cellStr(rows[r], colMap['sale_date']),
        orderStatus  : _cellStr(rows[r], colMap['order_status']).isNotEmpty
            ? _cellStr(rows[r], colMap['order_status']) : 'completed',
        paymentStatus: _cellStr(rows[r], colMap['payment_status']).isNotEmpty
            ? _cellStr(rows[r], colMap['payment_status']) : 'paid',
        source       : _cellStr(rows[r], colMap['source']).isNotEmpty
            ? _cellStr(rows[r], colMap['source']) : 'walk-in',
        isHistorical : _cellStr(rows[r], colMap['is_historical']).toLowerCase() == 'true',
        products     : [prod],
      ),
    );
  }

  Map<String, _InvoiceData> _parseCsv(List<int> bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    final lines   = const LineSplitter().convert(content);
    if (lines.isEmpty) return {};

    final headers = _splitCsv(lines[0]);
    final colMap  = <String, int>{};
    for (int i = 0; i < headers.length; i++) {
      final key = headers[i].trim().toLowerCase().replaceAll(' ', '_');
      if (_kExpectedHeaders.contains(key)) colMap[key] = i;
    }
    if (colMap.length < 3) {
      throw Exception(
        'CSV header row not recognised.\n'
        'Expected columns: invoice_number, sale_date, customer_name, product_name, total_amount',
      );
    }

    final dataRows = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      dataRows.add(_splitCsv(lines[i]));
    }

    String cs(List<String> c, String key) {
      final idx = colMap[key];
      if (idx == null || idx >= c.length) return '';
      return c[idx].trim();
    }
    double cd(List<String> c, String key) =>
        double.tryParse(cs(c, key).replaceAll(',', '')) ?? 0;

    return _groupInvoices(
      rowCount     : dataRows.length + 1,
      headerIdx    : 0,
      getInvoiceNo : (r) => cs(dataRows[r - 1], 'invoice_number'),
      makeProduct  : (r) {
        final c   = dataRows[r - 1];
        final wft = cd(c, 'width_ft');
        final hft = cd(c, 'height_ft');
        return {
          'name'      : cs(c, 'product_name'),
          'type'      : cs(c, 'type'),
          'size'      : cs(c, 'size'),
          'qty'       : int.tryParse(cs(c, 'quantity')) ?? 1,
          'unit_price': cd(c, 'unit_price'),
          'item_total': cd(c, 'item_total'),
          if (wft > 0 && hft > 0) 'width_ft':  wft,
          if (wft > 0 && hft > 0) 'height_ft': hft,
        };
      },
      makeInvoice  : (r, orderId, inv, prod) {
        final c = dataRows[r - 1];
        return _InvoiceData(
          orderId      : orderId,
          invoiceNumber: inv,
          customerName : cs(c, 'customer_name'),
          totalAmount  : cd(c, 'total_amount'),
          saleDate     : cs(c, 'sale_date'),
          orderStatus  : cs(c, 'order_status').isNotEmpty  ? cs(c, 'order_status')  : 'completed',
          paymentStatus: cs(c, 'payment_status').isNotEmpty ? cs(c, 'payment_status') : 'paid',
          source       : cs(c, 'source').isNotEmpty        ? cs(c, 'source')         : 'walk-in',
          isHistorical : cs(c, 'is_historical').toLowerCase() == 'true',
          products     : [prod],
        );
      },
    );
  }

  // ── Shared grouping logic ─────────────────────────────────────────────────
  Map<String, _InvoiceData> _groupInvoices({
    required int rowCount,
    required int headerIdx,
    required String Function(int r) getInvoiceNo,
    required Map<String, dynamic> Function(int r) makeProduct,
    required _InvoiceData Function(int r, String orderId, String inv, Map<String, dynamic> prod) makeInvoice,
  }) {
    final result = <String, _InvoiceData>{};
    for (int r = headerIdx + 1; r < rowCount; r++) {
      try {
        final inv = getInvoiceNo(r);
        if (inv.isEmpty) continue;
        final orderId = inv.replaceFirst('INV-', 'ORD-');
        final prod    = makeProduct(r);
        if (result.containsKey(orderId)) {
          result[orderId]!.products.add(prod);
        } else {
          result[orderId] = makeInvoice(r, orderId, inv, prod);
        }
      } catch (_) {}
    }
    return result;
  }

  // ── CSV line parser (handles quoted fields) ───────────────────────────────
  List<String> _splitCsv(String line) {
    final result = <String>[];
    final buf    = StringBuffer();
    bool inQ     = false;
    for (final ch in line.runes.map(String.fromCharCode)) {
      if (ch == '"') { inQ = !inQ; continue; }
      if (ch == ',' && !inQ) { result.add(buf.toString()); buf.clear(); continue; }
      buf.write(ch);
    }
    result.add(buf.toString());
    return result;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.58,
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
            color: _G.primary, borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import Sales Records',
                  style: TextStyle(color: _G.textPrimary, fontSize: 16,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              SizedBox(height: 1),
              Text('Upload an Excel (.xlsx) or CSV file — records are saved directly to the database',
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
      case _UploadStep.idle:       return _buildIdle();
      case _UploadStep.uploading:  return _buildUploading();
      case _UploadStep.processing: return _buildProcessing();
      case _UploadStep.done:       return _buildDone();
      case _UploadStep.clearing:   return _buildClearing();
      case _UploadStep.cleared:    return _buildCleared();
      case _UploadStep.error:      return _buildError();
    }
  }

  // ── Idle ──────────────────────────────────────────────────────────────────
  Widget _buildIdle() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 20),
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
        const Text('Import Sales Records',
            style: TextStyle(color: _G.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Upload a new .xlsx file or process the already-uploaded file to import into the database.',
            style: TextStyle(color: _G.textMuted, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 24),
        // ── Process already-uploaded file ──
        if (_hasExistingFile == true) ...[
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined, size: 14, color: _G.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _existingFileName ?? 'historical_sales.xlsx',
                    style: const TextStyle(color: _G.green, fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('already uploaded', style: TextStyle(color: _G.green, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PillButton(
            label: 'Process Existing File',
            icon: Icons.play_circle_outline_rounded,
            onTap: _processExistingFile,
            color: _G.green,
          ),
          const SizedBox(height: 10),
          const Text('— or upload a new file —',
              style: TextStyle(color: _G.textMuted, fontSize: 11)),
          const SizedBox(height: 10),
        ],
        _PillButton(
          label: 'Choose & Upload File',
          icon: Icons.folder_open_rounded,
          onTap: _pickAndUpload,
          color: _G.primary,
        ),
        const SizedBox(height: 16),
        _buildHint(),
        const SizedBox(height: 16),
        const Divider(indent: 32, endIndent: 32, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 12),
        _PillButton(
          label: 'Clear Imported Records',
          icon: Icons.delete_sweep_rounded,
          onTap: _clearImportedRecords,
          color: _G.red,
          outlined: true,
        ),
        const SizedBox(height: 4),
        const Text(
          'Removes all Excel/CSV-imported records from the database',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );

  Widget _buildHint() => Container(
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
            'Accepted: .xlsx or .csv\n'
            'Required: invoice_number · sale_date · customer_name · product_name · quantity · total_amount\n'
            'Optional: width_ft · height_ft  (improves forecast accuracy for size-based products)\n'
            'Multiple product rows per invoice are grouped automatically.',
            style: TextStyle(color: _G.amber, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );

  // ── Uploading ─────────────────────────────────────────────────────────────
  Widget _buildUploading() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(
              value: _uploadProgress, strokeWidth: 3, color: _G.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Uploading${_fileName != null ? ' $_fileName' : ''}…',
            style: const TextStyle(color: _G.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (_uploadProgress != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(_uploadProgress! * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: _G.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );

  // ── Processing ────────────────────────────────────────────────────────────
  Widget _buildProcessing() {
    final progress = _totalCount > 0 ? _processedCount / _totalCount : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56, height: 56,
              child: CircularProgressIndicator(
                value: progress, strokeWidth: 3, color: _G.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Importing records…',
                style: TextStyle(color: _G.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              _totalCount > 0
                  ? '$_processedCount / $_totalCount invoices written'
                  : 'Parsing file…',
              style: const TextStyle(color: _G.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ── Clearing ─────────────────────────────────────────────────────────────
  Widget _buildClearing() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(strokeWidth: 3, color: _G.red),
          ),
          const SizedBox(height: 20),
          const Text('Deleting imported records…',
              style: TextStyle(color: _G.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            _deletedCount > 0 ? '$_deletedCount records deleted so far…' : 'Searching records…',
            style: const TextStyle(color: _G.textMuted, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  // ── Cleared ───────────────────────────────────────────────────────────────
  Widget _buildCleared() => Center(
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
            child: const Icon(Icons.delete_sweep_rounded, color: _G.red, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Records Cleared',
              style: TextStyle(color: _G.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(
            '$_deletedCount imported record${_deletedCount == 1 ? '' : 's'} deleted from database',
            style: const TextStyle(color: _G.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Sales totals now reflect system orders only.',
            style: TextStyle(color: _G.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 28),
          _PillButton(
            label: 'Close',
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
            color: _G.textMuted,
            outlined: true,
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
          Text(
            '$_totalCount invoice${_totalCount == 1 ? '' : 's'} imported to database',
            style: const TextStyle(color: _G.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PillButton(
                label: 'Import Another',
                icon: Icons.upload_file_rounded,
                onTap: () => setState(() {
                  _step = _UploadStep.idle;
                  _processedCount = 0;
                  _totalCount = 0;
                }),
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
          const Text('Import Failed',
              style: TextStyle(color: _G.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(_errorMsg ?? 'Unknown error',
              style: const TextStyle(color: _G.textSecondary, fontSize: 12, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          _PillButton(
            label: 'Try Again',
            icon: Icons.refresh_rounded,
            onTap: () => setState(() { _step = _UploadStep.idle; _errorMsg = null; }),
            color: _G.primary,
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// Shared small widgets
// =============================================================================
class _PillButton extends StatelessWidget {
  final String   label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color    color;
  final bool     outlined;

  const _PillButton({
    required this.label, required this.icon,
    required this.onTap, required this.color,
    this.outlined = false,
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
