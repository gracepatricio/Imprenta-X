import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_theme.dart';

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xEEFFFFFF);
  static const Color surfaceMid = Color(0xCCFFFFFF);
  static const Color surfaceThin = Color(0x99FFFFFF);

  static const Color borderTop = Color(0xEEFFFFFF);
  static const Color borderMid = Color(0x55FFFFFF);
  static const Color borderDim = Color(0x28FFFFFF);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xBB111827);
  static const Color textMuted = Color(0x77111827);

  static const BoxShadow elevatedShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 20,
    spreadRadius: -2,
    offset: Offset(0, 6),
  );
  static const BoxShadow rowShadow = BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    spreadRadius: 0,
    offset: Offset(0, 2),
  );

  static BoxDecoration card({
    Color? color,
    double radius = 14,
    bool elevated = false,
  }) => BoxDecoration(
    color: color ?? surfaceMid,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderMid, width: 0.8),
    boxShadow: [elevated ? elevatedShadow : rowShadow],
  );

  static BoxDecoration pill({Color? tint}) => BoxDecoration(
    color: tint != null ? tint.withValues(alpha: 0.15) : surfaceThin,
    borderRadius: BorderRadius.circular(99),
    border: Border.all(
      color: tint != null ? tint.withValues(alpha: 0.45) : borderMid,
      width: 0.8,
    ),
    boxShadow: [rowShadow],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class EmployeeInventoryScreen extends StatefulWidget {
  const EmployeeInventoryScreen({super.key});

  @override
  State<EmployeeInventoryScreen> createState() =>
      _EmployeeInventoryScreenState();
}

class _EmployeeInventoryScreenState extends State<EmployeeInventoryScreen> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  DateTime? _scanFirstKey;
  DateTime? _scanLastKey;

  String? _statusFilter;
  String _employeeName = '';
  String _employeeUid = '';

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
    if (kIsWeb) {
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
        return const Color(0xFF2E7D32);
      case 'Low Stock':
        return const Color(0xFFF57F17);
      case 'Critical':
        return const Color(0xFFBF360C);
      default:
        return const Color(0xFFC62828);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final name = material['material_name']?.toString() ?? '';
    final unit = material['unit_description']?.toString() ?? '';
    final stockUnit = material['stock_unit']?.toString() ?? 'pcs';
    final pieceToSqft = (material['piece_to_sqft'] as num?)?.toDouble();
    final isSqft = stockUnit == 'sqft';
    final current = (material['current_stock'] as num?) ?? 0;
    bool saving = false;

    String fmt(num v) {
      final s = v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);
      return '$s $stockUnit';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _Glass.surface,
          elevation: 32,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _Glass.borderMid, width: 1),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x1A1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Glass.borderMid),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: _Glass.textSecondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Replenish Stock',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Material info card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _Glass.surfaceThin,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Glass.borderMid, width: 0.8),
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
                      if (unit.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          unit,
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
                            fmt(current),
                            style: const TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  isSqft && pieceToSqft != null
                      ? 'Number of pieces to add (rolls / sheets)'
                      : 'Quantity to add (${isSqft ? 'sqft' : 'pcs'})',
                  style: const TextStyle(
                    color: _Glass.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (isSqft && pieceToSqft != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '1 piece = ${pieceToSqft.toStringAsFixed(1)} sqft  •  '
                    'e.g. enter 1 to add ${pieceToSqft.toStringAsFixed(0)} sqft',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
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
                        label: isSqft && pieceToSqft != null
                            ? 'e.g. 1 (roll/sheet)'
                            : 'e.g. 2',
                        icon: Icons.add_circle_outline_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setQty(() {}),
                      ),
                      if (isSqft &&
                          pieceToSqft != null &&
                          qtyCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Builder(
                          builder: (_) {
                            final pieces =
                                double.tryParse(qtyCtrl.text.trim()) ?? 0;
                            final sqft = pieces * pieceToSqft;
                            return Text(
                              '= ${sqft.toStringAsFixed(1)} sqft will be added',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: _Glass.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel'),
            ),
            _GlassButton(
              label: 'Confirm',
              isPrimary: true,
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      final inputQty = double.tryParse(qtyCtrl.text.trim());
                      if (inputQty == null || inputQty <= 0) {
                        _snack('Enter a valid quantity > 0', Colors.orange);
                        return;
                      }
                      final actualQty = (isSqft && pieceToSqft != null)
                          ? inputQty * pieceToSqft
                          : inputQty;
                      setDlg(() => saving = true);
                      await _commitReplenish(
                        docId,
                        material,
                        actualQty,
                        method,
                        ctx,
                      );
                    },
            ),
          ],
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
            '$materialName updated: +$qty → $newStock '
            '${material['unit_description'] ?? ''}',
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
  String _nextMaterialId(List<Map<String, dynamic>> materials) {
    int maxNum = 0;
    for (final m in materials) {
      final id = m['material_id']?.toString() ?? '';
      if (id.startsWith('RM-')) {
        final n = int.tryParse(id.substring(3)) ?? 0;
        if (n > maxNum) maxNum = n;
      }
    }
    return 'RM-${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  void _showAddMaterialDialog(
    BuildContext context,
    List<Map<String, dynamic>> materials,
  ) {
    final suggestedId = _nextMaterialId(materials);
    final idCtrl = TextEditingController(text: suggestedId);
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final restockCtrl = TextEditingController(text: '5');
    final stockCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _Glass.surface,
          elevation: 32,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _Glass.borderMid, width: 1),
          ),
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0x1A1A1A2E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _Glass.borderMid),
                ),
                child: const Icon(
                  Icons.add_box_outlined,
                  color: _Glass.textSecondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add Raw Material',
                style: TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GlassField(
                    controller: idCtrl,
                    label: 'Material ID',
                    icon: Icons.tag_rounded,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  _GlassField(
                    controller: nameCtrl,
                    label: 'Material Name',
                    icon: Icons.inventory_2_outlined,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  _GlassField(
                    controller: unitCtrl,
                    label: 'Unit (e.g. 1 roll, 4x8ft sheet)',
                    icon: Icons.straighten_rounded,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _GlassField(
                          controller: restockCtrl,
                          label: 'Restock at',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Required';
                            if (double.tryParse(v.trim()) == null)
                              return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _GlassField(
                          controller: stockCtrl,
                          label: 'Initial stock',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty)
                              return 'Required';
                            if (double.tryParse(v.trim()) == null)
                              return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: _Glass.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel'),
            ),
            _GlassButton(
              label: 'Add',
              isPrimary: true,
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) return;
                      setDlg(() => saving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final id = idCtrl.text.trim();
                        await FirebaseFirestore.instance
                            .collection('RawMaterials')
                            .doc(id)
                            .set({
                              'material_id': id,
                              'material_name': nameCtrl.text.trim(),
                              'unit_description': unitCtrl.text.trim(),
                              'restock_level':
                                  double.tryParse(restockCtrl.text) ?? 5.0,
                              'current_stock':
                                  double.tryParse(stockCtrl.text) ?? 0.0,
                              'last_updated': null,
                              'last_updated_by': '',
                              'last_updated_by_uid': '',
                            });
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('$id added to inventory'),
                            backgroundColor: const Color(0xFF2E7D32),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                        setDlg(() => saving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
              color: _Glass.textPrimary.withValues(alpha: 0.5),
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
                    decoration: _Glass.card(radius: 20, elevated: true),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: _Glass.card(radius: 20, elevated: true),
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
                  style: TextStyle(color: _Glass.textSecondary, fontSize: 13),
                ),
              ],
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

        final counts = <String, int>{};
        for (final m in materials) {
          final s = m['_status'] as String;
          counts[s] = (counts[s] ?? 0) + 1;
        }

        final filtered = _statusFilter == null
            ? materials
            : materials.where((m) => m['_status'] == _statusFilter).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            return Padding(
              // ── Proper side padding matching admin layout ──
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top panel ──────────────────────────────────────────
                  _TopPanel(
                    isWide: isWide,
                    statuses: _statuses,
                    counts: counts,
                    statusFilter: _statusFilter,
                    statusColor: _statusColor,
                    totalCount: materials.length,
                    scanCtrl: _scanCtrl,
                    scanFocus: _scanFocus,
                    onScanChanged: _onScanFieldChanged,
                    onScanSubmitted: _onScanFieldSubmitted,
                    onCameraOpen: _openCameraScanner,
                    onFilterTap: (s) => setState(
                      () => _statusFilter = _statusFilter == s ? null : s,
                    ),
                    onClearFilter: () => setState(() => _statusFilter = null),
                    onAddMaterial: () =>
                        _showAddMaterialDialog(context, materials),
                  ),
                  const SizedBox(height: 12),

                  // ── Table panel ────────────────────────────────────────
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _Glass.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _Glass.borderMid,
                            width: 0.8,
                          ),
                          boxShadow: const [_Glass.rowShadow],
                        ),
                        child: Column(
                          children: [
                            if (isWide)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xF2F4F6F8),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _Glass.borderMid,
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                                child: const _TableHeader(),
                              ),
                            Expanded(
                              child: filtered.isEmpty
                                  ? Center(
                                      child: Text(
                                        _statusFilter != null
                                            ? 'No materials with status "$_statusFilter"'
                                            : 'No materials found',
                                        style: const TextStyle(
                                          color: _Glass.textMuted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.fromLTRB(
                                        0,
                                        0,
                                        0,
                                        isWide ? 0 : 20,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (_, i) {
                                        final m = filtered[i];
                                        return isWide
                                            ? _TableRow(
                                                data: m,
                                                isLast:
                                                    i == filtered.length - 1,
                                                statusColor: _statusColor(
                                                  m['_status'] as String,
                                                ),
                                                onEdit: () =>
                                                    _showReplenishDialog(
                                                      m['doc_id'] as String,
                                                      m,
                                                      method: 'manual',
                                                    ),
                                              )
                                            : _MaterialCard(
                                                data: m,
                                                statusColor: _statusColor(
                                                  m['_status'] as String,
                                                ),
                                                onEdit: () =>
                                                    _showReplenishDialog(
                                                      m['doc_id'] as String,
                                                      m,
                                                      method: 'manual',
                                                    ),
                                              );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
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

// =============================================================================
// Top Panel
// =============================================================================
class _TopPanel extends StatelessWidget {
  final bool isWide;
  final List<String> statuses;
  final Map<String, int> counts;
  final String? statusFilter;
  final Color Function(String) statusColor;
  final int totalCount;
  final TextEditingController scanCtrl;
  final FocusNode scanFocus;
  final void Function(String) onScanChanged;
  final void Function(String) onScanSubmitted;
  final VoidCallback onCameraOpen;
  final void Function(String) onFilterTap;
  final VoidCallback onClearFilter;
  final VoidCallback onAddMaterial;

  const _TopPanel({
    required this.isWide,
    required this.statuses,
    required this.counts,
    required this.statusFilter,
    required this.statusColor,
    required this.totalCount,
    required this.scanCtrl,
    required this.scanFocus,
    required this.onScanChanged,
    required this.onScanSubmitted,
    required this.onCameraOpen,
    required this.onFilterTap,
    required this.onClearFilter,
    required this.onAddMaterial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _Glass.surfaceMid,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Add button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Update raw material stock',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _GlassButton(
                label: isWide ? 'Add Material' : '',
                icon: Icons.add_rounded,
                isPrimary: true,
                onPressed: onAddMaterial,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scan bar
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _Glass.surfaceThin,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Glass.borderMid, width: 0.8),
                  ),
                  child: TextField(
                    controller: scanCtrl,
                    focusNode: scanFocus,
                    style: const TextStyle(
                      color: _Glass.textPrimary,
                      fontSize: 13,
                    ),
                    onChanged: onScanChanged,
                    onSubmitted: onScanSubmitted,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: kIsWeb
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
              if (!kIsWeb) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onCameraOpen,
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _Glass.surfaceThin,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _Glass.borderMid, width: 0.8),
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
          const SizedBox(height: 14),

          // Summary filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SummaryCard(
                  status: 'All',
                  count: totalCount,
                  color: _Glass.textSecondary,
                  isActive: statusFilter == null,
                  onTap: onClearFilter,
                ),
                ...statuses.map(
                  (s) => _SummaryCard(
                    status: s,
                    count: counts[s] ?? 0,
                    color: statusColor(s),
                    isActive: statusFilter == s,
                    onTap: () => onFilterTap(s),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Table header
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
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 74, child: Text('Code', style: _h)),
          Expanded(child: Text('Material Name', style: _h)),
          SizedBox(
            width: 72,
            child: Text('Stock', style: _h, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 80,
            child: Text('Restock At', style: _h, textAlign: TextAlign.center),
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
}

// =============================================================================
// Table row (wide)
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
    final id = data['material_id']?.toString() ?? '';
    final name = data['material_name']?.toString() ?? '';
    final unit = data['unit_description']?.toString() ?? '';
    final current = (data['current_stock'] as num?) ?? 0;
    final restock = (data['restock_level'] as num?) ?? 0;
    final status = data['_status']?.toString() ?? '';

    String fmt(num v) =>
        v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _Glass.borderMid, width: 0.8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              id,
              style: const TextStyle(
                color: _Glass.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: _Glass.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              fmt(current),
              style: const TextStyle(
                color: _Glass.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              fmt(restock),
              style: const TextStyle(color: _Glass.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x0D1A1A2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _Glass.borderMid, width: 0.8),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: _Glass.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
// Material card (narrow / mobile)
// =============================================================================
class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final VoidCallback onEdit;

  const _MaterialCard({
    required this.data,
    required this.statusColor,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final id = data['material_id']?.toString() ?? '';
    final name = data['material_name']?.toString() ?? '';
    final unit = data['unit_description']?.toString() ?? '';
    final current = (data['current_stock'] as num?) ?? 0;
    final restock = (data['restock_level'] as num?) ?? 0;
    final status = data['_status']?.toString() ?? '';

    String fmt(num v) =>
        v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      id,
                      style: const TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    unit,
                    style: const TextStyle(
                      color: _Glass.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StockInfo(label: 'Stock', value: fmt(current)),
                    const SizedBox(width: 20),
                    _StockInfo(label: 'Restock at', value: fmt(restock)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xDD1A1A2E),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x44FFFFFF), width: 0.8),
                boxShadow: const [_Glass.rowShadow],
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
// Summary card
// =============================================================================
class _SummaryCard extends StatelessWidget {
  final String status;
  final int count;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.status,
    required this.count,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xEE1A1A2E) : _Glass.surfaceMid,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0x44FFFFFF) : _Glass.borderMid,
            width: 0.8,
          ),
          boxShadow: [_Glass.rowShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 0.8,
              height: 22,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : _Glass.borderMid,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.85)
                        : color.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.9)
                        : _Glass.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
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
// Shared glass widgets
// =============================================================================

class _GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GlassButton({
    required this.label,
    this.icon,
    required this.isPrimary,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xDD1A1A2E) : _Glass.surfaceThin,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isPrimary ? const Color(0x44FFFFFF) : _Glass.borderMid,
            width: 0.8,
          ),
          boxShadow: [_Glass.rowShadow],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isPrimary ? Colors.white : _Glass.textSecondary,
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                size: 14,
                color: isPrimary ? Colors.white : _Glass.textSecondary,
              ),
            if ((icon != null || isLoading) && label.isNotEmpty)
              const SizedBox(width: 6),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.white : _Glass.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _GlassField({
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(color: _Glass.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _Glass.textSecondary, fontSize: 12),
        prefixIcon: icon != null
            ? Icon(icon, size: 16, color: _Glass.textMuted)
            : null,
        filled: true,
        fillColor: _Glass.surfaceThin,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _Glass.borderMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        errorStyle: const TextStyle(fontSize: 10),
      ),
    );
  }
}

class _StockInfo extends StatelessWidget {
  final String label;
  final String value;
  const _StockInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _Glass.textMuted, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _Glass.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// QR Camera Scanner Page
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
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
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
                border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
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
