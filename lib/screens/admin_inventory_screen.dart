import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_theme.dart';
import 'employee_inventory_forecast_screen.dart';
import '../services/inventory_service.dart';
import '../services/file_utils.dart' as file_utils;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// â”€â”€ Breakpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const double _kTableMinWidth = 628.0;

// â”€â”€ Shared colour constants (same as product management & admin logs) â”€â”€â”€â”€â”€â”€â”€â”€â”€
const Color _amber = Color(0xFFB45309);
const Color _navyBlue = Color(0xFF0F1A2E);

// ── Business constants (kept in sync with invoice_screen.dart so every
//    printed document shares the same letterhead) ──────────────────────────
const _bizName = 'IMPRENTA INC.';
const _bizTagline = 'Professional Printing Services';
const _bizAddr1 = '5th Street Pacita Avenue, Office 1 Rongavilla Building';
const _bizAddr2 = 'San Pedro, Laguna, 4023, Philippines';
const _bizTin = '010-253-357-000';

// â”€â”€ Liquid Glass Design Tokens â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _Glass {
  static const Color surface = Color(0xF8FFFFFF);
  static const Color surfaceMid = Color(0xF0FFFFFF);
  static const Color surfaceThin = Color(0xA0FFFFFF);

  static const Color borderMid = Color(0x70FFFFFF);
  static const Color borderDim = Color(0x30FFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xCC0F172A);
  static const Color textMuted = Color(0x880F172A);

  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFEF4444);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x22000000),
    blurRadius: 32,
    spreadRadius: -4,
    offset: Offset(0, 8),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x10000000),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static BoxDecoration glass({
    double radius = 16,
    bool elevated = false,
    Color? tintBorder,
  }) => BoxDecoration(
    color: surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: tintBorder ?? borderMid, width: 0.9),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  static BoxDecoration solidPill(Color color, {bool glow = false}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: glow ? 0.38 : 0.22),
            blurRadius: glow ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// â”€â”€ Shared blur filter â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final _blurFilter = ImageFilter.blur(sigmaX: 14, sigmaY: 14);

// â”€â”€ Sub-tab enum â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
enum _InventoryTab { inventory, forecast }

// =============================================================================
// Root screen
// =============================================================================
class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});
  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  _InventoryTab _activeTab = _InventoryTab.inventory;
  String? _statusFilter;
  bool _seeding = false;
  bool _seedingHistory = false;
  bool _clearingHistory = false;
  bool _syncingAvailability = false;

  @override
  void initState() {
    super.initState();
    _syncRawMaterials();
  }

  // One-time migration: replaces all raw material documents with the new
  // authoritative list of 33 materials.  Idempotent â€” checks RM-001 name
  // before running, so it silently skips after the first successful run.
  Future<void> _syncRawMaterials() async {
    try {
      final col = FirebaseFirestore.instance.collection('RawMaterials');
      final check = await col.doc('RM-001').get();
      if (check.exists &&
          check.data()?['material_name'] == 'Vinyl Matte Sticker') {
        return; // already migrated
      }

      // Full replacement in batches of 400 (Firestore cap is 500 per batch).
      const batchSize = 400;
      for (int start = 0;
      start < _kNewMaterials.length;
      start += batchSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = _kNewMaterials.sublist(
            start,
            (start + batchSize).clamp(0, _kNewMaterials.length));
        for (final mat in chunk) {
          batch.set(col.doc(mat['material_id'] as String), {
            ...mat,
            'last_updated': null,
            'last_updated_by': '',
            'last_updated_by_uid': '',
          });
        }
        await batch.commit();
      }

      // Delete any old RM-XXX documents not in the new list.
      final newIds = _kNewMaterials.map((m) => m['material_id']).toSet();
      final allSnap = await col.get();
      final toDelete = allSnap.docs
          .where((d) => !newIds.contains(d.id))
          .toList();
      if (toDelete.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final d in toDelete) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    } catch (_) {
      // Silent â€” retries on next open until it succeeds.
    }
  }

  // Counts derived from the live stream â€” kept here so the header can use them.
  Map<String, int> _counts = {};
  int _total = 0;

  static const _statuses = [
    'In Stock',
    'Low Stock',
    'Critical',
    'Out of Stock',
  ];

  String _computeStatus(num current, num restock) {
    if (current <= 0) return 'Out of Stock';
    if (current <= restock * 0.5) return 'Critical';
    if (current <= restock) return 'Low Stock';
    return 'In Stock';
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'In Stock':
        return _Glass.accentEmerald;
      case 'Low Stock':
        return _amber;
      case 'Critical':
        return const Color(0xFFDC2626);
      default:
        return _Glass.accentRose;
    }
  }

  Future<void> _seedInitialData() async {
    setState(() => _seeding = true);
    try {
      final col = FirebaseFirestore.instance.collection('RawMaterials');

      // Only seed materials that do not already exist â€” never overwrite
      // existing documents so configured dimensions and stock are preserved.
      final existingSnap = await col.get();
      final existingIds = existingSnap.docs.map((d) => d.id).toSet();

      final missing = _kInitialMaterials
          .where((m) => !existingIds.contains(m['material_id'] as String))
          .toList();

      if (missing.isEmpty) {
        if (mounted) _snack('All materials already exist â€” nothing to seed', _Glass.accentEmerald);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final mat in missing) {
        batch.set(col.doc(mat['material_id'] as String), {
          ...mat,
          'current_stock': 0.0,
          'last_updated': null,
          'last_updated_by': '',
          'last_updated_by_uid': '',
        });
      }
      await batch.commit();
      if (mounted) _snack('${missing.length} missing material(s) added', _Glass.accentEmerald);
    } catch (e) {
      if (mounted) _snack('Seed error: $e', _Glass.accentRose);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _snack(String msg, Color bg) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

  // ── Availability sync ─────────────────────────────────────────────────────

  Future<void> _syncAvailability() async {
    setState(() => _syncingAvailability = true);
    try {
      await InventoryService.refreshAllProductAvailability();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product availability synced.'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingAvailability = false);
    }
  }

  // ── Historical data seeder ─────────────────────────────────────────────────

  Future<void> _seedHistoricalData() async {
    setState(() => _seedingHistory = true);
    try {
      final db  = FirebaseFirestore.instance;
      final rng = math.Random(42);
      final now = DateTime.now();
      const numPeriods = 12;

      // Build materialId → first product that uses it (via BOM)
      final prodSnap = await db.collection('Products').get();
      final matProd = <String, _SeedEntry>{};
      for (final doc in prodSnap.docs) {
        final name = (doc.data()['product_name']?.toString() ?? '').trim();
        if (name.isEmpty) continue;
        final bom = (doc.data()['bill_of_materials'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
        for (final b in bom) {
          final mid = b['material_id']?.toString() ?? '';
          if (mid.isEmpty || matProd.containsKey(mid)) continue;
          final qpu = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
          matProd[mid] = _SeedEntry(name, qpu,
              b['for_material_option']?.toString() ?? '');
        }
      }

      if (matProd.isEmpty) {
        _snack(
          'No products with BOM entries found — '
              'add Bill of Materials to products first.',
          _Glass.accentRose,
        );
        return;
      }

      // Delete any existing seed records first
      await _deleteSeedRecords(db);

      // Build all write payloads
      final writes = <({String id, Map<String, dynamic> data})>[];
      for (final e in matProd.entries) {
        final mid  = e.key;
        final prod = e.value;
        final safeId = mid.replaceAll('-', '').toLowerCase();

        for (int p = 0; p < numPeriods; p++) {
          // Sinusoidal season + noise so MAPE is non-trivial
          final seasonal = 1.0 + 0.45 * math.sin(p * math.pi / 6.0);
          final noise    = 0.75 + rng.nextDouble() * 0.50;
          final qty      = (2.5 * seasonal * noise).round().clamp(1, 9);

          // Middle of period p (0 = oldest, 11 = most recent)
          final periodsFromNow = numPeriods - p;
          final saleDate = now.subtract(
            Duration(days: periodsFromNow * 30 - 15),
          );

          final docId = 'hs-$safeId-p${(p + 1).toString().padLeft(2, '0')}';
          writes.add((
          id: docId,
          data: {
            'order_id'       : docId,
            'invoice_number' : 'HIST-${mid.toUpperCase()}-P${p + 1}',
            'customer_name'  : 'Historical Seed',
            'order_total'    : 0.0,
            'sale_amount'    : 0.0,
            'payment_method' : 'seed',
            'payment_type'   : 'full',
            'sale_date'      : Timestamp.fromDate(saleDate),
            'order_status'   : 'completed',
            'payment_status' : 'paid',
            'is_historical'  : true,
            'import_source'  : 'historical_seed',
            'products'       : [
              {
                'name'      : prod.productName,
                'type'      : prod.variant,
                'size'      : '',
                'qty'       : qty,
                'unit_price': 0.0,
                'item_total': 0.0,
              }
            ],
          },
          ));
        }
      }

      // Commit in batches of 400
      const batchSize = 400;
      for (int s = 0; s < writes.length; s += batchSize) {
        final batch = db.batch();
        for (final w in writes.skip(s).take(batchSize)) {
          batch.set(db.collection('Sales_Records').doc(w.id), w.data);
        }
        await batch.commit();
      }

      if (mounted) {
        _snack(
          '${matProd.length} materials × 12 periods seeded — '
              'refresh the Forecast tab to see MAPE.',
          _Glass.accentEmerald,
        );
      }
    } catch (e) {
      if (mounted) _snack('Seed error: $e', _Glass.accentRose);
    } finally {
      if (mounted) setState(() => _seedingHistory = false);
    }
  }

  Future<void> _deleteSeedRecords(FirebaseFirestore db) async {
    while (true) {
      final snap = await db
          .collection('Sales_Records')
          .where('import_source', isEqualTo: 'historical_seed')
          .limit(400)
          .get();
      if (snap.docs.isEmpty) break;
      final batch = db.batch();
      for (final d in snap.docs) batch.delete(d.reference);
      await batch.commit();
    }
  }

  Future<void> _clearHistoricalData() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => AlertDialog(
        backgroundColor: _Glass.surface,
        elevation: 32,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _Glass.borderMid),
        ),
        title: const Text('Clear Seeded History',
            style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        content: const Text(
          'Deletes all auto-seeded records.\n'
              'Real imported or system orders are NOT affected.',
          style: TextStyle(
              color: _Glass.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _Glass.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: _Glass.accentRose),
            child: const Text('Clear',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _clearingHistory = true);
    try {
      await _deleteSeedRecords(FirebaseFirestore.instance);
      if (mounted) _snack('Seeded history cleared', _Glass.accentEmerald);
    } catch (e) {
      if (mounted) _snack('Error: $e', _Glass.accentRose);
    } finally {
      if (mounted) setState(() => _clearingHistory = false);
    }
  }

  void _handleAddMaterial() => showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) =>
        _AddMaterialDialog(onAdded: (msg) => _snack(msg, _Glass.accentEmerald)),
  );

  void _handleEditMaterial(Map<String, dynamic> m) => showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => _EditMaterialDialog(
      data: m,
      onSaved: (msg) => _snack(msg, _Glass.accentEmerald),
    ),
  );

  // ── Print report ────────────────────────────────────────────────────────

  // Opens the "Print Report" dialog. Pulls a fresh snapshot of RawMaterials
  // (rather than reusing the live stream) so the report always reflects the
  // latest stock counts at the moment the Admin opens the dialog.
  Future<void> _handlePrintReport() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('RawMaterials')
          .orderBy('material_id')
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        _snack('No inventory data to print', _Glass.accentRose);
        return;
      }

      final materials = snap.docs.map((d) {
        final data = d.data();
        final current = (data['current_stock'] as num?) ?? 0;
        final restock = (data['restock_level'] as num?) ?? 1;
        return {
          ...data,
          'doc_id': d.id,
          '_status': _computeStatus(current, restock),
        };
      }).toList();

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.25),
        builder: (_) => _PrintReportDialog(
          materials: materials,
          statusColor: _statusColor,
          onGenerate: _generateInventoryReport,
        ),
      );
    } catch (e) {
      if (mounted) _snack('Error loading inventory: $e', _Glass.accentRose);
    }
  }

  // Builds a PDF from the selected materials, then downloads it (web) or
  // hands off to the native share/print sheet (mobile/desktop) — same
  // pattern used by invoice_screen.dart's PDF export.
  Future<void> _generateInventoryReport(
      List<Map<String, dynamic>> selected,
      String scopeLabel,
      ) async {
    if (selected.isEmpty) return;
    try {
      // Sort by material code for a cleaner printed report.
      final rows = [...selected]..sort((a, b) => (a['material_id'] ?? '')
          .toString()
          .compareTo((b['material_id'] ?? '').toString()));

      final bytes = await _buildInventoryReportPdf(rows, scopeLabel);
      final filename =
          'Inventory_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Same web-vs-native branch used by invoice_screen.dart: on web we
      // trigger a browser download, elsewhere we hand off to the native
      // share/print sheet.
      if (kIsWeb) {
        await file_utils.downloadBytes(bytes, 'application/pdf', filename);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      }
    } catch (e) {
      if (mounted) _snack('Print error: $e', _Glass.accentRose);
    }
  }

  // ── Inventory report PDF builder ────────────────────────────────────────
  // Mirrors the letterhead / colour language of invoice_screen.dart's
  // _buildPdf so every document generated by the app looks consistent.
  static Future<Uint8List> _buildInventoryReportPdf(
      List<Map<String, dynamic>> rows,
      String scopeLabel,
      ) async {
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();
    final italic = await PdfGoogleFonts.notoSansItalic();

    final doc = pw.Document();
    final now = DateTime.now();

    String fmtDate(DateTime d) {
      const mo = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${mo[d.month - 1]} ${d.day}, ${d.year}';
    }

    String fmtTime(DateTime d) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final mm = d.minute.toString().padLeft(2, '0');
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '$h:$mm $ampm';
    }

    // ── Colours (mirrors invoice_screen.dart) ────────────────────────────
    const navy = PdfColor.fromInt(0xFF0F1A2E);
    const gold = PdfColor.fromInt(0xFFE8B84B);
    const textDark = PdfColor.fromInt(0xFF0F172A);
    const textMid = PdfColor.fromInt(0xFF475569);
    const textLight = PdfColor.fromInt(0xFF94A3B8);
    const rowAlt = PdfColor.fromInt(0xFFF8FAFC);
    const rowBorder = PdfColor.fromInt(0xFFE2E8F0);
    const accentBg = PdfColor.fromInt(0xFFF0F9FF);

    pw.TextStyle s(pw.Font f, double sz, PdfColor c) =>
        pw.TextStyle(font: f, fontSize: sz, color: c);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (context) {
          // Full letterhead band only on page 1 — later pages get a slim
          // continuation header so the table has more room to breathe.
          if (context.pageNumber == 1) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Header band ──────────────────────────────────────
                pw.Container(
                  width: double.infinity,
                  color: navy,
                  padding: const pw.EdgeInsets.fromLTRB(36, 28, 36, 24),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left — company info
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _bizName,
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 24,
                                color: gold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(_bizTagline, style: s(regular, 9, textLight)),
                            pw.SizedBox(height: 10),
                            pw.Container(
                              height: 1,
                              width: 160,
                              color: const PdfColor.fromInt(0xFF334155),
                            ),
                            pw.SizedBox(height: 10),
                            pw.Text(
                              _bizAddr1,
                              style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1)),
                            ),
                            pw.Text(
                              _bizAddr2,
                              style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1)),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Row(
                              children: [
                                pw.Text('TIN: ', style: s(bold, 8.5, textLight)),
                                pw.Text(
                                  _bizTin,
                                  style: s(regular, 8.5, const PdfColor.fromInt(0xFFCBD5E1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Right — report meta
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'INVENTORY REPORT',
                            style: pw.TextStyle(
                              font: bold,
                              fontSize: 20,
                              color: gold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          _pdfReportMetaRow('Scope', scopeLabel, bold, regular, PdfColors.white),
                          pw.SizedBox(height: 4),
                          _pdfReportMetaRow(
                            'Date Generated',
                            fmtDate(now),
                            bold,
                            regular,
                            const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                          pw.SizedBox(height: 4),
                          _pdfReportMetaRow(
                            'Time',
                            fmtTime(now),
                            bold,
                            regular,
                            const PdfColor.fromInt(0xFFCBD5E1),
                          ),
                          pw.SizedBox(height: 12),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFF14532D),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              '${rows.length} ITEM(S)',
                              style: pw.TextStyle(
                                font: bold,
                                fontSize: 9,
                                color: const PdfColor.fromInt(0xFF86EFAC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Issued-by / scope strip ─────────────────────────────
                pw.Container(
                  width: double.infinity,
                  color: accentBg,
                  padding: const pw.EdgeInsets.fromLTRB(36, 16, 36, 16),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('ISSUED BY', style: s(bold, 7.5, textLight)),
                            pw.SizedBox(height: 5),
                            pw.Text(_bizName, style: s(bold, 11, textDark)),
                            pw.Text(
                              'Raw Materials Inventory — Admin',
                              style: s(regular, 8.5, textMid),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 20),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('REPORT SCOPE', style: s(bold, 7.5, textLight)),
                            pw.SizedBox(height: 5),
                            pw.Text(scopeLabel, style: s(bold, 11, textDark)),
                            pw.Text(
                              '${rows.length} material(s) included',
                              style: s(regular, 8.5, textMid),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            );
          }
          // Slim continuation header for page 2+
          return pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 20, 36, 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(_bizName, style: s(bold, 9, textMid)),
                pw.Text('Inventory Report (cont.)', style: s(italic, 8.5, textLight)),
              ],
            ),
          );
        },
        footer: (context) => pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 10),
          decoration: const pw.BoxDecoration(color: rowAlt),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('$_bizName  ·  TIN: $_bizTin', style: s(bold, 8, textMid)),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: s(regular, 7.5, textLight),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 0, 36, 8),
            child: pw.Text('MATERIALS', style: s(bold, 7.5, textLight)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(36, 0, 36, 24),
            child: pw.Table(
              columnWidths: {
                0: const pw.FixedColumnWidth(58),
                1: const pw.FlexColumnWidth(3.2),
                2: const pw.FlexColumnWidth(2.4),
                3: const pw.FlexColumnWidth(2.0),
                4: const pw.FlexColumnWidth(2.0),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navy),
                  children: [
                    'CODE',
                    'MATERIAL',
                    'AVAILABLE STOCK',
                    'RESTOCK LEVEL',
                    'STATUS',
                  ]
                      .map(
                        (h) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(font: bold, fontSize: 7.5, color: gold),
                      ),
                    ),
                  )
                      .toList(),
                ),
                // Material rows
                ...rows.asMap().entries.map((e) {
                  final idx = e.key;
                  final m = e.value;
                  final id = m['material_id']?.toString() ?? '';
                  final name = m['material_name']?.toString() ?? '';
                  final status = m['_status']?.toString() ?? '';
                  final bg = idx.isEven ? PdfColors.white : rowAlt;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: bg,
                      border: const pw.Border(
                        bottom: pw.BorderSide(color: rowBorder, width: 0.5),
                      ),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(id, style: s(regular, 8, textMid)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(name, style: s(bold, 9, textDark)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(_reportStockText(m), style: s(regular, 8.5, textDark)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(_reportRestockText(m), style: s(regular, 8.5, textMid)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        child: pw.Text(
                          status.isEmpty ? '—' : status,
                          style: s(regular, 8.5, textDark),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await doc.save());
  }

  static pw.Widget _pdfReportMetaRow(
      String label,
      String value,
      pw.Font bold,
      pw.Font regular,
      PdfColor valueColor,
      ) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text(
        '$label  ',
        style: pw.TextStyle(
          font: regular,
          fontSize: 8.5,
          color: const PdfColor.fromInt(0xFF64748B),
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(font: bold, fontSize: 8.5, color: valueColor),
      ),
    ],
  );

  // â”€â”€ build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // â”€â”€ Header card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: _blurFilter,
            child: Container(
              decoration: _Glass.glass(radius: 20, elevated: true),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // â”€â”€ Row 1: icon + title + Add Material + Re-seed â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon badge
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _navyBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title + subtitle
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Inventory Management',
                              style: TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Raw materials â€” stock levels and forecast',
                              style: TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_activeTab == _InventoryTab.inventory) ...[
                        // Print Report pill
                        GestureDetector(
                          onTap: _handlePrintReport,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: _Glass.glass(radius: 99),
                            child: const Icon(
                              Icons.print_outlined,
                              size: 16,
                              color: _Glass.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Add Material primary pill
                        GestureDetector(
                          onTap: _handleAddMaterial,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9),
                            decoration: _Glass.solidPill(_navyBlue, glow: true),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_rounded,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text('Add Material',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                      ],
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(height: 1, color: _Glass.borderDim),
                  const SizedBox(height: 12),

                  // â”€â”€ Row 2: sub-tab pills â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                  Row(
                    children: [
                      _TabPill(
                        label: 'Inventory',
                        icon: Icons.inventory_2_outlined,
                        isActive: _activeTab == _InventoryTab.inventory,
                        onTap: () => setState(
                              () => _activeTab = _InventoryTab.inventory,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TabPill(
                        label: 'Forecast',
                        icon: Icons.trending_up_rounded,
                        isActive: _activeTab == _InventoryTab.forecast,
                        onTap: () =>
                            setState(() => _activeTab = _InventoryTab.forecast),
                      ),
                    ],
                  ),

                  // â”€â”€ Row 3: status filter pills with counts (Inventory tab only)
                  if (_activeTab == _InventoryTab.inventory) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "All" pill shows total count
                          _FilterPill(
                            label: 'All',
                            count: _total > 0 ? _total : null,
                            isActive: _statusFilter == null,
                            dotColor: _Glass.textSecondary,
                            onTap: () => setState(() => _statusFilter = null),
                          ),
                          ..._statuses.map(
                                (s) => _FilterPill(
                              label: s,
                              count: _counts[s],
                              isActive: _statusFilter == s,
                              dotColor: _statusColor(s),
                              onTap: () => setState(
                                    () => _statusFilter = _statusFilter == s
                                    ? null
                                    : s,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // â”€â”€ Body â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Expanded(
          child: _activeTab == _InventoryTab.forecast
              ? const EmployeeInventoryForecastScreen()
              : _buildInventoryContent(),
        ),
      ],
    );
  }

  // â”€â”€ Inventory content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildInventoryContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('RawMaterials')
          .orderBy('material_id')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _navyBlue.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        // Empty state
        if (docs.isEmpty) {
          // Clear counts
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted)
              setState(() {
                _counts = {};
                _total = 0;
              });
          });

          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: _blurFilter,
              child: Container(
                decoration: _Glass.glass(radius: 20, elevated: true),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: _Glass.glass(radius: 22),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 32,
                          color: _Glass.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No inventory data',
                        style: TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Seed the 29 initial raw materials to get started',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _seeding ? null : _seedInitialData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: _Glass.solidPill(_navyBlue, glow: true),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_seeding)
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.add_box_outlined,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 8),
                              const Text(
                                'Seed Initial Materials',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Build materials list with status
        final materials = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final current = (data['current_stock'] as num?) ?? 0;
          final restock = (data['restock_level'] as num?) ?? 1;
          return {
            ...data,
            'doc_id': d.id,
            '_status': _computeStatus(current, restock),
          };
        }).toList();

        // Derive counts and push them into state so the header pills update.
        final newCounts = <String, int>{};
        for (final m in materials) {
          final s = m['_status'] as String;
          newCounts[s] = (newCounts[s] ?? 0) + 1;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              (_counts.toString() != newCounts.toString() ||
                  _total != materials.length)) {
            setState(() {
              _counts = newCounts;
              _total = materials.length;
            });
          }
        });

        final filtered = _statusFilter == null
            ? materials
            : materials.where((m) => m['_status'] == _statusFilter).toList();

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: _blurFilter,
            child: Container(
              decoration: _Glass.glass(radius: 20, elevated: true),
              child: LayoutBuilder(
                builder: (_, c) {
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _statusFilter != null
                            ? 'No "$_statusFilter" materials'
                            : 'No materials found',
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  final tableScrollCtrl = ScrollController();
                  Widget buildTable() => Scrollbar(
                      controller: tableScrollCtrl,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: ListView.builder(
                        controller: tableScrollCtrl,
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Container(
                              decoration: const BoxDecoration(
                                color: Color(0xF2F4F6F8),
                                border: Border(
                                  bottom: BorderSide(color: _Glass.borderDim, width: 0.8),
                                ),
                              ),
                              child: const _TableHeader(),
                            );
                          }
                          final idx = i - 1;
                          return _MaterialRow(
                            data: filtered[idx],
                            isLast: idx == filtered.length - 1,
                            statusColor: _statusColor(
                              filtered[idx]['_status'] as String,
                            ),
                            onQrTap: () => _showQr(context, filtered[idx]),
                            onEditTap: () => _handleEditMaterial(filtered[idx]),
                            onDeleteTap: () => _confirmDelete(context, filtered[idx]),
                          );
                        },
                      ));  // closes Scrollbar child + Scrollbar
                  if (c.maxWidth < _kTableMinWidth) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _kTableMinWidth,
                        child: buildTable(),
                      ),
                    );
                  }
                  return buildTable();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // â”€â”€ Dialogs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _confirmDelete(BuildContext context, Map<String, dynamic> m) {
    final docId = m['doc_id']?.toString() ?? '';
    final name = m['material_name']?.toString() ?? docId;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => AlertDialog(
        backgroundColor: _Glass.surface,
        elevation: 32,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _Glass.accentRose.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _Glass.accentRose.withValues(alpha: 0.30),
                ),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: _Glass.accentRose,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Delete Material',
              style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Delete "$name"? This cannot be undone.',
          style: const TextStyle(
            color: _Glass.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: _Glass.glass(radius: 99),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                    .collection('RawMaterials')
                    .doc(docId)
                    .delete();
                _snack('"$name" deleted', _Glass.accentRose);
              } catch (e) {
                _snack('Error: $e', _Glass.accentRose);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: _Glass.solidPill(_Glass.accentRose),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQr(BuildContext context, Map<String, dynamic> m) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => AlertDialog(
        backgroundColor: _Glass.surface,
        elevation: 32,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        title: Text(
          m['material_name']?.toString() ?? '',
          style: const TextStyle(
            color: _Glass.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 204,
              height: 204,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Glass.borderMid),
                boxShadow: const [_Glass.rowShadow],
              ),
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: m['material_id']?.toString() ?? 'NO-ID',
                version: QrVersions.auto,
                size: 180,
                gapless: false,
                backgroundColor: Colors.white,
                errorStateBuilder: (_, __) => const Center(
                  child: Text(
                    'QR error',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              m['material_id']?.toString() ?? '',
              style: const TextStyle(
                color: _Glass.textSecondary,
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Print and attach to raw material storage',
              style: TextStyle(color: _Glass.textMuted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: _Glass.glass(radius: 99),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _TabPill â€” pill-shaped sub-tab (same style as category pills)
// =============================================================================
class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _TabPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: isActive
          ? _Glass.solidPill(_navyBlue, glow: true)
          : BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _Glass.borderMid, width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isActive ? Colors.white : _Glass.textSecondary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : _Glass.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// _FilterPill â€” status filter pill with inline count
// Design: dot + label run together; count sits in a clean filled chip,
// no border â€” just background tint. Consistent across all states.
// =============================================================================
class _FilterPill extends StatelessWidget {
  final String label;
  final int? count; // null = counts not yet known (hide chip)
  final bool isActive;
  final Color dotColor;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.dotColor,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    // When active: navy pill, white text, semi-white count chip.
    // When inactive: ghost pill, muted text, color-tinted count chip.
    final countBg = isActive
        ? Colors.white.withValues(alpha: 0.18)
        : dotColor.withValues(alpha: 0.13);
    final countFg = isActive ? Colors.white : dotColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.only(left: 10, right: 8, top: 7, bottom: 7),
        decoration: isActive
            ? _Glass.solidPill(_navyBlue, glow: true)
            : BoxDecoration(
          color: _Glass.surfaceThin,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _Glass.borderMid, width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dot â€” always the status color; on active navy bg a thin white
            // halo ring makes it pop against the dark fill.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.5,
                )
                    : null,
              ),
            ),
            const SizedBox(width: 6),

            // Label
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),

            // Count chip â€” borderless, just a tinted background
            if (count != null) ...[
              const SizedBox(width: 7),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: countBg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: countFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _TableHeader
// =============================================================================
class _TableHeader extends StatelessWidget {
  const _TableHeader();

  static const _h = TextStyle(
    color: _Glass.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        SizedBox(width: 74, child: Text('Code', style: _h)),
        Expanded(child: Text('Material', style: _h)),
        SizedBox(
          width: 120,
          child: Text('Available Stock', style: _h, textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 110,
          child: Text('Restock Level', style: _h, textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 90,
          child: Text('Status', style: _h, textAlign: TextAlign.center),
        ),
        SizedBox(width: 96),
      ],
    ),
  );
}

// =============================================================================
// _MaterialRow
// =============================================================================
class _MaterialRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final bool isLast;
  final VoidCallback onQrTap;
  final VoidCallback onEditTap;
  final VoidCallback onDeleteTap;
  const _MaterialRow({
    required this.data,
    required this.statusColor,
    required this.onQrTap,
    required this.onEditTap,
    required this.onDeleteTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final id       = data['material_id']?.toString() ?? '';
    final name     = data['material_name']?.toString() ?? '';
    final status   = data['_status']?.toString() ?? '';
    final current  = (data['current_stock'] as num?)?.toDouble() ?? 0;
    final su       = data['stocking_unit']?.toString() ?? '';
    final unitSqft = (data['unit_size_sqft'] as num?)?.toDouble() ?? 0;
    final baseUom  = data['base_uom']?.toString() ??
        (su == 'Piece' ? 'pc' : 'sqft');
    final restock      = (data['restock_level'] as num?)?.toDouble() ?? 0;
    final subLine      = _buildMatSubLine(data);
    final isStructured = su.isNotEmpty;
    final isPiece      = su == 'Piece';

    String fmtRestock(double val) {
      if (!isStructured) return _fmtNum(val);
      if (isPiece) {
        if (baseUom == 'sheet' && unitSqft > 1) {
          final packs = unitSqft > 0 ? val / unitSqft : 0.0;
          return '${_fmtNum(val)} sh / ${_fmtNum(packs)} pk';
        }
        final label = baseUom == 'sheet' ? 'sh' : 'pcs';
        return '${_fmtNum(val)} $label';
      }
      final stockUnits = unitSqft > 0 ? val / unitSqft : 0.0;
      final label = _stockUnitLabel(su);
      return '${_fmtNum(stockUnits)} ${label}s';
    }

    // Available stock display
    Widget stockCell;
    if (!isStructured) {
      stockCell = Text(
        _fmtNum(current),
        style: const TextStyle(color: _Glass.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      );
    } else if (isPiece) {
      if (baseUom == 'sheet' && unitSqft > 1) {
        final packs = unitSqft > 0 ? current / unitSqft : 0.0;
        stockCell = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_fmtNum(current)} sheets',
                style: const TextStyle(color: _Glass.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            Text('${_fmtNum(packs)} packs',
                style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                textAlign: TextAlign.center),
          ],
        );
      } else {
        final label = baseUom == 'sheet' ? 'sheets' : 'pcs';
        stockCell = Text(
          '${_fmtNum(current)} $label',
          style: const TextStyle(color: _Glass.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        );
      }
    } else {
      final stockUnits = unitSqft > 0 ? current / unitSqft : 0.0;
      final label = _stockUnitLabel(su);
      stockCell = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${_fmtNum(current)} $baseUom',
            style: const TextStyle(color: _Glass.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          Text(
            '${_fmtNum(stockUnits)} ${label}s',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _Glass.borderDim, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Code
          SizedBox(
            width: 74,
            child: Text(
              id,
              style: const TextStyle(
                color: _Glass.textMuted,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Name + sub-line
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subLine.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subLine,
                    style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          // Available stock
          SizedBox(width: 120, child: Center(child: stockCell)),
          // Restock level
          SizedBox(
            width: 110,
            child: Center(
              child: Text(
                restock > 0 ? fmtRestock(restock) : '—',
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Status badge
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _IconAction(icon: Icons.qr_code_rounded,       color: _navyBlue,          onTap: onQrTap),
                const SizedBox(width: 4),
                _IconAction(icon: Icons.edit_outlined,          color: _amber,             onTap: onEditTap),
                const SizedBox(width: 4),
                _IconAction(icon: Icons.delete_outline_rounded, color: _Glass.accentRose,  onTap: onDeleteTap),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == _navyBlue ? 1.0 : 0.10),
        shape: BoxShape.circle,
        border: Border.all(
          color: color == _navyBlue
              ? Colors.white.withValues(alpha: 0.20)
              : color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Icon(
        icon,
        color: color == _navyBlue ? Colors.white : color,
        size: 13,
      ),
    ),
  );
}

// =============================================================================
// Print Report Dialog
// =============================================================================
enum _ReportMode { manual, filter }

class _PrintReportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final Color Function(String) statusColor;
  final Future<void> Function(
      List<Map<String, dynamic>> selected,
      String scopeLabel,
      ) onGenerate;

  const _PrintReportDialog({
    required this.materials,
    required this.statusColor,
    required this.onGenerate,
  });

  @override
  State<_PrintReportDialog> createState() => _PrintReportDialogState();
}

class _PrintReportDialogState extends State<_PrintReportDialog> {
  _ReportMode _mode = _ReportMode.manual;
  final Set<String> _selectedIds = {};
  final Set<String> _selectedStatuses = {};
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _generating = false;

  // Internal status values (must match _computeStatus) paired with the
  // Admin-facing labels requested for the filter list.
  static const _filterStatuses = <String, String>{
    'Low Stock': 'Low Stock',
    'Critical': 'Critical Stock',
    'Out of Stock': 'Out of Stock',
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleManualList {
    if (_search.isEmpty) return widget.materials;
    final q = _search.toLowerCase();
    return widget.materials.where((m) {
      final name = (m['material_name']?.toString() ?? '').toLowerCase();
      final id = (m['material_id']?.toString() ?? '').toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _selectedMaterials {
    if (_mode == _ReportMode.manual) {
      return widget.materials
          .where((m) => _selectedIds.contains(m['doc_id']?.toString()))
          .toList();
    }
    return widget.materials
        .where((m) => _selectedStatuses.contains(m['_status']?.toString()))
        .toList();
  }

  String get _scopeLabel {
    if (_mode == _ReportMode.manual) {
      return 'Manually Selected (${_selectedIds.length} item(s))';
    }
    if (_selectedStatuses.isEmpty) return 'No filter selected';
    return _selectedStatuses
        .map((s) => _filterStatuses[s] ?? s)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedMaterials.length;
    return AlertDialog(
      backgroundColor: _Glass.surface,
      elevation: 32,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      insetPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _navyBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _navyBlue.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.print_outlined, color: _navyBlue, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Print Inventory Report',
              style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Mode toggle ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Select Materials',
                    icon: Icons.checklist_rounded,
                    isActive: _mode == _ReportMode.manual,
                    onTap: () => setState(() => _mode = _ReportMode.manual),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    label: 'Filter by Status',
                    icon: Icons.filter_alt_outlined,
                    isActive: _mode == _ReportMode.filter,
                    onTap: () => setState(() => _mode = _ReportMode.filter),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Manual selection mode ───────────────────────────────────
            if (_mode == _ReportMode.manual) ...[
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 13, color: _Glass.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search materials…',
                  hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: _Glass.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: _Glass.surfaceThin,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _Glass.borderDim),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _Glass.borderDim),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _navyBlue),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '$selectedCount selected',
                    style: const TextStyle(
                      color: _Glass.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedIds.addAll(
                        _visibleManualList.map((m) => m['doc_id'].toString()))),
                    child: const Text(
                      'Select All',
                      style: TextStyle(
                          color: _navyBlue, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _selectedIds.clear()),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                          color: _Glass.accentRose,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: _Glass.borderDim),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _visibleManualList.isEmpty
                    ? const Center(
                  child: Text('No matches',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 12)),
                )
                    : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _visibleManualList.length,
                  itemBuilder: (_, i) {
                    final m = _visibleManualList[i];
                    final id = m['doc_id'].toString();
                    final status = m['_status']?.toString() ?? '';
                    final checked = _selectedIds.contains(id);
                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      activeColor: _navyBlue,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectedIds.add(id);
                        } else {
                          _selectedIds.remove(id);
                        }
                      }),
                      title: Text(
                        m['material_name']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _Glass.textPrimary),
                      ),
                      subtitle: Text(
                        '${m['material_id'] ?? ''} · $status',
                        style: const TextStyle(
                            fontSize: 10.5, color: _Glass.textMuted),
                      ),
                    );
                  },
                ),
              ),
            ]

            // ── Status-filter mode ──────────────────────────────────────
            else ...[
              const Text(
                'Include materials matching:',
                style: TextStyle(
                    color: _Glass.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ..._filterStatuses.entries.map((entry) {
                final statusKey = entry.key;
                final displayLabel = entry.value;
                final matchCount = widget.materials
                    .where((m) => m['_status'] == statusKey)
                    .length;
                final checked = _selectedStatuses.contains(statusKey);
                return CheckboxListTile(
                  dense: true,
                  value: checked,
                  activeColor: widget.statusColor(statusKey),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedStatuses.add(statusKey);
                    } else {
                      _selectedStatuses.remove(statusKey);
                    }
                  }),
                  title: Text(
                    displayLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _Glass.textPrimary),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.statusColor(statusKey).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$matchCount',
                      style: TextStyle(
                          color: widget.statusColor(statusKey),
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Text(
                '$selectedCount material(s) match the selected filter(s)',
                style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
      actions: [
        GestureDetector(
          onTap: _generating ? null : () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: _Glass.glass(radius: 99),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
        GestureDetector(
          onTap: (_generating || selectedCount == 0)
              ? null
              : () async {
            setState(() => _generating = true);
            final selected = _selectedMaterials;
            final label = _scopeLabel;
            Navigator.pop(context);
            await widget.onGenerate(selected, label);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: _Glass.solidPill(
              selectedCount == 0 ? _Glass.textMuted : _navyBlue,
              glow: selectedCount > 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Generate Report ($selectedCount)',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? _navyBlue : _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? _navyBlue : _Glass.borderDim),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: isActive ? Colors.white : _Glass.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : _Glass.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// Add Material Dialog
// =============================================================================
class _AddMaterialDialog extends StatefulWidget {
  final void Function(String) onAdded;
  const _AddMaterialDialog({required this.onAdded});
  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final _formKey   = GlobalKey<FormState>();
  final _idCtrl    = TextEditingController();
  final _nameCtrl  = TextEditingController();
  String _su       = 'Roll'; // stocking unit
  final _wCtrl     = TextEditingController();
  String _wUnit    = 'ft';
  final _lCtrl     = TextEditingController();
  String _lUnit    = 'm';
  String _baseUom  = 'pc'; // 'pc' | 'sheet' â€” only relevant for Piece type
  final _packSizeCtrl = TextEditingController(text: '1'); // sheets per pack
  final _restockCtrl = TextEditingController(text: '5');
  final _stockCtrl   = TextEditingController(text: '0');
  bool _saving = false;

  bool get _isPiece  => _su == 'Piece';
  bool get _isPack   => _isPiece && _baseUom == 'sheet';

  double get _unitSizeSqft {
    if (_isPiece) {
      if (_isPack) return double.tryParse(_packSizeCtrl.text) ?? 1.0;
      return 1.0;
    }
    final wv = double.tryParse(_wCtrl.text) ?? 0;
    final lv = double.tryParse(_lCtrl.text) ?? 0;
    return _calcUnitSqft(wv, _wUnit, lv, _lUnit);
  }

  String get _unitSizeDisplay {
    if (_isPack) return '${_fmtNum(_unitSizeSqft)} sheets / pack';
    if (_isPiece) return '1 pc / pc';
    final s = _unitSizeSqft;
    return '${_fmtNum(s)} sqft / ${_stockUnitLabel(_su)}';
  }

  @override
  void initState() {
    super.initState();
    _autoId();
    _wCtrl.addListener(() => setState(() {}));
    _lCtrl.addListener(() => setState(() {}));
  }

  Future<void> _autoId() async {
    final snap = await FirebaseFirestore.instance
        .collection('RawMaterials')
        .orderBy('material_id')
        .get();
    int maxNum = 0;
    for (final d in snap.docs) {
      final id = d.data()['material_id']?.toString() ?? '';
      if (id.startsWith('RM-')) {
        final n = int.tryParse(id.substring(3)) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    if (mounted) _idCtrl.text = 'RM-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  @override
  void dispose() {
    _idCtrl.dispose(); _nameCtrl.dispose();
    _wCtrl.dispose();  _lCtrl.dispose();
    _packSizeCtrl.dispose();
    _restockCtrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _isPack ? 'sheets' : (_isPiece ? 'pcs' : '${_stockUnitLabel(_su)}s');
    return Dialog(
      backgroundColor: _Glass.surface,
      elevation: 32,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // â”€â”€ Title bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: _navyBlue, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add_box_outlined, color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Add Raw Material',
                          style: TextStyle(color: _Glass.textPrimary, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: _Glass.surfaceThin, shape: BoxShape.circle,
                            border: Border.all(color: _Glass.borderMid, width: 0.9)),
                        child: const Icon(Icons.close_rounded, color: _Glass.textMuted, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: _Glass.borderMid, height: 16, thickness: 0.8),

              // â”€â”€ Form â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ID
                      _SectionLabel('Material ID'),
                      const SizedBox(height: 6),
                      _GlassField(controller: _idCtrl, hint: 'e.g. RM-030', icon: Icons.tag_rounded,
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 12),

                      // Name
                      _SectionLabel('Material Name *'),
                      const SizedBox(height: 6),
                      _GlassField(controller: _nameCtrl, hint: 'e.g. Tarpaulin 13oz', icon: Icons.inventory_2_outlined,
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 12),

                      // Stocking unit
                      _SectionLabel('Stocking Unit *'),
                      const SizedBox(height: 6),
                      _GlassDropdown<String>(
                        value: _su,
                        items: const ['Roll', 'Sheet', 'Piece'],
                        onChanged: (v) => setState(() { _su = v!; _baseUom = 'pc'; }),
                      ),
                      const SizedBox(height: 12),

                      // Piece sub-type (base unit + optional pack size)
                      if (_isPiece) ...[
                        _SectionLabel('Base Unit'),
                        const SizedBox(height: 6),
                        _GlassDropdown<String>(
                          value: _baseUom,
                          items: const ['pc', 'sheet'],
                          onChanged: (v) => setState(() => _baseUom = v!),
                        ),
                        if (_isPack) ...[
                          const SizedBox(height: 12),
                          _SectionLabel('Sheets per pack *'),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 160,
                            child: _GlassField(
                              controller: _packSizeCtrl,
                              hint: 'e.g. 100',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.trim().isEmpty == true) return 'Required';
                                if (int.tryParse(v!.trim()) == null) return 'Whole number';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'â†’ ${_fmtNum(_unitSizeSqft)} sheets per pack',
                            style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],

                      // Width + Length (only for Roll/Sheet)
                      if (!_isPiece) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel('Width *'),
                                  const SizedBox(height: 6),
                                  _DimensionRow(ctrl: _wCtrl, unit: _wUnit,
                                      onUnitChanged: (u) => setState(() => _wUnit = u)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel('Length *'),
                                  const SizedBox(height: 6),
                                  _DimensionRow(ctrl: _lCtrl, unit: _lUnit,
                                      onUnitChanged: (u) => setState(() => _lUnit = u)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Computed unit size chip
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _navyBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _navyBlue.withValues(alpha: 0.15), width: 0.9),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined, size: 14, color: _Glass.textMuted),
                              const SizedBox(width: 7),
                              Text('Unit size: ', style: const TextStyle(color: _Glass.textMuted, fontSize: 12)),
                              Text(_unitSizeDisplay,
                                  style: const TextStyle(color: _Glass.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Restock At + Initial Stock
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Restock At ($unitLabel)'),
                                const SizedBox(height: 6),
                                _GlassField(
                                  controller: _restockCtrl, hint: '5',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    if (v?.trim().isEmpty == true) return 'Required';
                                    if (double.tryParse(v!.trim()) == null) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Initial Stock ($unitLabel)'),
                                const SizedBox(height: 6),
                                _GlassField(
                                  controller: _stockCtrl, hint: '0',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (v) {
                                    if (v?.trim().isEmpty == true) return 'Required';
                                    if (double.tryParse(v!.trim()) == null) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // â”€â”€ Action bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _Glass.borderMid, width: 0.9))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: _Glass.glass(radius: 99),
                        child: const Text('Cancel',
                            style: TextStyle(color: _Glass.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: _Glass.solidPill(_navyBlue, glow: true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saving)
                              const SizedBox(width: 13, height: 13,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            else
                              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            const Text('Add Material',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isPiece) {
      final wv = double.tryParse(_wCtrl.text) ?? 0;
      final lv = double.tryParse(_lCtrl.text) ?? 0;
      if (wv <= 0 || lv <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Width and Length must be greater than 0'),
          backgroundColor: _Glass.accentRose,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final id   = _idCtrl.text.trim();
      final name = _nameCtrl.text.trim();
      final stockInput  = double.tryParse(_stockCtrl.text) ?? 0.0;
      final restockInput = double.tryParse(_restockCtrl.text) ?? 5.0;
      final sqft = _unitSizeSqft;
      final currentBase = _isPiece ? stockInput : stockInput * sqft;
      final restockBase  = _isPiece ? restockInput : restockInput * sqft;
      final wv = _isPiece ? 0.0 : (double.tryParse(_wCtrl.text) ?? 0.0);
      final lv = _isPiece ? 0.0 : (double.tryParse(_lCtrl.text) ?? 0.0);
      String unitDesc;
      if (_isPack) {
        unitDesc = 'Pack (${_fmtNum(sqft)} sheets)';
      } else if (_isPiece) {
        unitDesc = 'Piece';
      } else {
        unitDesc = '$_su (${_fmtNum(wv)}$_wUnit × ${_fmtNum(lv)}$_lUnit)';
      }
      final effectiveBaseUom = _isPiece ? _baseUom : 'sqft';

      await FirebaseFirestore.instance.collection('RawMaterials').doc(id).set({
        'material_id': id,
        'material_name': name,
        'stocking_unit': _su,
        'base_uom': effectiveBaseUom,
        'width_value':  _isPiece ? null : wv,
        'width_unit':   _isPiece ? null : _wUnit,
        'length_value': _isPiece ? null : lv,
        'length_unit':  _isPiece ? null : _lUnit,
        'unit_size_sqft': sqft,
        'unit_description': unitDesc,
        'restock_level': restockBase,
        'current_stock': currentBase,
        'last_updated': null,
        'last_updated_by': '',
        'last_updated_by_uid': '',
      });
      nav.pop();
      widget.onAdded('$id added to inventory');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: _Glass.accentRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =============================================================================
// Edit Material Dialog
// =============================================================================
class _EditMaterialDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final void Function(String) onSaved;
  const _EditMaterialDialog({required this.data, required this.onSaved});
  @override
  State<_EditMaterialDialog> createState() => _EditMaterialDialogState();
}

class _EditMaterialDialogState extends State<_EditMaterialDialog> {
  final _formKey  = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String _su;
  late String _baseUom; // 'sqft' | 'pc' | 'sheet'
  late final TextEditingController _wCtrl;
  late String _wUnit;
  late final TextEditingController _lCtrl;
  late String _lUnit;
  late final TextEditingController _packSizeCtrl;
  late final TextEditingController _restockCtrl;
  bool _saving = false;

  bool get _isPiece => _su == 'Piece';
  bool get _isPack  => _isPiece && _baseUom == 'sheet';

  double get _unitSizeSqft {
    if (_isPack) return double.tryParse(_packSizeCtrl.text) ?? 1.0;
    if (_isPiece) return 1.0;
    final wv = double.tryParse(_wCtrl.text) ?? 0;
    final lv = double.tryParse(_lCtrl.text) ?? 0;
    return _calcUnitSqft(wv, _wUnit, lv, _lUnit);
  }

  String get _unitSizeDisplay {
    if (_isPack) return '${_fmtNum(_unitSizeSqft)} sheets / pack';
    if (_isPiece) return '1 pc / pc';
    final s = _unitSizeSqft;
    return '${_fmtNum(s)} sqft / ${_stockUnitLabel(_su)}';
  }

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameCtrl = TextEditingController(text: d['material_name']?.toString() ?? '');
    _su       = d['stocking_unit']?.toString().isNotEmpty == true
        ? d['stocking_unit'] as String : 'Roll';
    _baseUom  = d['base_uom']?.toString().isNotEmpty == true
        ? d['base_uom'] as String
        : (_su == 'Piece' ? 'pc' : 'sqft');
    _wCtrl    = TextEditingController(text: (d['width_value']  as num?)?.toString() ?? '');
    _wUnit    = d['width_unit']?.toString().isNotEmpty  == true ? d['width_unit']  as String : 'ft';
    _lCtrl    = TextEditingController(text: (d['length_value'] as num?)?.toString() ?? '');
    _lUnit    = d['length_unit']?.toString().isNotEmpty == true ? d['length_unit'] as String : 'm';

    final existingUnitSize = (d['unit_size_sqft'] as num?)?.toDouble() ?? 1.0;
    _packSizeCtrl = TextEditingController(
      text: _baseUom == 'sheet' && existingUnitSize > 1
          ? _fmtNum(existingUnitSize)
          : '1',
    );

    // Pre-fill restock in stock units.
    final currentSqft = existingUnitSize;
    final restockBase  = (d['restock_level'] as num?)?.toDouble() ?? 0;
    double restockDisplay;
    if (_su == 'Piece' || currentSqft <= 0) {
      restockDisplay = restockBase;
    } else {
      restockDisplay = restockBase / currentSqft;
    }
    _restockCtrl = TextEditingController(text: _fmtNum(restockDisplay));

    _wCtrl.addListener(() => setState(() {}));
    _lCtrl.addListener(() => setState(() {}));
    _packSizeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _wCtrl.dispose(); _lCtrl.dispose();
    _packSizeCtrl.dispose(); _restockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _isPack ? 'sheets' : (_isPiece ? 'pcs' : '${_stockUnitLabel(_su)}s');
    final docId = widget.data['material_id']?.toString() ?? '';
    return Dialog(
      backgroundColor: _Glass.surface,
      elevation: 32,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _Glass.borderMid, width: 1)),
      child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Edit Raw Material',
                              style: TextStyle(color: _Glass.textPrimary, fontSize: 15,
                                  fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                          Text(docId,
                              style: const TextStyle(color: _Glass.textMuted, fontSize: 11,
                                  fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: _Glass.surfaceThin, shape: BoxShape.circle,
                            border: Border.all(color: _Glass.borderMid, width: 0.9)),
                        child: const Icon(Icons.close_rounded, color: _Glass.textMuted, size: 15),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: _Glass.borderMid, height: 16, thickness: 0.8),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _SectionLabel('Material Name *'),
                      const SizedBox(height: 6),
                      _GlassField(controller: _nameCtrl, hint: 'Material name',
                          icon: Icons.inventory_2_outlined,
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 12),

                      // Stocking unit
                      _SectionLabel('Stocking Unit *'),
                      const SizedBox(height: 6),
                      _GlassDropdown<String>(
                        value: _su,
                        items: const ['Roll', 'Sheet', 'Piece'],
                        onChanged: (v) => setState(() {
                          _su = v!;
                          if (_su != 'Piece') _baseUom = 'sqft';
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Piece sub-type
                      if (_isPiece) ...[
                        _SectionLabel('Base Unit'),
                        const SizedBox(height: 6),
                        _GlassDropdown<String>(
                          value: _baseUom == 'sqft' ? 'pc' : _baseUom,
                          items: const ['pc', 'sheet'],
                          onChanged: (v) => setState(() => _baseUom = v!),
                        ),
                        if (_isPack) ...[
                          const SizedBox(height: 12),
                          _SectionLabel('Sheets per pack *'),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 160,
                            child: _GlassField(
                              controller: _packSizeCtrl,
                              hint: 'e.g. 100',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.trim().isEmpty == true) return 'Required';
                                if (int.tryParse(v!.trim()) == null) return 'Whole number';
                                return null;
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],

                      // Width + Length
                      if (!_isPiece) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel('Width *'),
                                  const SizedBox(height: 6),
                                  _DimensionRow(ctrl: _wCtrl, unit: _wUnit,
                                      onUnitChanged: (u) => setState(() => _wUnit = u)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel('Length *'),
                                  const SizedBox(height: 6),
                                  _DimensionRow(ctrl: _lCtrl, unit: _lUnit,
                                      onUnitChanged: (u) => setState(() => _lUnit = u)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _navyBlue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _navyBlue.withValues(alpha: 0.15), width: 0.9),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calculate_outlined, size: 14, color: _Glass.textMuted),
                              const SizedBox(width: 7),
                              const Text('Unit size: ',
                                  style: TextStyle(color: _Glass.textMuted, fontSize: 12)),
                              Text(_unitSizeDisplay,
                                  style: const TextStyle(color: _Glass.textPrimary, fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Restock level
                      _SectionLabel('Restock At ($unitLabel)'),
                      const SizedBox(height: 6),
                      _GlassField(
                        controller: _restockCtrl, hint: '5',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v?.trim().isEmpty == true) return 'Required';
                          if (double.tryParse(v!.trim()) == null) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Note: current stock level is managed through inventory logs and is not changed here.',
                        style: TextStyle(color: _Glass.textMuted, fontSize: 10, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              // Action bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _Glass.borderMid, width: 0.9))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: _Glass.glass(radius: 99),
                        child: const Text('Cancel',
                            style: TextStyle(color: _Glass.textSecondary, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        decoration: _Glass.solidPill(_amber, glow: true),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_saving)
                              const SizedBox(width: 13, height: 13,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            else
                              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            const Text('Save Changes',
                                style: TextStyle(color: Colors.white, fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isPiece) {
      final wv = double.tryParse(_wCtrl.text) ?? 0;
      final lv = double.tryParse(_lCtrl.text) ?? 0;
      if (wv <= 0 || lv <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Width and Length must be greater than 0'),
          backgroundColor: _Glass.accentRose,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final docId       = widget.data['material_id']?.toString() ?? '';
      final name        = _nameCtrl.text.trim();
      final restockInput = double.tryParse(_restockCtrl.text) ?? 5.0;
      final sqft        = _unitSizeSqft;
      final restockBase  = _isPiece ? restockInput : restockInput * sqft;
      final wv = _isPiece ? 0.0 : (double.tryParse(_wCtrl.text) ?? 0.0);
      final lv = _isPiece ? 0.0 : (double.tryParse(_lCtrl.text) ?? 0.0);
      String unitDesc;
      if (_isPack) {
        unitDesc = 'Pack (${_fmtNum(sqft)} sheets)';
      } else if (_isPiece) {
        unitDesc = 'Piece';
      } else {
        unitDesc = '$_su (${_fmtNum(wv)}$_wUnit × ${_fmtNum(lv)}$_lUnit)';
      }
      final effectiveBaseUom = _isPiece ? (_isPack ? 'sheet' : _baseUom) : 'sqft';

      await FirebaseFirestore.instance.collection('RawMaterials').doc(docId).update({
        'material_name': name,
        'stocking_unit': _su,
        'base_uom': effectiveBaseUom,
        'width_value':  _isPiece ? null : wv,
        'width_unit':   _isPiece ? null : _wUnit,
        'length_value': _isPiece ? null : lv,
        'length_unit':  _isPiece ? null : _lUnit,
        'unit_size_sqft': sqft,
        'unit_description': unitDesc,
        'restock_level': restockBase,
      });
      nav.pop();
      widget.onSaved('$docId updated');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: _Glass.accentRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ));
      if (mounted) setState(() => _saving = false);
    }
  }
}

// =============================================================================
// Shared form helpers
// =============================================================================
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _GlassField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
      prefixIcon: icon != null
          ? Icon(icon, size: 16, color: _Glass.textMuted)
          : null,
      filled: true,
      fillColor: _Glass.surfaceThin,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Glass.borderMid, width: 0.9),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _amber.withValues(alpha: 0.7)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Glass.accentRose),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _Glass.accentRose),
      ),
      errorStyle: const TextStyle(fontSize: 10, color: _Glass.accentRose),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _Glass.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );
}

// Styled dropdown matching _GlassField appearance.
class _GlassDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  const _GlassDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    onChanged: onChanged,
    dropdownColor: _Glass.surface,
    style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      filled: true,
      fillColor: _Glass.surfaceThin,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _Glass.borderMid, width: 0.9)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _amber.withValues(alpha: 0.7))),
    ),
    items: items.map((e) => DropdownMenuItem<T>(
      value: e,
      child: Text(e.toString(), style: const TextStyle(color: _Glass.textPrimary, fontSize: 13)),
    )).toList(),
  );
}

// Number field + unit dropdown side-by-side for width/length inputs.
class _DimensionRow extends StatelessWidget {
  final TextEditingController ctrl;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  const _DimensionRow({required this.ctrl, required this.unit, required this.onUnitChanged});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
          validator: (v) {
            if (v?.trim().isEmpty == true) return 'Required';
            final n = double.tryParse(v!.trim());
            if (n == null || n <= 0) return 'Invalid';
            return null;
          },
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: _Glass.textMuted, fontSize: 13),
            filled: true,
            fillColor: _Glass.surfaceThin,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                borderSide: const BorderSide(color: _Glass.borderMid, width: 0.9)),
            focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                borderSide: BorderSide(color: _amber.withValues(alpha: 0.7))),
            errorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                borderSide: const BorderSide(color: _Glass.accentRose)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10), bottomLeft: Radius.circular(10)),
                borderSide: const BorderSide(color: _Glass.accentRose)),
            errorStyle: const TextStyle(fontSize: 10, color: _Glass.accentRose),
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: _Glass.surfaceThin,
          borderRadius: const BorderRadius.only(
              topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
          border: const Border(
            top:    BorderSide(color: _Glass.borderMid, width: 0.9),
            right:  BorderSide(color: _Glass.borderMid, width: 0.9),
            bottom: BorderSide(color: _Glass.borderMid, width: 0.9),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: unit,
            dropdownColor: _Glass.surface,
            style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
            onChanged: (v) { if (v != null) onUnitChanged(v); },
            items: ['in', 'ft', 'm'].map((u) => DropdownMenuItem(
              value: u,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(u, style: const TextStyle(color: _Glass.textPrimary, fontSize: 13)),
              ),
            )).toList(),
          ),
        ),
      ),
    ],
  );
}


// =============================================================================
// Inventory dimension helpers
// =============================================================================

double _toFeet(double v, String unit) {
  if (unit == 'in') return v / 12.0;
  if (unit == 'm') return v * 3.28084;
  return v; // 'ft'
}

double _calcUnitSqft(double wV, String wU, double lV, String lU) =>
    _toFeet(wV, wU) * _toFeet(lV, lU);

String _fmtNum(double v) {
  if (v == v.truncateToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String _stockUnitLabel(String su) {
  if (su == 'Sheet') return 'sheet';
  if (su == 'Roll') return 'roll';
  return 'pc';
}

// =============================================================================
// Print-report text formatters (mirror the on-screen table formatting in
// _MaterialRow, but as plain text for the PDF cells).
// =============================================================================
String _reportStockText(Map<String, dynamic> data) {
  final current = (data['current_stock'] as num?)?.toDouble() ?? 0;
  final su = data['stocking_unit']?.toString() ?? '';
  final unitSqft = (data['unit_size_sqft'] as num?)?.toDouble() ?? 0;
  final baseUom =
      data['base_uom']?.toString() ?? (su == 'Piece' ? 'pc' : 'sqft');
  final isStructured = su.isNotEmpty;
  final isPiece = su == 'Piece';

  if (!isStructured) return _fmtNum(current);
  if (isPiece) {
    if (baseUom == 'sheet' && unitSqft > 1) {
      final packs = unitSqft > 0 ? current / unitSqft : 0.0;
      return '${_fmtNum(current)} sheets (${_fmtNum(packs)} packs)';
    }
    final label = baseUom == 'sheet' ? 'sheets' : 'pcs';
    return '${_fmtNum(current)} $label';
  }
  final stockUnits = unitSqft > 0 ? current / unitSqft : 0.0;
  final label = _stockUnitLabel(su);
  return '${_fmtNum(current)} $baseUom (${_fmtNum(stockUnits)} ${label}s)';
}

String _reportRestockText(Map<String, dynamic> data) {
  final restock = (data['restock_level'] as num?)?.toDouble() ?? 0;
  if (restock <= 0) return '—';
  final su = data['stocking_unit']?.toString() ?? '';
  final unitSqft = (data['unit_size_sqft'] as num?)?.toDouble() ?? 0;
  final baseUom =
      data['base_uom']?.toString() ?? (su == 'Piece' ? 'pc' : 'sqft');
  final isStructured = su.isNotEmpty;
  final isPiece = su == 'Piece';

  if (!isStructured) return _fmtNum(restock);
  if (isPiece) {
    if (baseUom == 'sheet' && unitSqft > 1) {
      final packs = unitSqft > 0 ? restock / unitSqft : 0.0;
      return '${_fmtNum(restock)} sh / ${_fmtNum(packs)} pk';
    }
    final label = baseUom == 'sheet' ? 'sh' : 'pcs';
    return '${_fmtNum(restock)} $label';
  }
  final stockUnits = unitSqft > 0 ? restock / unitSqft : 0.0;
  final label = _stockUnitLabel(su);
  return '${_fmtNum(stockUnits)} ${label}s';
}

// Builds the sub-line shown under the material name in the table.
String _buildMatSubLine(Map<String, dynamic> data) {
  final su = data['stocking_unit']?.toString();
  if (su == null || su.isEmpty) return '';
  if (su == 'Piece') {
    final baseUom  = data['base_uom']?.toString() ?? 'pc';
    final unitSize = (data['unit_size_sqft'] as num?)?.toDouble() ?? 1;
    if (baseUom == 'sheet' && unitSize > 1) {
      return 'Pack · ${_fmtNum(unitSize)} sheets';
    }
    return 'Piece';
  }
  final wv = (data['width_value'] as num?)?.toDouble() ?? 0;
  final wu = data['width_unit']?.toString() ?? 'ft';
  final lv = (data['length_value'] as num?)?.toDouble() ?? 0;
  final lu = data['length_unit']?.toString() ?? 'm';
  return '$su (${_fmtNum(wv)}$wu × ${_fmtNum(lv)}$lu)';
}


// =============================================================================
// Seed-entry helper (used by _seedHistoricalData)
// =============================================================================
class _SeedEntry {
  final String productName;
  final double qpu;     // quantity_per_unit from BOM
  final String variant; // for_material_option (may be empty)
  const _SeedEntry(this.productName, this.qpu, this.variant);
}
// =============================================================================
// Authoritative raw-material list â€” 33 materials (replaces old seed list)
// =============================================================================
const _kNewMaterials = [
  // â”€â”€ Rolls â€” width in ft, length in m â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-001','material_name':'Vinyl Matte Sticker','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':2050.53,'current_stock':0.0},
  {'material_id':'RM-002','material_name':'Clear Matte Printable','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':2050.53,'current_stock':0.0},
  {'material_id':'RM-003','material_name':'Clear Glossy Printable','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':1230.32,'current_stock':0.0},
  {'material_id':'RM-004','material_name':'Poster Paper Matte','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':1230.32,'current_stock':0.0},
  {'material_id':'RM-005','material_name':'Poster Paper Glossy','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':1230.32,'current_stock':0.0},
  {'material_id':'RM-006','material_name':'Vinyl Glossy Sticker','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':1230.32,'current_stock':0.0},
  {'material_id':'RM-007','material_name':'Sticker Matte (paper)','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':1230.32,'current_stock':0.0},
  {'material_id':'RM-008','material_name':'Sticker Glossy (paper)','stocking_unit':'Roll','width_value':2.5,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':410.11,'base_uom':'sqft','unit_description':'Roll (2.5ft × 50m)','restock_level':1230.32,'current_stock':0.0},
  {'material_id':'RM-009','material_name':'Tarpaulin 13oz','stocking_unit':'Roll','width_value':10.0,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':1640.42,'base_uom':'sqft','unit_description':'Roll (10ft × 50m)','restock_level':4921.26,'current_stock':0.0},
  {'material_id':'RM-010','material_name':'Tarpaulin 10oz','stocking_unit':'Roll','width_value':10.0,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':1640.42,'base_uom':'sqft','unit_description':'Roll (10ft × 50m)','restock_level':4921.26,'current_stock':0.0},
  // â”€â”€ Sheets â€” width & length in ft â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-011','material_name':'Composite Panel 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':160.0,'current_stock':0.0},
  {'material_id':'RM-012','material_name':'Acrylic Clear 5mm 3x8','stocking_unit':'Sheet','width_value':3.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':24.0,'base_uom':'sqft','unit_description':'Sheet (3ft × 8ft)','restock_level':48.0,'current_stock':0.0},
  {'material_id':'RM-013','material_name':'Acrylic Chalk White 4x4','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':4.0,'length_unit':'ft','unit_size_sqft':16.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 4ft)','restock_level':32.0,'current_stock':0.0},
  {'material_id':'RM-014','material_name':'Acrylic Diffuser 3mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':64.0,'current_stock':0.0},
  {'material_id':'RM-015','material_name':'Acrylic Diffuser 1.5mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':64.0,'current_stock':0.0},
  {'material_id':'RM-016','material_name':'Acrylic Clear 3mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':64.0,'current_stock':0.0},
  {'material_id':'RM-017','material_name':'Acrylic Clear 1.5mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':64.0,'current_stock':0.0},
  {'material_id':'RM-018','material_name':'Sintra Board 1.5mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':96.0,'current_stock':0.0},
  {'material_id':'RM-019','material_name':'Sintra Board 2mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':96.0,'current_stock':0.0},
  {'material_id':'RM-020','material_name':'Sintra Board 3mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':96.0,'current_stock':0.0},
  {'material_id':'RM-021','material_name':'Sintra Board 5mm 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':64.0,'current_stock':0.0},
  {'material_id':'RM-022','material_name':'Plastic PVC Board 4x8','stocking_unit':'Sheet','width_value':4.0,'width_unit':'ft','length_value':8.0,'length_unit':'ft','unit_size_sqft':32.0,'base_uom':'sqft','unit_description':'Sheet (4ft × 8ft)','restock_level':96.0,'current_stock':0.0},
  // â”€â”€ Piece â€” no dimensions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-023','material_name':'Metal Furring','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':10.0,'current_stock':0.0},
  // â”€â”€ Roll â€” Panaflex â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-024','material_name':'Panaflex Flex','stocking_unit':'Roll','width_value':10.0,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':1640.42,'base_uom':'sqft','unit_description':'Roll (10ft × 50m)','restock_level':4921.26,'current_stock':0.0},
  // â”€â”€ Photo paper packs â€” base UoM = sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-025','material_name':'Photo Paper 4R','stocking_unit':'Piece','unit_size_sqft':100.0,'base_uom':'sheet','unit_description':'Pack (100 sheets)','restock_level':200.0,'current_stock':0.0},
  // â”€â”€ Sheets â€” Card stock â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-026','material_name':'Card Stock Matte','stocking_unit':'Sheet','width_value':1.083,'width_unit':'ft','length_value':0.875,'length_unit':'ft','unit_size_sqft':0.95,'base_uom':'sqft','unit_description':'Sheet (1.083ft × 0.875ft)','restock_level':4.74,'current_stock':0.0},
  {'material_id':'RM-027','material_name':'Card Stock Glossy','stocking_unit':'Sheet','width_value':1.083,'width_unit':'ft','length_value':0.875,'length_unit':'ft','unit_size_sqft':0.95,'base_uom':'sqft','unit_description':'Sheet (1.083ft × 0.875ft)','restock_level':4.74,'current_stock':0.0},
  // â”€â”€ Stand units â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-028','material_name':'Roll-up Stand','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':5.0,'current_stock':0.0},
  // â”€â”€ More photo paper packs â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-029','material_name':'Photo Paper 3R','stocking_unit':'Piece','unit_size_sqft':100.0,'base_uom':'sheet','unit_description':'Pack (100 sheets)','restock_level':100.0,'current_stock':0.0},
  {'material_id':'RM-030','material_name':'Photo Paper 5R','stocking_unit':'Piece','unit_size_sqft':100.0,'base_uom':'sheet','unit_description':'Pack (100 sheets)','restock_level':100.0,'current_stock':0.0},
  {'material_id':'RM-031','material_name':'Photo Paper 8R/A4','stocking_unit':'Piece','unit_size_sqft':50.0,'base_uom':'sheet','unit_description':'Pack (50 sheets)','restock_level':50.0,'current_stock':0.0},
  // â”€â”€ Equipment units â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  {'material_id':'RM-032','material_name':'X-banner Frame','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':5.0,'current_stock':0.0},
  {'material_id':'RM-033','material_name':'PVC ID Card Blank','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':20.0,'current_stock':0.0},
];

// =============================================================================
// Legacy seed data (kept for reference â€” superseded by _kNewMaterials)
// =============================================================================
const _kInitialMaterials = [
  {
    'material_id': 'RM-001',
    'material_name': 'Poster Glitter',
    'unit_description': '1 roll',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-002',
    'material_name': 'Vinyl Matte Sticker',
    'unit_description': '1 roll',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-003',
    'material_name': 'Clear Matte Printable',
    'unit_description': '1 roll',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-004',
    'material_name': 'Clear Glossy Printable',
    'unit_description': '1/2 roll',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-005',
    'material_name': 'Poster Paper Matte',
    'unit_description': '1/2 roll',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-006',
    'material_name': 'Poster Paper Glossy',
    'unit_description': '3/4 roll',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-007',
    'material_name': 'Vinyl Glossy Sticker',
    'unit_description': '3/4 roll',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-008',
    'material_name': '5ft Matte Sticker',
    'unit_description': '1/4 roll',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-009',
    'material_name': '3in Sticker',
    'unit_description': '4x5ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-010',
    'material_name': 'Composite Panel (4x8ft)',
    'unit_description': '4x8ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-011',
    'material_name': 'Composite Panel (2x4ft)',
    'unit_description': '2x4ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-012',
    'material_name': 'Acrylic Clear 5mm',
    'unit_description': '3x8ft sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-013',
    'material_name': 'Acrylic Chalk White',
    'unit_description': '4x4ft sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-014',
    'material_name': 'Acrylic Diffuser 3mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-015',
    'material_name': 'Acrylic Diffuser 1.5mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-016',
    'material_name': 'Acrylic Clear 3mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-017',
    'material_name': 'Acrylic Clear 1.5mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-018',
    'material_name': 'Sintra Board 3mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-019',
    'material_name': 'Sintra Board 1.5mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-020',
    'material_name': 'Sintra Board 5mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-021',
    'material_name': 'Tarpaulin 13oz',
    'unit_description': 'Roll (13oz)',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-022',
    'material_name': 'Tarpaulin 10oz',
    'unit_description': 'Roll (10oz)',
    'restock_level': 3.0,
  },
  {
    'material_id': 'RM-023',
    'material_name': 'Sticker Matte',
    'unit_description': 'Roll',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-024',
    'material_name': 'Sticker Glossy',
    'unit_description': 'Roll',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-025',
    'material_name': 'Sintra Board 2mm',
    'unit_description': '4x8ft sheet',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-026',
    'material_name': 'Plastic PVC',
    'unit_description': 'Sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-027',
    'material_name': 'Adhesive',
    'unit_description': 'pcs / bottle',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-028',
    'material_name': 'Signage - Composite Panel',
    'unit_description': 'Sheet',
    'restock_level': 5.0,
  },
  {
    'material_id': 'RM-029',
    'material_name': 'Signage - Metal Furring',
    'unit_description': 'pcs',
    'restock_level': 20.0,
  },
];