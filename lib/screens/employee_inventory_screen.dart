import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_theme.dart';
import 'employee_inventory_forecast_screen.dart';
import 'platform_utils.dart';

// ── Shared colour constants (aligned with admin) ──────────────────────────────
const Color _amber = Color(0xFFB45309);
const Color _navyBlue = Color(0xFF0F1A2E);

// ── Liquid Glass Design Tokens (aligned with admin) ───────────────────────────
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

final _blurFilter = ImageFilter.blur(sigmaX: 14, sigmaY: 14);

// ── Breakpoint ────────────────────────────────────────────────────────────────
const double _kTableMinWidth = 500.0;

// ── Dimension helpers (mirrors admin screen) ──────────────────────────────────
double _toFeet(double v, String unit) {
  if (unit == 'in') return v / 12.0;
  if (unit == 'm') return v * 3.28084;
  return v;
}

double _calcUnitSqft(double wV, String wU, double lV, String lU) =>
    _toFeet(wV, wU) * _toFeet(lV, lU);

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _stockUnitLabel(String su) {
  if (su == 'Sheet') return 'sheet';
  if (su == 'Roll') return 'roll';
  return 'pc';
}

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

// ── Sub-tab enum (mirrors admin) ──────────────────────────────────────────────
enum _InventoryTab { inventory, forecast }

// =============================================================================
// Root screen — now hosts both Inventory and Forecast sub-tabs
// =============================================================================
class EmployeeInventoryScreen extends StatefulWidget {
  const EmployeeInventoryScreen({super.key});

  @override
  State<EmployeeInventoryScreen> createState() =>
      _EmployeeInventoryScreenState();
}

class _EmployeeInventoryScreenState extends State<EmployeeInventoryScreen> {
  // ── Sub-tab state ──────────────────────────────────────────────────────────
  _InventoryTab _activeTab = _InventoryTab.inventory;

  // ── Inventory-tab state ────────────────────────────────────────────────────
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  DateTime? _scanFirstKey;
  DateTime? _scanLastKey;

  String? _statusFilter;
  String _employeeName = '';
  String _employeeUid = '';

  // Counts fed up from the stream so header pills stay live
  Map<String, int> _counts = {};
  int _total = 0;

  static const _statuses = [
    'In Stock',
    'Low Stock',
    'Critical',
    'Out of Stock',
  ];

  @override
  void initState() {
    super.initState();
    _loadEmployee();
    if (kIsWeb && !PlatformUtils.effectiveMobile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _loadEmployee() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _employeeName =
            doc.data()?['full_name'] ?? user.displayName ?? 'Employee';
        _employeeUid = user.uid;
      });
    }
  }

  String _computeStatus(num current, num restock) {
    if (current <= 0) return 'Out of Stock';
    if (current <= restock * 0.5) return 'Critical';
    if (current <= restock) return 'Low Stock';
    return 'In Stock';
  }

  Color _statusColor(String status) {
    switch (status) {
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

  bool _isPhysicalScanner(String code) {
    if (_scanFirstKey == null || _scanLastKey == null || code.length < 2) {
      return false;
    }
    final elapsed = _scanLastKey!.difference(_scanFirstKey!).inMilliseconds;
    final msPerChar = elapsed / code.length;
    return msPerChar < 50;
  }

  void _onScanFieldChanged(String value) {
    final now = DateTime.now();
    if (value.length == 1) _scanFirstKey = now;
    _scanLastKey = now;
  }

  void _onScanFieldSubmitted(String rawCode) {
    final fromPhysicalScanner = _isPhysicalScanner(rawCode.trim());
    _scanFirstKey = null;
    _scanLastKey = null;
    _handleScan(rawCode, fromCamera: fromPhysicalScanner);
  }

  Future<void> _handleScan(String rawCode, {bool fromCamera = false}) async {
    final code = rawCode.trim();
    if (code.isEmpty) return;
    _scanCtrl.clear();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('RawMaterials')
          .doc(code)
          .get();

      if (!mounted) return;

      if (!snap.exists) {
        _snack('Material "$code" not found', Colors.orange);
        return;
      }

      _showReplenishDialog(
        snap.id,
        snap.data() as Map<String, dynamic>,
        method: fromCamera ? 'qr_scan' : 'manual',
      );
    } catch (e) {
      if (mounted) _snack('Scan error: $e', Colors.red);
    }
  }

  void _openCameraScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _QrScannerPage(
          onScan: (code) {
            Navigator.pop(context);
            _handleScan(code, fromCamera: true);
          },
        ),
      ),
    );
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Replenish dialog ────────────────────────────────────────────────────────
  void _showReplenishDialog(
    String docId,
    Map<String, dynamic> material, {
    required String method,
  }) {
    final qtyCtrl = TextEditingController();
    final name     = material['material_name']?.toString() ?? '';
    final unitDesc = material['unit_description']?.toString() ?? '';
    final su       = material['stocking_unit']?.toString() ?? 'Piece';
    final baseUom  = material['base_uom']?.toString() ??
        (su == 'Piece' ? 'pc' : 'sqft');
    final unitSize = (material['unit_size_sqft'] as num?)?.toDouble() ?? 1.0;
    final current  = (material['current_stock'] as num?) ?? 0;
    final isPiece  = su == 'Piece';
    final isPack   = isPiece && baseUom == 'sheet';
    final isSqft   = !isPiece;
    // Label for one stocking unit (e.g. "roll", "sheet", "pack", "pc")
    final suLabel  = isPack ? 'pack' : (isPiece ? 'pc' : _stockUnitLabel(su));
    bool saving = false;

    // Format a base-unit quantity for display.
    String fmtBase(num v) {
      final s = v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);
      return '$s $baseUom';
    }
    // Format a stocking-unit quantity for display.
    String fmtStock(double v) {
      final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
      return '$s ${suLabel}s';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          backgroundColor: _Glass.surface,
          elevation: 32,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _Glass.borderMid, width: 1),
          ),
          child: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _navyBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Replenish Stock',
                          style: TextStyle(
                            color: _Glass.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: saving ? null : () => Navigator.pop(ctx),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _Glass.surfaceThin,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _Glass.borderMid,
                              width: 0.9,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _Glass.textMuted,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  color: _Glass.borderMid,
                  height: 16,
                  thickness: 0.8,
                ),

                // ── Content ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _Glass.borderMid,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (unitDesc.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                unitDesc,
                                style: const TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Current stock: ',
                                  style: TextStyle(
                                    color: _Glass.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  fmtBase(current),
                                  style: const TextStyle(
                                    color: _Glass.accentEmerald,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isSqft && unitSize > 0) ...[
                                  const Text(
                                    '  (',
                                    style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    fmtStock(
                                        (current as double) / unitSize),
                                    style: const TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 12),
                                  ),
                                  const Text(
                                    ')',
                                    style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                                if (isPack && unitSize > 0) ...[
                                  const Text(
                                    '  (',
                                    style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 12),
                                  ),
                                  Text(
                                    fmtStock(
                                        (current as double) / unitSize),
                                    style: const TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 12),
                                  ),
                                  const Text(
                                    ')',
                                    style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      _SectionLabel(
                        isPiece && !isPack
                            ? 'Quantity to add (pcs)'
                            : 'Number of ${suLabel}s to add',
                      ),
                      if (unitSize > 1) ...[
                        const SizedBox(height: 3),
                        Text(
                          '1 $suLabel = ${_fmtNum(unitSize)} $baseUom'
                          '  •  e.g. enter 2 to add ${_fmtNum(unitSize * 2)} $baseUom',
                          style: const TextStyle(
                            color: _Glass.accentEmerald,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      StatefulBuilder(
                        builder: (_, setQty) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _GlassField(
                              controller: qtyCtrl,
                              hint: 'e.g. 1',
                              icon: Icons.add_circle_outline_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setQty(() {}),
                            ),
                            if (unitSize > 1 && qtyCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Builder(
                                builder: (_) {
                                  final qty =
                                      double.tryParse(qtyCtrl.text.trim()) ?? 0;
                                  final total = qty * unitSize;
                                  return Text(
                                    '= ${_fmtNum(total)} $baseUom will be added',
                                    style: const TextStyle(
                                      color: _Glass.accentEmerald,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            color: _Glass.textMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _employeeName,
                            style: const TextStyle(
                              color: _Glass.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.qr_code_2,
                            color: _Glass.textMuted,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            method == 'qr_scan' ? 'QR Scan' : 'Manual',
                            style: const TextStyle(
                              color: _Glass.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ── Action bar ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: _Glass.borderMid, width: 0.9),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: saving ? null : () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
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
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: saving
                            ? null
                            : () async {
                                final inputQty = double.tryParse(
                                  qtyCtrl.text.trim(),
                                );
                                if (inputQty == null || inputQty <= 0) {
                                  _snack(
                                    'Enter a valid quantity > 0',
                                    Colors.orange,
                                  );
                                  return;
                                }
                                // Universal conversion: input × unit_size
                                // Works for all types: rolls (→sqft),
                                // sheets (→sqft), packs (→sheets), pcs (×1).
                                final actualQty = inputQty * unitSize;
                                setDlg(() => saving = true);
                                await _commitReplenish(
                                  docId,
                                  material,
                                  actualQty,
                                  method,
                                  ctx,
                                );
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: _Glass.solidPill(_navyBlue, glow: true),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (saving)
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
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 6),
                              const Text(
                                'Confirm',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _commitReplenish(
    String docId,
    Map<String, dynamic> material,
    double qty,
    String method,
    BuildContext dialogCtx,
  ) async {
    final materialId = material['material_id']?.toString() ?? docId;
    final materialName = material['material_name']?.toString() ?? '';
    double previousStock = 0;
    double newStock = 0;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final ref = FirebaseFirestore.instance
            .collection('RawMaterials')
            .doc(docId);
        final snap = await tx.get(ref);
        previousStock = ((snap.data()?['current_stock'] as num?) ?? 0)
            .toDouble();
        newStock = previousStock + qty;

        tx.update(ref, {
          'current_stock': newStock,
          'last_updated': FieldValue.serverTimestamp(),
          'last_updated_by': _employeeName,
          'last_updated_by_uid': _employeeUid,
        });

        final logRef = FirebaseFirestore.instance
            .collection('InventoryLogs')
            .doc();
        tx.set(logRef, {
          'material_id': materialId,
          'material_name': materialName,
          'quantity_added': qty,
          'previous_stock': previousStock,
          'new_stock': newStock,
          'updated_by_uid': _employeeUid,
          'updated_by_name': _employeeName,
          'timestamp': FieldValue.serverTimestamp(),
          'update_method': method,
        });
      });

      _refreshProductAvailability(materialId);

      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$materialName: +${_fmtNum(qty)} → ${_fmtNum(newStock)} '
            '${(material['base_uom'] ?? material['unit_description'] ?? '')}',
          ),
          backgroundColor: _Glass.accentEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: _Glass.accentRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _refreshProductAvailability(String materialId) async {
    try {
      final products = await FirebaseFirestore.instance
          .collection('Products')
          .get();
      for (final doc in products.docs) {
        final data = doc.data();
        final bom = (data['bill_of_materials'] as List?) ?? [];
        final usesMaterial = bom.any(
          (item) => (item as Map)['material_id']?.toString() == materialId,
        );
        if (!usesMaterial) continue;

        bool available = true;
        for (final item in bom) {
          final matId = (item as Map)['material_id']?.toString() ?? '';
          final matDoc = await FirebaseFirestore.instance
              .collection('RawMaterials')
              .doc(matId)
              .get();
          final stock = (matDoc.data()?['current_stock'] as num?) ?? 0;
          if (stock <= 0) {
            available = false;
            break;
          }
        }
        if (data['availability_override'] == null) {
          await doc.reference.update({'is_available': available});
        }
      }
    } catch (_) {}
  }

  // ── Add new material ────────────────────────────────────────────────────────
  void _showAddMaterialDialog(
    BuildContext context,
    List<Map<String, dynamic>> materials,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => _AddMaterialDialog(
        onAdded: (msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: _Glass.accentEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        )),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Unified header card (mirrors admin layout exactly) ────────
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: _blurFilter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: _Glass.glass(radius: 20, elevated: true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: icon + title + Add Material button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Inventory',
                                style: TextStyle(
                                  color: _Glass.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Raw materials — stock levels and forecast',
                                style: TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Only show Add Material on the inventory tab
                        _AddMaterialButton(
                          onTap: () => _showAddMaterialDialog(context, []),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Divider(height: 1, color: _Glass.borderDim),
                    const SizedBox(height: 12),

                    // Row 2: sub-tab pills (Inventory | Forecast)
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
                          onTap: () => setState(
                            () => _activeTab = _InventoryTab.forecast,
                          ),
                        ),
                      ],
                    ),

                    // Row 3: scan bar + status filter pills
                    // (only on Inventory tab)
                    if (_activeTab == _InventoryTab.inventory) ...[
                      const SizedBox(height: 12),

                      // Scan bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _Glass.surfaceThin,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _Glass.borderMid,
                                  width: 0.8,
                                ),
                              ),
                              child: TextField(
                                controller: _scanCtrl,
                                focusNode: _scanFocus,
                                style: const TextStyle(
                                  color: _Glass.textPrimary,
                                  fontSize: 13,
                                ),
                                onChanged: _onScanFieldChanged,
                                onSubmitted: _onScanFieldSubmitted,
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: (kIsWeb && !PlatformUtils.effectiveMobile)
                                      ? 'Physical scanner or type ID (e.g. RM-001) + Enter'
                                      : 'Type material ID (e.g. RM-001) + Enter',
                                  hintStyle: const TextStyle(
                                    color: _Glass.textMuted,
                                    fontSize: 12,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.qr_code_scanner,
                                    color: _Glass.textMuted,
                                    size: 18,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (PlatformUtils.isMobileDevice) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _openCameraScanner,
                              child: Container(
                                padding: const EdgeInsets.all(11),
                                decoration: BoxDecoration(
                                  color: _Glass.surfaceThin,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _Glass.borderMid,
                                    width: 0.8,
                                  ),
                                  boxShadow: const [_Glass.rowShadow],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: _Glass.textSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status filter pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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

          // ── Body ────────────────────────────────────────────────────────
          Expanded(
            child: _activeTab == _InventoryTab.forecast
                ? const _EmbeddedForecast()
                : _buildInventoryBody(),
          ),
        ],
      ),
    );
  }

  // ── Inventory body (table panel) ────────────────────────────────────────────
  Widget _buildInventoryBody() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('RawMaterials')
          .orderBy('material_id')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(
              color: _navyBlue.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: _Glass.glass(radius: 22, elevated: true),
                    child: const Icon(
                      Icons.wifi_off_outlined,
                      size: 32,
                      color: _Glass.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Could not load inventory',
                    style: TextStyle(
                      color: _Glass.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Check your internet connection and try again',
                    style: TextStyle(color: _Glass.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
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
                        decoration: _Glass.glass(radius: 22, elevated: true),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ask the admin to seed the initial materials',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

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

        // Sync counts into state for header pills
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
                  Widget buildTable() => ListView.builder(
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
                      return _TableRow(
                        data: filtered[idx],
                        isLast: idx == filtered.length - 1,
                        statusColor: _statusColor(
                          filtered[idx]['_status'] as String,
                        ),
                        onEdit: () => _showReplenishDialog(
                          filtered[idx]['doc_id'] as String,
                          filtered[idx],
                          method: 'manual',
                        ),
                      );
                    },
                  );
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
}

// =============================================================================
// _AddMaterialButton — extracted so the header can render it declaratively
// while the actual dialog call still happens inside the stream context
// =============================================================================
class _AddMaterialButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMaterialButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: _Glass.solidPill(_navyBlue, glow: true),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 14, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Add Material',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================================
// _TabPill — mirrors admin's _TabPill exactly
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
// _FilterPill — status filter pill with inline count (unchanged)
// =============================================================================
class _FilterPill extends StatelessWidget {
  final String label;
  final int? count;
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
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
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
// _TableHeader (unchanged)
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
          width: 150,
          child: Text('Available Stock', style: _h, textAlign: TextAlign.center),
        ),
        SizedBox(
          width: 90,
          child: Text('Status', style: _h, textAlign: TextAlign.center),
        ),
        SizedBox(width: 60),
      ],
    ),
  );
}

// =============================================================================
// _TableRow (unchanged)
// =============================================================================
class _TableRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final bool isLast;
  final VoidCallback onEdit;

  const _TableRow({
    required this.data,
    required this.statusColor,
    required this.onEdit,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final id      = data['material_id']?.toString() ?? '';
    final name    = data['material_name']?.toString() ?? '';
    final status  = data['_status']?.toString() ?? '';
    final current  = (data['current_stock'] as num?)?.toDouble() ?? 0;
    final su       = data['stocking_unit']?.toString() ?? '';
    final unitSqft = (data['unit_size_sqft'] as num?)?.toDouble() ?? 0;
    final baseUom  = data['base_uom']?.toString() ??
        (su == 'Piece' ? 'pc' : 'sqft');
    final subLine      = _buildMatSubLine(data);
    final isStructured = su.isNotEmpty;
    final isPiece      = su == 'Piece';

    // Available stock cell
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
        children: [
          Text('${_fmtNum(current)} $baseUom',
              style: const TextStyle(color: _Glass.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          Text('${_fmtNum(stockUnits)} ${label}s',
              style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
              textAlign: TextAlign.center),
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
          SizedBox(
            width: 74,
            child: Text(id,
                style: const TextStyle(
                    color: _Glass.textMuted, fontSize: 12,
                    fontFamily: 'monospace', fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: _Glass.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subLine.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(subLine,
                      style: const TextStyle(color: _Glass.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
          SizedBox(width: 150, child: Center(child: stockCell)),
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
                child: Text(status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _navyBlue,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(color: _navyBlue.withValues(alpha: 0.22),
                          blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Text('Edit',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
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
// _EmbeddedForecast
// Wraps EmployeeInventoryForecastScreen so it fills only the body area
// (the header + padding are already provided by EmployeeInventoryScreen).
// All logic inside EmployeeInventoryForecastScreen is completely untouched.
// =============================================================================
class _EmbeddedForecast extends StatelessWidget {
  const _EmbeddedForecast();

  @override
  Widget build(BuildContext context) {
    return EmployeeInventoryForecastScreen(); // ← remove const
  }
}

// =============================================================================
// Shared form helpers (unchanged)
// =============================================================================
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _GlassField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    onChanged: onChanged,
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
  final _formKey      = GlobalKey<FormState>();
  final _idCtrl       = TextEditingController();
  final _nameCtrl     = TextEditingController();
  String _su          = 'Roll';
  final _wCtrl        = TextEditingController();
  String _wUnit       = 'ft';
  final _lCtrl        = TextEditingController();
  String _lUnit       = 'm';
  String _baseUom     = 'pc';
  final _packSizeCtrl = TextEditingController(text: '1');
  final _restockCtrl  = TextEditingController(text: '5');
  final _stockCtrl    = TextEditingController(text: '0');
  bool _saving = false;

  bool get _isPiece => _su == 'Piece';
  bool get _isPack  => _isPiece && _baseUom == 'sheet';

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
              // ── Title bar ────────────────────────────────────────────────
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

              // ── Form ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel('Material ID'),
                      const SizedBox(height: 6),
                      _GlassField(controller: _idCtrl, hint: 'e.g. RM-030', icon: Icons.tag_rounded,
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 12),

                      _SectionLabel('Material Name *'),
                      const SizedBox(height: 6),
                      _GlassField(controller: _nameCtrl, hint: 'e.g. Tarpaulin 13oz', icon: Icons.inventory_2_outlined,
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                      const SizedBox(height: 12),

                      _SectionLabel('Stocking Unit *'),
                      const SizedBox(height: 6),
                      _GlassDropdown<String>(
                        value: _su,
                        items: const ['Roll', 'Sheet', 'Piece'],
                        onChanged: (v) => setState(() { _su = v!; _baseUom = 'pc'; }),
                      ),
                      const SizedBox(height: 12),

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
                            '→ ${_fmtNum(_unitSizeSqft)} sheets per pack',
                            style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],

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
                              const Text('Unit size: ', style: TextStyle(color: _Glass.textMuted, fontSize: 12)),
                              Text(_unitSizeDisplay,
                                  style: const TextStyle(color: _Glass.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

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

              // ── Action bar ───────────────────────────────────────────────
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
      final stockInput   = double.tryParse(_stockCtrl.text) ?? 0.0;
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
// Shared dropdown + dimension helpers
// =============================================================================
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
// QR Camera Scanner Page (unchanged)
// =============================================================================
class _QrScannerPage extends StatefulWidget {
  final Function(String) onScan;
  const _QrScannerPage({required this.onScan});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  late final MobileScannerController _ctrl;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    _ctrl.stop();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            errorBuilder: (ctx, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white38,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission denied.\nGo to Settings → Apps → Permissions.'
                            : 'Camera unavailable: '
                                  '${error.errorDetails?.message ?? error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: _Glass.solidPill(_navyBlue, glow: true),
                          child: const Text(
                            'Go Back',
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
                ),
              );
            },
            onDetect: (capture) {
              if (_scanned) return;
              final barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final code = barcodes.first.rawValue;
              if (code != null && code.isNotEmpty) {
                _scanned = true;
                widget.onScan(code);
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _amber.withValues(alpha: 0.9),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'Point at the QR code on the raw material label',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
