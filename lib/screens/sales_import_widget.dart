import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:excel/excel.dart' hide Border;
import '../services/sales_file_picker.dart';

// Storage path where the historical Excel file lives.
const kSalesExcelStoragePath = 'sales_records/historical_sales.xlsx';

const _kExpectedHeaders = [
  'invoice_number', 'sale_date',    'order_date',     'customer_name',
  'product_name',   'type',         'size',            'quantity',
  'unit_price',     'item_total',   'total_amount',    'order_status',
  'payment_status', 'source',       'is_historical',
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
              'Upload Excel',
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
// Show the upload bottom sheet
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
// Upload Sheet — picks file and uploads directly to Firebase Storage
// =============================================================================
enum _UploadStep { idle, uploading, done, error }

class _SalesImportSheet extends StatefulWidget {
  const _SalesImportSheet();
  @override
  State<_SalesImportSheet> createState() => _SalesImportSheetState();
}

class _SalesImportSheetState extends State<_SalesImportSheet> {
  _UploadStep _step     = _UploadStep.idle;
  String?     _fileName;
  String?     _errorMsg;
  double?     _progress; // null = indeterminate

  Future<void> _pickAndUpload() async {
    final picked = await pickSalesFile();
    if (picked == null) return;

    final (fileName, bytes) = picked;
    setState(() {
      _step     = _UploadStep.uploading;
      _fileName = fileName;
      _errorMsg = null;
      _progress = null;
    });

    try {
      final ref  = FirebaseStorage.instance.ref(kSalesExcelStoragePath);
      final task = ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          customMetadata: {'originalName': fileName},
        ),
      );

      task.snapshotEvents.listen((snap) {
        if (!mounted) return;
        setState(() {
          _progress = snap.totalBytes > 0
              ? snap.bytesTransferred / snap.totalBytes
              : null;
        });
      });

      await task;
      if (mounted) setState(() => _step = _UploadStep.done);
    } catch (e) {
      if (mounted) setState(() {
        _step     = _UploadStep.error;
        _errorMsg = e.toString();
      });
    }
  }

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
              Text('Upload Sales Excel',
                  style: TextStyle(color: _G.textPrimary, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              SizedBox(height: 1),
              Text('File is stored in cloud and read on demand — no row limit',
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
      case _UploadStep.idle:      return _buildIdle();
      case _UploadStep.uploading: return _buildUploading();
      case _UploadStep.done:      return _buildDone();
      case _UploadStep.error:     return _buildError();
    }
  }

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
        const Text('No file uploaded',
            style: TextStyle(color: _G.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Choose your .xlsx file and it will be stored in the cloud.\nView it anytime under the "Excel File" tab — no row limit.',
            style: TextStyle(color: _G.textMuted, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 28),
        _PillButton(
          label: 'Choose & Upload',
          icon: Icons.cloud_upload_rounded,
          onTap: _pickAndUpload,
          color: _G.primary,
        ),
        const SizedBox(height: 16),
        _buildHint(),
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
            'Uploading replaces any previously uploaded file.\nRequired columns: invoice_number · sale_date · customer_name · product_name · total_amount',
            style: TextStyle(color: _G.amber, fontSize: 11, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _buildUploading() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 56, height: 56,
            child: CircularProgressIndicator(
              value: _progress,
              strokeWidth: 3,
              color: _G.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Uploading${_fileName != null ? ' $_fileName' : ''}…',
            style: const TextStyle(color: _G.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (_progress != null) ...[
            const SizedBox(height: 10),
            Text(
              '${(_progress! * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: _G.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );

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
          const Text('Upload Complete!',
              style: TextStyle(color: _G.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Your Excel file is saved in the cloud.\nSwitch to the "Excel File" tab to browse and search all records.',
              style: TextStyle(color: _G.textSecondary, fontSize: 12, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PillButton(
                label: 'Upload Another',
                icon: Icons.upload_file_rounded,
                onTap: () => setState(() { _step = _UploadStep.idle; }),
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
          const Text('Upload Failed',
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
// Excel Viewer — downloads from Storage and shows paginated records
// =============================================================================
class _ExcelRecord {
  final String invoiceNumber;
  final String saleDate;
  final String customerName;
  final String productName;
  final double totalAmount;
  final String orderStatus;

  const _ExcelRecord({
    required this.invoiceNumber,
    required this.saleDate,
    required this.customerName,
    required this.productName,
    required this.totalAmount,
    required this.orderStatus,
  });
}

enum _ViewState { loading, loaded, empty, error }

class SalesExcelViewer extends StatefulWidget {
  const SalesExcelViewer({super.key});

  @override
  State<SalesExcelViewer> createState() => _SalesExcelViewerState();
}

class _SalesExcelViewerState extends State<SalesExcelViewer> {
  _ViewState           _state   = _ViewState.loading;
  List<_ExcelRecord>   _allRows = [];
  String               _search  = '';
  int                  _page    = 0;
  String?              _errorMsg;
  String?              _uploadedName;
  final _searchCtrl = TextEditingController();

  static const int _perPage = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _state = _ViewState.loading; _allRows = []; _page = 0; });

    try {
      final ref = FirebaseStorage.instance.ref(kSalesExcelStoragePath);

      // Check if file exists
      FullMetadata? meta;
      try { meta = await ref.getMetadata(); } catch (_) {}
      if (meta == null) {
        setState(() => _state = _ViewState.empty);
        return;
      }

      _uploadedName = meta.customMetadata?['originalName'];

      final bytes = await ref.getData(50 * 1024 * 1024); // 50 MB max
      if (bytes == null || bytes.isEmpty) {
        setState(() => _state = _ViewState.empty);
        return;
      }

      final rows = _parseBytes(bytes);
      setState(() {
        _allRows = rows;
        _state   = rows.isEmpty ? _ViewState.empty : _ViewState.loaded;
      });
    } catch (e) {
      setState(() {
        _state    = _ViewState.error;
        _errorMsg = e.toString();
      });
    }
  }

  // ── Parse Excel bytes → list of display records ────────────────────────────
  List<_ExcelRecord> _parseBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]!;
    final rows  = sheet.rows;
    if (rows.isEmpty) return [];

    // Detect header row (check first 5 rows)
    int headerIdx = 0;
    Map<String, int> colMap = {};
    for (int r = 0; r < rows.length.clamp(0, 5); r++) {
      final map = _buildColMap(rows[r]);
      if (map.length >= 3) { headerIdx = r; colMap = map; break; }
    }
    if (colMap.isEmpty) return [];

    final result = <_ExcelRecord>[];
    for (int r = headerIdx + 1; r < rows.length; r++) {
      try {
        final row = rows[r];
        final inv = _cs(row, colMap['invoice_number']);
        if (inv.isEmpty) continue;
        result.add(_ExcelRecord(
          invoiceNumber: inv,
          saleDate     : _cs(row, colMap['sale_date']),
          customerName : _cs(row, colMap['customer_name']),
          productName  : _cs(row, colMap['product_name']),
          totalAmount  : _cn(row, colMap['total_amount']),
          orderStatus  : _cs(row, colMap['order_status']),
        ));
      } catch (_) {
        // skip rows that can't be parsed
      }
    }
    return result;
  }

  Map<String, int> _buildColMap(List<Data?> row) {
    final map = <String, int>{};
    for (int i = 0; i < row.length; i++) {
      final val = _cs(row, i).toLowerCase().replaceAll(' ', '_');
      if (_kExpectedHeaders.contains(val)) map[val] = i;
    }
    return map;
  }

  static String _cs(List<Data?> row, int? idx) {
    if (idx == null || idx >= row.length) return '';
    final cell = row[idx];
    if (cell == null) return '';
    if (cell.value is IntCellValue)    return (cell.value as IntCellValue).value.toString();
    if (cell.value is DoubleCellValue) return (cell.value as DoubleCellValue).value.toString();
    if (cell.value is DateCellValue)   return (cell.value as DateCellValue).asDateTimeLocal().toIso8601String();
    final raw   = cell.value?.toString() ?? '';
    final match = RegExp(r'«(.*?)»').firstMatch(raw);
    return (match?.group(1) ?? raw).trim();
  }

  static double _cn(List<Data?> row, int? idx) {
    if (idx == null || idx >= row.length) return 0;
    final cell = row[idx];
    if (cell == null) return 0;
    if (cell.value is IntCellValue)    return (cell.value as IntCellValue).value.toDouble();
    if (cell.value is DoubleCellValue) return (cell.value as DoubleCellValue).value;
    return double.tryParse(_cs(row, idx).replaceAll(',', '')) ?? 0;
  }

  // ── Filtered + paginated view ──────────────────────────────────────────────
  List<_ExcelRecord> get _filtered {
    if (_search.isEmpty) return _allRows;
    final q = _search.toLowerCase();
    return _allRows.where((r) =>
        r.invoiceNumber.toLowerCase().contains(q) ||
        r.customerName.toLowerCase().contains(q)  ||
        r.productName.toLowerCase().contains(q),
    ).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _ViewState.loading: return _buildLoading();
      case _ViewState.empty:   return _buildEmpty();
      case _ViewState.error:   return _buildError();
      case _ViewState.loaded:  return _buildTable();
    }
  }

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(strokeWidth: 2.5, color: _G.primary),
        SizedBox(height: 16),
        Text('Loading Excel file…', style: TextStyle(color: _G.textMuted, fontSize: 12)),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            ),
            child: const Icon(Icons.table_chart_outlined, size: 34, color: _G.textMuted),
          ),
          const SizedBox(height: 18),
          const Text('No Excel file uploaded yet',
              style: TextStyle(color: _G.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Use the "Upload Excel" button to upload your\nhistorical sales file.',
            style: TextStyle(color: _G.textMuted, fontSize: 12, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

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
            child: const Icon(Icons.error_outline_rounded, color: _G.red, size: 34),
          ),
          const SizedBox(height: 18),
          const Text('Could not read file',
              style: TextStyle(color: _G.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_errorMsg ?? 'Unknown error',
              style: const TextStyle(color: _G.textSecondary, fontSize: 11, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          _PillButton(label: 'Retry', icon: Icons.refresh_rounded, onTap: _load, color: _G.primary),
        ],
      ),
    ),
  );

  Widget _buildTable() {
    final filtered = _filtered;
    final totalPages = (filtered.length / _perPage).ceil().clamp(1, 999999);
    final pageRows   = filtered.skip(_page * _perPage).take(_perPage).toList();

    return Column(
      children: [
        // ── toolbar ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              // file badge
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
                    const Icon(Icons.insert_drive_file_outlined, size: 12, color: _G.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      _uploadedName ?? 'historical_sales.xlsx',
                      style: const TextStyle(color: _G.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
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
                child: Text('${_allRows.length} rows',
                    style: const TextStyle(color: _G.green, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _load,
                child: const Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 13, color: _G.textMuted),
                    SizedBox(width: 4),
                    Text('Reload', style: TextStyle(color: _G.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── search ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [_G.shadow],
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search_rounded, size: 16, color: _G.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 12, color: _G.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Search invoice, customer, product…',
                      hintStyle: TextStyle(fontSize: 12, color: _G.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setState(() { _search = v; _page = 0; }),
                  ),
                ),
                if (_search.isNotEmpty)
                  GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() { _search = ''; _page = 0; }); },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.close_rounded, size: 14, color: _G.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── table header ───────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 2, child: _TH('Invoice')),
              Expanded(flex: 3, child: _TH('Customer')),
              Expanded(flex: 2, child: _TH('Date')),
              Expanded(flex: 2, child: _TH('Product')),
              SizedBox(width: 80, child: _TH('Total', right: true)),
              SizedBox(width: 74, child: _TH('Status', center: true)),
            ],
          ),
        ),

        // ── rows ───────────────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            itemCount: pageRows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 3),
            itemBuilder: (_, i) => _buildRow(pageRows[i]),
          ),
        ),

        // ── pagination ─────────────────────────────────────────────────────
        _buildPager(filtered.length, totalPages),
      ],
    );
  }

  Widget _buildRow(_ExcelRecord r) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        Expanded(flex: 2, child: _Cell(r.invoiceNumber, mono: true)),
        Expanded(flex: 3, child: _Cell(r.customerName)),
        Expanded(flex: 2, child: _Cell(r.saleDate.length > 10 ? r.saleDate.substring(0, 10) : r.saleDate)),
        Expanded(flex: 2, child: _Cell(r.productName, muted: true)),
        SizedBox(
          width: 80,
          child: Text(
            r.totalAmount > 0 ? '₱${r.totalAmount.toStringAsFixed(2)}' : '—',
            style: const TextStyle(color: _G.amber, fontSize: 11, fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(width: 74, child: _StatusPill(r.orderStatus)),
      ],
    ),
  );

  Widget _buildPager(int total, int totalPages) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _search.isNotEmpty
              ? '$total result${total == 1 ? '' : 's'}'
              : '${_allRows.length} total rows',
          style: const TextStyle(color: _G.textMuted, fontSize: 11),
        ),
        Row(
          children: [
            _PageBtn(
              icon: Icons.chevron_left_rounded,
              enabled: _page > 0,
              onTap: () => setState(() => _page--),
            ),
            const SizedBox(width: 8),
            Text(
              'Page ${_page + 1} / $totalPages',
              style: const TextStyle(color: _G.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            _PageBtn(
              icon: Icons.chevron_right_rounded,
              enabled: _page < totalPages - 1,
              onTap: () => setState(() => _page++),
            ),
          ],
        ),
      ],
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

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final bool     enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: AnimatedOpacity(
      opacity: enabled ? 1 : 0.3,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 16, color: _G.textSecondary),
      ),
    ),
  );
}
