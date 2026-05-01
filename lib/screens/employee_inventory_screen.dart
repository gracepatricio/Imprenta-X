import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'app_theme.dart';

class EmployeeInventoryScreen extends StatefulWidget {
  const EmployeeInventoryScreen({super.key});

  @override
  State<EmployeeInventoryScreen> createState() =>
      _EmployeeInventoryScreenState();
}

class _EmployeeInventoryScreenState extends State<EmployeeInventoryScreen> {
  final _scanCtrl = TextEditingController();
  final _scanFocus = FocusNode();

  String? _statusFilter;
  String _employeeName = '';
  String _employeeUid = '';

  static const _statuses = ['In Stock', 'Low Stock', 'Critical', 'Out of Stock'];

  @override
  void initState() {
    super.initState();
    _loadEmployee();
    // On web, auto-focus the scan field so physical USB/Bluetooth scanners
    // can type directly into it without the user needing to click first.
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
        _employeeName = doc.data()?['full_name'] ?? user.displayName ?? 'Employee';
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
        return const Color(0xFF4CAF50);
      case 'Low Stock':
        return const Color(0xFFFFB300);
      case 'Critical':
        return const Color(0xFFFF6D00);
      default:
        return const Color(0xFFF44336);
    }
  }

  // Called when user submits text in scan field or camera detects code
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Material "$code" not found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _showReplenishDialog(
        snap.id,
        snap.data() as Map<String, dynamic>,
        method: fromCamera ? 'qr_scan' : 'manual',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _showReplenishDialog(
      String docId, Map<String, dynamic> material, {required String method}) {
    final qtyCtrl = TextEditingController();
    final name = material['material_name']?.toString() ?? '';
    final unit = material['unit_description']?.toString() ?? '';
    final current = (material['current_stock'] as num?) ?? 0;
    bool saving = false;

    String fmt(num v) =>
        v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(2);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          title: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Replenish Stock',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      if (unit.isNotEmpty)
                        Text(unit,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('Current stock: ',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          Text(fmt(current),
                              style: const TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Quantity to add',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: AppTheme.inputDecoration('e.g. 2 or 0.5',
                      icon: Icons.add_circle_outline),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 6),
                    Text(_employeeName,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    const SizedBox(width: 12),
                    const Icon(Icons.qr_code_2,
                        color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Text(
                        method == 'qr_scan' ? 'QR Scan' : 'Manual',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final qty = double.tryParse(qtyCtrl.text.trim());
                      if (qty == null || qty <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid quantity > 0'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      setDlg(() => saving = true);
                      await _commitReplenish(
                          docId, material, qty, method, ctx);
                    },
              style: AppTheme.primaryButton(),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Confirm'),
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
        final ref =
            FirebaseFirestore.instance.collection('RawMaterials').doc(docId);
        final snap = await tx.get(ref);
        previousStock = ((snap.data()?['current_stock'] as num?) ?? 0).toDouble();
        newStock = previousStock + qty;

        tx.update(ref, {
          'current_stock': newStock,
          'last_updated': FieldValue.serverTimestamp(),
          'last_updated_by': _employeeName,
          'last_updated_by_uid': _employeeUid,
        });

        final logRef =
            FirebaseFirestore.instance.collection('InventoryLogs').doc();
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

      // Update product availability based on this material
      _refreshProductAvailability(materialId);

      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              '$materialName updated: +$qty → $newStock ${material['unit_description'] ?? ''}'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // After stock update, recalculate availability for products using this material
  Future<void> _refreshProductAvailability(String materialId) async {
    try {
      final products = await FirebaseFirestore.instance
          .collection('Products')
          .get();

      for (final doc in products.docs) {
        final data = doc.data();
        final bom = (data['bill_of_materials'] as List?) ?? [];
        final usesMaterial = bom.any((item) =>
            (item as Map)['material_id']?.toString() == materialId);
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
    } catch (_) {
      // Non-critical: availability refresh failure doesn't break the update
    }
  }

  // ── Add new raw material ─────────────────────────────────────────────────────

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
      BuildContext context, List<Map<String, dynamic>> materials) {
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_box_outlined, color: AppTheme.gold, size: 20),
              SizedBox(width: 8),
              Text('Add Raw Material',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: idCtrl,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: AppTheme.inputDecoration('Material ID',
                        icon: Icons.tag),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nameCtrl,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: AppTheme.inputDecoration('Material Name',
                        icon: Icons.inventory_2_outlined),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: unitCtrl,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: AppTheme.inputDecoration(
                        'Unit (e.g. 1 roll, 4x8ft sheet)',
                        icon: Icons.straighten),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: restockCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration:
                              AppTheme.inputDecoration('Restock at'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: stockCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration:
                              AppTheme.inputDecoration('Initial stock'),
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
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false))
                        return;
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
                        messenger.showSnackBar(SnackBar(
                          content: Text('$id added to inventory'),
                          backgroundColor: const Color(0xFF4CAF50),
                        ));
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red));
                        setDlg(() => saving = false);
                      }
                    },
              style: AppTheme.primaryButton(),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

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
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off_outlined,
                      size: 48, color: Colors.white38),
                  const SizedBox(height: 14),
                  const Text('Could not load inventory',
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Check your internet connection and try again',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 56, color: Colors.white24),
                SizedBox(height: 16),
                Text('No inventory data',
                    style:
                        TextStyle(color: Colors.white60, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Ask the admin to seed the initial materials',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 20, isWide ? 24 : 16, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Inventory',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            Text('Update raw material stock',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                      // Wide: full button; narrow: icon-only to prevent overflow
                      isWide
                          ? ElevatedButton.icon(
                              onPressed: () => _showAddMaterialDialog(
                                  context, materials),
                              icon: const Icon(Icons.add, size: 15),
                              label: const Text('Add Material',
                                  style: TextStyle(fontSize: 13)),
                              style: AppTheme.primaryButton(),
                            )
                          : ElevatedButton(
                              onPressed: () => _showAddMaterialDialog(
                                  context, materials),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.gold,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                minimumSize: const Size(40, 40),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Icon(Icons.add, size: 22),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Scan bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _scanCtrl,
                          focusNode: _scanFocus,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          onSubmitted: _handleScan,
                          decoration: AppTheme.inputDecoration(
                            kIsWeb
                                ? 'Physical scanner or type ID (e.g. RM-001) + Enter'
                                : 'Type material ID (e.g. RM-001) + Enter',
                            icon: Icons.qr_code_scanner,
                          ),
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      // Camera button — mobile only
                      if (!kIsWeb) ...[
                        const SizedBox(width: 10),
                        Tooltip(
                          message: 'Scan with camera',
                          child: ElevatedButton(
                            onPressed: _openCameraScanner,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Icon(Icons.camera_alt, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Status summary
                SizedBox(
                  height: 70,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 24 : 16),
                    children: _statuses
                        .map((s) => _SummaryCard(
                              status: s,
                              count: counts[s] ?? 0,
                              color: _statusColor(s),
                              isActive: _statusFilter == s,
                              onTap: () => setState(() => _statusFilter =
                                  _statusFilter == s ? null : s),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter chips
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 24 : 16),
                    children: [
                      _StatusChip(
                          label: 'All',
                          isActive: _statusFilter == null,
                          onTap: () =>
                              setState(() => _statusFilter = null)),
                      ..._statuses.map((s) => _StatusChip(
                            label: s,
                            color: _statusColor(s),
                            isActive: _statusFilter == s,
                            onTap: () => setState(() => _statusFilter =
                                _statusFilter == s ? null : s),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Table or card list
                if (isWide)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _InventoryTableHeader(showEdit: true),
                  ),
                if (isWide) const SizedBox(height: 4),

                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No materials with status "$_statusFilter"',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                              isWide ? 24 : 16, 0, isWide ? 24 : 16, 20),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            return isWide
                                ? _InventoryTableRow(
                                    data: m,
                                    statusColor: _statusColor(
                                        m['_status'] as String),
                                    onEdit: () => _showReplenishDialog(
                                        m['doc_id'] as String, m,
                                        method: 'manual'),
                                  )
                                : _InventoryCard(
                                    data: m,
                                    statusColor: _statusColor(
                                        m['_status'] as String),
                                    onEdit: () => _showReplenishDialog(
                                        m['doc_id'] as String, m,
                                        method: 'manual'),
                                  );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── QR Camera Scanner Page ────────────────────────────────────────────────────

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
    // Explicitly stop before dispose to release the camera hardware.
    // Without stop(), the OS camera session stays open and the next
    // scanner launch throws "max open allowed is 1".
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
              // Camera permission denied or hardware unavailable
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.white38, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        error.errorCode ==
                                MobileScannerErrorCode.permissionDenied
                            ? 'Camera permission denied.\nGo to Settings → Apps → Imprentax → Permissions.'
                            : 'Camera unavailable: ${error.errorDetails?.message ?? error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13),
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
          // Scan window overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.gold, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: const Text(
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

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String status;
  final int count;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _SummaryCard(
      {required this.status,
      required this.count,
      required this.color,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(count.toString(),
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(status,
                style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _StatusChip(
      {required this.label,
      required this.isActive,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.gold;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? c.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive
                  ? c.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? c : Colors.white60,
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

class _InventoryTableHeader extends StatelessWidget {
  final bool showEdit;
  const _InventoryTableHeader({this.showEdit = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 74, child: Text('Code', style: _h)),
          const Expanded(child: Text('Material Name', style: _h)),
          const SizedBox(width: 80, child: Text('Stock', style: _h, textAlign: TextAlign.center)),
          const SizedBox(width: 80, child: Text('Restock At', style: _h, textAlign: TextAlign.center)),
          const SizedBox(width: 96, child: Text('Status', style: _h, textAlign: TextAlign.center)),
          if (showEdit) const SizedBox(width: 60, child: Text('', style: _h)),
        ],
      ),
    );
  }

  static const _h = TextStyle(
      color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold);
}

class _InventoryTableRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final VoidCallback onEdit;

  const _InventoryTableRow(
      {required this.data,
      required this.statusColor,
      required this.onEdit});

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
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(id,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                if (unit.isNotEmpty)
                  Text(unit,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          SizedBox(
              width: 80,
              child: Text(fmt(current),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 80,
              child: Text(fmt(restock),
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center)),
          SizedBox(
            width: 96,
            child: Center(
              child: _StatusBadge(status: status, color: statusColor),
            ),
          ),
          SizedBox(
            width: 60,
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.gold,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text('Edit', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final VoidCallback onEdit;

  const _InventoryCard(
      {required this.data,
      required this.statusColor,
      required this.onEdit});

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(id,
                        style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontFamily: 'monospace')),
                    const SizedBox(width: 8),
                    _StatusBadge(status: status, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                if (unit.isNotEmpty)
                  Text(unit,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StockInfo(label: 'Stock', value: fmt(current)),
                    const SizedBox(width: 16),
                    _StockInfo(
                        label: 'Restock at', value: fmt(restock)),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
              foregroundColor: AppTheme.gold,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: AppTheme.gold.withValues(alpha: 0.4))),
            ),
            child: const Text('Edit', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
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
        Text(label,
            style:
                const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(value,
            style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
