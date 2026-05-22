import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_theme.dart';

// ── Breakpoint ────────────────────────────────────────────────────────────────
const double _kNarrow = 700.0;
const double _kTableMinWidth = 640.0;

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xEEFFFFFF);
  static const Color surfaceMid = Color(0xCCFFFFFF);
  static const Color surfaceThin = Color(0x99FFFFFF);
  static const Color surfaceRow = Color(0xBBFFFFFF);

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

// ── Sub-menu tab enum ─────────────────────────────────────────────────────────
enum _InventoryTab { inventory, forecast }

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

  Future<void> _seedInitialData() async {
    setState(() => _seeding = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance.collection('RawMaterials');
      for (final mat in _kInitialMaterials) {
        final ref = col.doc(mat['material_id'] as String);
        final docData = <String, dynamic>{
          ...mat,
          'current_stock': 0.0,
          'last_updated': null,
          'last_updated_by': '',
          'last_updated_by_uid': '',
        };
        // Remove null piece_to_sqft entries (pcs materials don't have it)
        if (!mat.containsKey('piece_to_sqft')) {
          docData.remove('piece_to_sqft');
        }
        batch.set(ref, docData);
      }
      await batch.commit();
      if (mounted)
        _snack(
          '29 raw materials seeded successfully',
          _statusColor('In Stock'),
        );
    } catch (e) {
      if (mounted) _snack('Seed error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Root build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubMenuTabBar(
          activeTab: _activeTab,
          onTabChanged: (tab) => setState(() => _activeTab = tab),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _activeTab == _InventoryTab.forecast
              ? const _ForecastTab()
              : _buildInventoryContent(),
        ),
      ],
    );
  }

  // ── Inventory content ───────────────────────────────────────────────────────
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
              color: _Glass.textPrimary.withValues(alpha: 0.5),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(seeding: _seeding, onSeed: _seedInitialData);
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
            final isNarrow = constraints.maxWidth < _kNarrow;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Constrain top panel to parent width
                SizedBox(
                  width: constraints.maxWidth,
                  child: _TopPanel(
                    isNarrow: isNarrow,
                    statuses: _statuses,
                    counts: counts,
                    statusFilter: _statusFilter,
                    statusColor: _statusColor,
                    seeding: _seeding,
                    onFilterTap: (s) => setState(
                      () => _statusFilter = _statusFilter == s ? null : s,
                    ),
                    onClearFilter: () => setState(() => _statusFilter = null),
                    onAddMaterial: () =>
                        _showAddMaterialDialog(context, materials),
                    onReseed: _seeding ? null : _seedInitialData,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // Constrain table panel to same parent width
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: _TablePanel(
                      isNarrow: isNarrow,
                      filtered: filtered,
                      statusColor: _statusColor,
                      statusFilter: _statusFilter,
                      onQrTap: (m) => _showQr(context, m),
                      onEditTap: (m) => _showAddMaterialDialog(
                        context,
                        materials,
                        existing: m,
                      ),
                      onDeleteTap: (m) => _confirmDelete(context, m),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

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
    List<Map<String, dynamic>> materials, {
    Map<String, dynamic>? existing,
  }) {
    final isEdit = existing != null;
    final suggestedId = isEdit
        ? (existing['material_id']?.toString() ?? '')
        : _nextMaterialId(materials);
    final idCtrl = TextEditingController(text: suggestedId);
    final nameCtrl = TextEditingController(
      text: existing?['material_name']?.toString() ?? '',
    );
    final unitCtrl = TextEditingController(
      text: existing?['unit_description']?.toString() ?? '',
    );
    final restockCtrl = TextEditingController(
      text: existing?['restock_level']?.toString() ?? '5',
    );
    final stockCtrl = TextEditingController(
      text: existing?['current_stock']?.toString() ?? '0',
    );
    final pieceSqftCtrl = TextEditingController(
      text: existing?['piece_to_sqft']?.toString() ?? '',
    );
    String stockUnit = existing?['stock_unit']?.toString() ?? 'pcs';
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
                child: Icon(
                  isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                  color: _Glass.textSecondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'Edit Raw Material' : 'Add Raw Material',
                style: const TextStyle(
                  color: _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassField(
                      controller: idCtrl,
                      label: 'Material ID',
                      icon: Icons.tag_rounded,
                      readOnly: isEdit,
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
                      label: 'Unit description (e.g. 1 roll, 4×8ft sheet)',
                      icon: Icons.straighten_rounded,
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    // ── Stock Unit ─────────────────────────────────────────────
                    const Text(
                      'STOCK UNIT',
                      style: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _Glass.surfaceThin,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _Glass.borderMid, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // sqft option
                          GestureDetector(
                            onTap: () => setDlg(() => stockUnit = 'sqft'),
                            child: Row(
                              children: [
                                Icon(
                                  stockUnit == 'sqft'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: stockUnit == 'sqft'
                                      ? AppTheme.gold
                                      : _Glass.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'sqft  (area — for rolls & sheets)',
                                      style: TextStyle(
                                        color: _Glass.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Stock tracks total sq ft remaining',
                                      style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // pcs option
                          GestureDetector(
                            onTap: () => setDlg(() => stockUnit = 'pcs'),
                            child: Row(
                              children: [
                                Icon(
                                  stockUnit == 'pcs'
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: stockUnit == 'pcs'
                                      ? AppTheme.gold
                                      : _Glass.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'pcs  (pieces / units / bottles)',
                                      style: TextStyle(
                                        color: _Glass.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Stock tracks discrete count',
                                      style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // sqft-per-piece field shown only when sqft is selected
                          if (stockUnit == 'sqft') ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: _Glass.borderDim),
                            const SizedBox(height: 10),
                            const Text(
                              'Sqft per piece (for replenishment conversion)',
                              style: TextStyle(
                                color: _Glass.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'e.g. 1722.44 for a 10.5ft×50m tarpaulin roll, '
                              '32 for a 4×8ft sheet.',
                              style: TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: pieceSqftCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: const TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. 1722.44',
                                hintStyle: const TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: _Glass.surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                    color: _Glass.borderMid,
                                    width: 0.8,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppTheme.gold.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                if (double.tryParse(v.trim()) == null) {
                                  return 'Invalid number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Restock level + Initial stock ──────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _GlassField(
                            controller: restockCtrl,
                            label: 'Restock at (${stockUnit == 'sqft' ? 'sqft' : 'pcs'})',
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
                            label: 'Initial stock (${stockUnit == 'sqft' ? 'sqft' : 'pcs'})',
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
              label: isEdit ? 'Save' : 'Add',
              isPrimary: true,
              isLoading: saving,
              onPressed: saving
                  ? null
                  : () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      setDlg(() {});
                      if (!isValid) return;
                      setDlg(() => saving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final id = idCtrl.text.trim();
                        final pieceSqft = pieceSqftCtrl.text.trim().isNotEmpty
                            ? double.tryParse(pieceSqftCtrl.text.trim())
                            : null;
                        await FirebaseFirestore.instance
                            .collection('RawMaterials')
                            .doc(id)
                            .set({
                              'material_id': id,
                              'material_name': nameCtrl.text.trim(),
                              'unit_description': unitCtrl.text.trim(),
                              'stock_unit': stockUnit,
                              if (pieceSqft != null) 'piece_to_sqft': pieceSqft,
                              'restock_level':
                                  double.tryParse(restockCtrl.text) ?? 5.0,
                              'current_stock':
                                  double.tryParse(stockCtrl.text) ?? 0.0,
                              if (!isEdit) ...{
                                'last_updated': null,
                                'last_updated_by': '',
                                'last_updated_by_uid': '',
                              },
                            }, SetOptions(merge: isEdit));
                        if (ctx.mounted) Navigator.pop(ctx);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              isEdit
                                  ? '$id updated'
                                  : '$id added to inventory',
                            ),
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

  void _confirmDelete(BuildContext context, Map<String, dynamic> m) {
    final docId = m['doc_id']?.toString() ?? '';
    final name = m['material_name']?.toString() ?? docId;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) => AlertDialog(
        backgroundColor: _Glass.surface,
        elevation: 32,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _Glass.borderMid, width: 1),
        ),
        title: const Text(
          'Delete Material',
          style: TextStyle(
            color: _Glass.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Delete "$name"? This cannot be undone and will also remove it from any bill of materials.',
          style: const TextStyle(color: _Glass.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _Glass.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await FirebaseFirestore.instance
                    .collection('RawMaterials')
                    .doc(docId)
                    .delete();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('"$name" deleted'),
                    backgroundColor: Colors.red.shade700,
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
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600.withValues(alpha: 0.85),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
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
          side: BorderSide(color: _Glass.borderMid, width: 1),
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
                border: Border.all(color: _Glass.borderMid, width: 1),
                boxShadow: const [_Glass.rowShadow],
              ),
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: m['material_id']?.toString() ?? 'NO-ID',
                version: QrVersions.auto,
                size: 180,
                gapless: false,
                backgroundColor: Colors.white,
                errorStateBuilder: (ctx, err) => const Center(
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _Glass.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Top Panel
// =============================================================================
class _TopPanel extends StatelessWidget {
  final bool isNarrow;
  final List<String> statuses;
  final Map<String, int> counts;
  final String? statusFilter;
  final Color Function(String) statusColor;
  final bool seeding;
  final void Function(String) onFilterTap;
  final VoidCallback onClearFilter;
  final VoidCallback onAddMaterial;
  final VoidCallback? onReseed;

  const _TopPanel({
    required this.isNarrow,
    required this.statuses,
    required this.counts,
    required this.statusFilter,
    required this.statusColor,
    required this.seeding,
    required this.onFilterTap,
    required this.onClearFilter,
    required this.onAddMaterial,
    required this.onReseed,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = counts.values.fold(0, (a, b) => a + b);

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
          if (isNarrow) ...[
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory',
                  style: TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Raw materials — view and adjust stock',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _GlassButton(
                  label: 'Add Material',
                  icon: Icons.add_rounded,
                  isPrimary: true,
                  onPressed: onAddMaterial,
                ),
                const SizedBox(width: 8),
                _GlassButton(
                  label: 'Re-seed',
                  icon: Icons.refresh_rounded,
                  isPrimary: false,
                  isLoading: seeding,
                  onPressed: onReseed,
                ),
              ],
            ),
          ] else ...[
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
                        'Raw materials — view and adjust stock',
                        style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                _GlassButton(
                  label: 'Add Material',
                  icon: Icons.add_rounded,
                  isPrimary: true,
                  onPressed: onAddMaterial,
                ),
                const SizedBox(width: 8),
                _GlassButton(
                  label: 'Re-seed',
                  icon: Icons.refresh_rounded,
                  isPrimary: false,
                  isLoading: seeding,
                  onPressed: onReseed,
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),

          // ── Summary cards (with "All" prepended) ─────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All" card
                _SummaryCard(
                  status: 'All',
                  count: totalCount,
                  color: _Glass.textSecondary,
                  isActive: statusFilter == null,
                  onTap: onClearFilter,
                ),
                // Per-status cards
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
// Table Panel — fixed responsiveness: ClipRRect + clamped scroll width
// =============================================================================
class _TablePanel extends StatelessWidget {
  final bool isNarrow;
  final List<Map<String, dynamic>> filtered;
  final Color Function(String) statusColor;
  final String? statusFilter;
  final void Function(Map<String, dynamic>) onQrTap;
  final void Function(Map<String, dynamic>) onDeleteTap;
  final void Function(Map<String, dynamic>) onEditTap;

  const _TablePanel({
    required this.isNarrow,
    required this.filtered,
    required this.statusColor,
    required this.statusFilter,
    required this.onQrTap,
    required this.onDeleteTap,
    required this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: _Glass.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _Glass.borderMid, width: 0.8),
          boxShadow: const [_Glass.rowShadow],
        ),
        child: Column(
          children: [
            // ── Sticky header ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: const Color(0xF2F4F6F8),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                border: Border(
                  bottom: BorderSide(color: _Glass.borderMid, width: 0.8),
                ),
              ),
              child: isNarrow
                  ? LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _kTableMinWidth.clamp(
                            c.maxWidth,
                            double.infinity,
                          ),
                          child: const _TableHeader(),
                        ),
                      ),
                    )
                  : const _TableHeader(),
            ),

            // ── Rows ────────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        statusFilter != null
                            ? 'No materials with status "$statusFilter"'
                            : 'No materials found',
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : isNarrow
                  ? LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _kTableMinWidth.clamp(
                            c.maxWidth,
                            double.infinity,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _MaterialRow(
                              data: filtered[i],
                              isLast: i == filtered.length - 1,
                              statusColor: statusColor(
                                filtered[i]['_status'] as String,
                              ),
                              onQrTap: () => onQrTap(filtered[i]),
                              onEditTap: () => onEditTap(filtered[i]),
                              onDeleteTap: () => onDeleteTap(filtered[i]),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _MaterialRow(
                        data: filtered[i],
                        isLast: i == filtered.length - 1,
                        statusColor: statusColor(
                          filtered[i]['_status'] as String,
                        ),
                        onQrTap: () => onQrTap(filtered[i]),
                        onEditTap: () => onEditTap(filtered[i]),
                        onDeleteTap: () => onDeleteTap(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-menu tab bar
// =============================================================================
class _SubMenuTabBar extends StatelessWidget {
  final _InventoryTab activeTab;
  final ValueChanged<_InventoryTab> onTabChanged;

  const _SubMenuTabBar({required this.activeTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SubMenuTab(
            label: 'Inventory',
            icon: Icons.inventory_2_outlined,
            isActive: activeTab == _InventoryTab.inventory,
            onTap: () => onTabChanged(_InventoryTab.inventory),
          ),
          const SizedBox(width: 4),
          _SubMenuTab(
            label: 'Forecast',
            icon: Icons.trending_up_rounded,
            isActive: activeTab == _InventoryTab.forecast,
            onTap: () => onTabChanged(_InventoryTab.forecast),
          ),
        ],
      ),
    );
  }
}

class _SubMenuTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SubMenuTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xEE1A1A2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0x33FFFFFF) : Colors.transparent,
            width: 0.8,
          ),
          boxShadow: isActive ? const [_Glass.rowShadow] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : _Glass.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : _Glass.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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
// DES algorithm — top-level function
// =============================================================================

// Double Exponential Smoothing (Holt's linear method)
// Returns forecast for 1 period ahead, clamped >= 0
Map<String, double> _applyDES(
  List<double> series, {
  double alpha = 0.3,
  double beta = 0.1,
}) {
  if (series.isEmpty) return {'forecast': 0.0, 'trend': 0.0};

  // Use non-zero values to compute a better initial estimate
  final nonZero = series.where((v) => v > 0).toList();
  if (nonZero.isEmpty) return {'forecast': 0.0, 'trend': 0.0};
  if (nonZero.length == 1) return {'forecast': nonZero[0], 'trend': 0.0};

  double L = series[0];
  double T = 0.0;
  // Init trend from first two non-flat values
  for (int i = 1; i < series.length; i++) {
    if (series[i] != series[i - 1]) {
      T = (series[i] - series[i - 1]) * 0.5; // damped init
      break;
    }
  }

  for (int i = 1; i < series.length; i++) {
    final prevL = L;
    L = alpha * series[i] + (1 - alpha) * (prevL + T);
    T = beta * (L - prevL) + (1 - beta) * T;
  }
  return {
    'forecast': (L + T).clamp(0.0, double.maxFinite),
    'trend': T,
  };
}

// =============================================================================
// Material forecast data model
// =============================================================================
class _MaterialForecast {
  final String materialId;
  final String docId;
  final String materialName;
  final String stockUnit;
  final double? pieceToSqft;
  final double currentStock;
  final double currentRestockLevel;
  final double avgMonthlyUsage;
  final double forecastNextMonth;
  final double suggestedRestockLevel;
  final List<double> monthlyData;

  const _MaterialForecast({
    required this.materialId,
    required this.docId,
    required this.materialName,
    required this.stockUnit,
    required this.pieceToSqft,
    required this.currentStock,
    required this.currentRestockLevel,
    required this.avgMonthlyUsage,
    required this.forecastNextMonth,
    required this.suggestedRestockLevel,
    required this.monthlyData,
  });
}

// =============================================================================
// Forecast tab
// =============================================================================
class _ForecastTab extends StatefulWidget {
  const _ForecastTab();

  @override
  State<_ForecastTab> createState() => _ForecastTabState();
}

class _ForecastTabState extends State<_ForecastTab> {
  static const double _alpha = 0.3;
  static const double _beta = 0.1;
  static const double _safetyFactor = 1.5;
  static const int _months = 12;

  bool _loading = true;
  String? _error;
  List<_MaterialForecast> _forecasts = [];
  DateTime _lastComputed = DateTime.now();

  @override
  void initState() {
    super.initState();
    _compute();
  }

  String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _compute() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final cutoff = DateTime(now.year, now.month - (_months - 1), 1);

      // Fetch orders (completed + ready + in_production)
      final ordersSnap = await FirebaseFirestore.instance
          .collection('Orders')
          .where('status', whereIn: ['completed', 'ready', 'in_production'])
          .where(
            'created_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
          )
          .get();

      // Fetch all products for BOM lookup
      final productsSnap = await FirebaseFirestore.instance
          .collection('Products')
          .get();

      // Fetch all raw materials
      final materialsSnap = await FirebaseFirestore.instance
          .collection('RawMaterials')
          .orderBy('material_id')
          .get();

      // Build product BOM map (keyed by doc id AND product_id field)
      final productBomMap = <String, List<Map<String, dynamic>>>{};
      for (final doc in productsSnap.docs) {
        final data = doc.data();
        final bom = List<Map<String, dynamic>>.from(
          ((data['bill_of_materials'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        productBomMap[doc.id] = bom;
        final pid = data['product_id']?.toString() ?? '';
        if (pid.isNotEmpty && pid != doc.id) productBomMap[pid] = bom;
      }

      // Build material monthly consumption map
      // material_id → month_key → total_consumed
      final Map<String, Map<String, double>> materialMonthly = {};

      for (final orderDoc in ordersSnap.docs) {
        final orderData = orderDoc.data();
        final createdAt = orderData['created_at'] as Timestamp?;
        if (createdAt == null) continue;
        final month = _monthKey(createdAt.toDate());

        final products = List<Map<String, dynamic>>.from(
          ((orderData['products'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );

        for (final p in products) {
          final productId = p['product_id']?.toString() ?? '';
          if (productId.isEmpty) continue;
          final bom = productBomMap[productId] ?? [];
          if (bom.isEmpty) continue;

          final qty = (p['qty'] as num?)?.toDouble() ?? 1.0;
          final widthFt = (p['width_ft'] as num?)?.toDouble();
          final heightFt = (p['height_ft'] as num?)?.toDouble();
          final selectedMaterial = p['material']?.toString();

          // Effective order quantity in the material's tracking unit
          final effectiveQty = (widthFt != null && heightFt != null)
              ? widthFt * heightFt * qty
              : qty;

          // Filter BOM by material option (same logic as InventoryService)
          for (final bomItem in bom) {
            final forOpt = bomItem['for_material_option']?.toString() ?? '';
            if (forOpt.isNotEmpty && forOpt != (selectedMaterial ?? ''))
              continue;
            final matId = bomItem['material_id']?.toString() ?? '';
            if (matId.isEmpty) continue;
            final qpu =
                (bomItem['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
            materialMonthly.putIfAbsent(matId, () => {});
            materialMonthly[matId]![month] =
                (materialMonthly[matId]![month] ?? 0) + effectiveQty * qpu;
          }
        }
      }

      // Build ordered month keys (oldest to newest)
      final monthKeys = List.generate(
        _months,
        (i) =>
            _monthKey(DateTime(now.year, now.month - (_months - 1 - i), 1)),
      );

      // Compute DES forecast per material
      final forecasts = <_MaterialForecast>[];
      for (final matDoc in materialsSnap.docs) {
        final matData = matDoc.data();
        final matId = matData['material_id']?.toString() ?? matDoc.id;
        final matName = matData['material_name']?.toString() ?? '';
        final stockUnit = matData['stock_unit']?.toString() ?? 'pcs';
        final pieceToSqft = (matData['piece_to_sqft'] as num?)?.toDouble();
        final currentStock =
            (matData['current_stock'] as num?)?.toDouble() ?? 0.0;
        final currentRestock =
            (matData['restock_level'] as num?)?.toDouble() ?? 0.0;

        final monthly = materialMonthly[matId] ?? {};
        final series = monthKeys.map((k) => monthly[k] ?? 0.0).toList();

        final nonZeroValues = series.where((v) => v > 0);
        final avgMonthly = nonZeroValues.isEmpty
            ? 0.0
            : nonZeroValues.reduce((a, b) => a + b) / nonZeroValues.length;

        final des = _applyDES(series, alpha: _alpha, beta: _beta);
        final forecast = des['forecast']!;
        final suggested = forecast * _safetyFactor;

        forecasts.add(_MaterialForecast(
          materialId: matId,
          docId: matDoc.id,
          materialName: matName,
          stockUnit: stockUnit,
          pieceToSqft: pieceToSqft,
          currentStock: currentStock,
          currentRestockLevel: currentRestock,
          avgMonthlyUsage: avgMonthly,
          forecastNextMonth: forecast,
          suggestedRestockLevel: suggested,
          monthlyData: series,
        ));
      }

      // Sort: materials with usage first (desc forecast), then zero-forecast alphabetically
      forecasts.sort((a, b) {
        if (a.forecastNextMonth == 0 && b.forecastNextMonth > 0) return 1;
        if (b.forecastNextMonth == 0 && a.forecastNextMonth > 0) return -1;
        return b.forecastNextMonth.compareTo(a.forecastNextMonth);
      });

      if (mounted) {
        setState(() {
          _forecasts = forecasts;
          _loading = false;
          _lastComputed = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _applyRestock(String docId, double value) async {
    await FirebaseFirestore.instance
        .collection('RawMaterials')
        .doc(docId)
        .update({'restock_level': value});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Restock level updated'),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String _fmtQty(double v, String stockUnit, double? pieceToSqft) {
    if (v == 0) return '—';
    final s = v < 10 ? v.toStringAsFixed(1) : v.toStringAsFixed(0);
    if (stockUnit == 'sqft' && pieceToSqft != null && pieceToSqft > 0) {
      final pieces = v / pieceToSqft;
      final pLabel = pieces < 2 ? 'roll/sheet' : 'rolls/sheets';
      final pStr =
          pieces < 10 ? pieces.toStringAsFixed(2) : pieces.toStringAsFixed(1);
      return '$s sqft\n(≈$pStr $pLabel)';
    }
    return '$s $stockUnit';
  }

  String _timeLabel(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header panel ──────────────────────────────────────────────────────
        Container(
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demand Forecast',
                          style: TextStyle(
                            color: _Glass.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Double Exponential Smoothing · α=0.3  β=0.1  ·  Safety buffer ×1.5',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                              width: 0.8,
                            ),
                          ),
                          child: const Text(
                            'Based on last 12 months of completed orders',
                            style: TextStyle(
                              color: Color(0xFF1565C0),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _GlassButton(
                        label: 'Refresh',
                        icon: Icons.refresh_rounded,
                        isPrimary: false,
                        isLoading: _loading,
                        onPressed: _loading ? null : _compute,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Last computed: ${_timeLabel(_lastComputed)}',
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Main content area ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _Glass.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _Glass.borderMid, width: 0.8),
              boxShadow: const [_Glass.rowShadow],
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: _Glass.textMuted,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error: $_error',
                            style: const TextStyle(
                              color: _Glass.textSecondary,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          _GlassButton(
                            label: 'Retry',
                            icon: Icons.refresh_rounded,
                            isPrimary: true,
                            onPressed: _compute,
                          ),
                        ],
                      ),
                    ),
                  )
                : _forecasts.every((f) => f.forecastNextMonth == 0)
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No order history found — forecasts will appear after orders are completed',
                        style: TextStyle(
                          color: _Glass.textSecondary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // ── Table header ─────────────────────────────────────────
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
                        child: const _ForecastTableHeader(),
                      ),
                      // ── Table rows ────────────────────────────────────────────
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: _forecasts.length,
                          itemBuilder: (_, i) {
                            final f = _forecasts[i];
                            return _ForecastRow(
                              forecast: f,
                              isLast: i == _forecasts.length - 1,
                              fmtQty: _fmtQty,
                              onApply: f.suggestedRestockLevel > 0
                                  ? () => _applyRestock(
                                      f.docId,
                                      f.suggestedRestockLevel,
                                    )
                                  : null,
                            );
                          },
                        ),
                      ),
                      // ── Footer note ───────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: _Glass.borderMid, width: 0.8),
                          ),
                        ),
                        child: const Text(
                          'Restock level = DES forecast for next month × 1.5 safety factor. '
                          'Apply to update the restock threshold for that material.',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 10.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Forecast table header
// =============================================================================
class _ForecastTableHeader extends StatelessWidget {
  const _ForecastTableHeader();

  static const _h = TextStyle(
    color: _Glass.textSecondary,
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Material', style: _h)),
          SizedBox(
            width: 90,
            child: Text('Avg/mo', style: _h, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'Forecast (next mo)',
              style: _h,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'Current Stock',
              style: _h,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              'Suggested Restock',
              style: _h,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 70, child: Text('Action', style: _h, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// =============================================================================
// Forecast row
// =============================================================================
class _ForecastRow extends StatelessWidget {
  final _MaterialForecast forecast;
  final bool isLast;
  final String Function(double, String, double?) fmtQty;
  final VoidCallback? onApply;

  const _ForecastRow({
    required this.forecast,
    required this.isLast,
    required this.fmtQty,
    required this.onApply,
  });

  Color _suggestedColor() {
    final suggested = forecast.suggestedRestockLevel;
    final current = forecast.currentStock;
    if (suggested == 0) return _Glass.textMuted;
    if (current >= suggested) return const Color(0xFF2E7D32);
    if (current >= suggested * 0.5) return const Color(0xFFF57F17);
    return const Color(0xFFC62828);
  }

  bool _isAlreadyApplied() {
    final suggested = forecast.suggestedRestockLevel;
    final current = forecast.currentRestockLevel;
    if (suggested == 0) return false;
    return (current - suggested).abs() / suggested < 0.05;
  }

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final sugColor = _suggestedColor();
    final alreadyApplied = _isAlreadyApplied();

    Widget qtyCell(String text, {Color? color}) {
      final lines = text.split('\n');
      if (lines.length > 1) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              lines[0],
              style: TextStyle(
                color: color ?? _Glass.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              lines[1],
              style: const TextStyle(color: _Glass.textMuted, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }
      return Text(
        text,
        style: TextStyle(
          color: color ?? _Glass.textPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _Glass.borderMid, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Material name + ID
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.materialName,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  f.materialId,
                  style: const TextStyle(
                    color: _Glass.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          // Avg/mo
          SizedBox(
            width: 90,
            child: Center(
              child: qtyCell(
                fmtQty(f.avgMonthlyUsage, f.stockUnit, f.pieceToSqft),
                color: _Glass.textSecondary,
              ),
            ),
          ),
          // Forecast next month
          SizedBox(
            width: 110,
            child: Center(
              child: f.forecastNextMonth == 0
                  ? const Text(
                      'No data',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                      textAlign: TextAlign.center,
                    )
                  : qtyCell(
                      fmtQty(
                        f.forecastNextMonth,
                        f.stockUnit,
                        f.pieceToSqft,
                      ),
                    ),
            ),
          ),
          // Current stock
          SizedBox(
            width: 100,
            child: Center(
              child: qtyCell(
                fmtQty(f.currentStock, f.stockUnit, f.pieceToSqft),
                color: _Glass.textSecondary,
              ),
            ),
          ),
          // Suggested restock (color coded)
          SizedBox(
            width: 110,
            child: Center(
              child: f.suggestedRestockLevel == 0
                  ? const Text(
                      '—',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    )
                  : qtyCell(
                      fmtQty(
                        f.suggestedRestockLevel,
                        f.stockUnit,
                        f.pieceToSqft,
                      ),
                      color: sugColor,
                    ),
            ),
          ),
          // Action button
          SizedBox(
            width: 70,
            child: Center(
              child: alreadyApplied
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    )
                  : onApply != null
                  ? GestureDetector(
                      onTap: onApply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDD1A1A2E),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: const Color(0x44FFFFFF),
                            width: 0.8,
                          ),
                          boxShadow: const [_Glass.rowShadow],
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
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
            if (icon != null || isLoading) const SizedBox(width: 6),
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
  final bool readOnly;

  const _GlassField({
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? _Glass.textMuted : _Glass.textPrimary,
        fontSize: 13,
      ),
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
          borderSide: BorderSide(color: AppTheme.gold.withValues(alpha: 0.7)),
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

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool seeding;
  final VoidCallback onSeed;
  const _EmptyState({required this.seeding, required this.onSeed});

  @override
  Widget build(BuildContext context) {
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
            'Seed the 29 initial raw materials to get started',
            style: TextStyle(color: _Glass.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _GlassButton(
            label: 'Seed Initial Materials',
            icon: Icons.add_box_outlined,
            isPrimary: true,
            isLoading: seeding,
            onPressed: seeding ? null : onSeed,
          ),
        ],
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────
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

// ── Table header ──────────────────────────────────────────────────────────────
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
            width: 90,
            child: Text('Stock', style: _h, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 90,
            child: Text('Restock At', style: _h, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 90,
            child: Text('Status', style: _h, textAlign: TextAlign.center),
          ),
          SizedBox(width: 84),
        ],
      ),
    );
  }
}

// ── Material row ──────────────────────────────────────────────────────────────
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
    final id = data['material_id']?.toString() ?? '';
    final name = data['material_name']?.toString() ?? '';
    final unit = data['unit_description']?.toString() ?? '';
    final stockUnit = data['stock_unit']?.toString() ?? 'pcs';
    final pieceToSqft = (data['piece_to_sqft'] as num?)?.toDouble();
    final current = (data['current_stock'] as num?) ?? 0;
    final restock = (data['restock_level'] as num?) ?? 0;
    final status = data['_status']?.toString() ?? '';

    // Determine piece label from unit_description
    String pieceLabel() {
      final ud = unit.toLowerCase();
      if (ud.contains('roll')) return 'rolls';
      if (ud.contains('sheet')) return 'sheets';
      return 'pcs';
    }

    // Format a stock value — shows sqft + piece equivalent when applicable
    Widget fmtWidget(num v, {bool isPrimary = true}) {
      final numVal = v.toDouble();
      if (stockUnit == 'sqft' && pieceToSqft != null && pieceToSqft > 0) {
        final sqftStr = numVal == numVal.toInt()
            ? numVal.toInt().toString()
            : numVal.toStringAsFixed(1);
        final pieces = numVal / pieceToSqft;
        final piecesStr = pieces < 10
            ? pieces.toStringAsFixed(1)
            : pieces.toStringAsFixed(0);
        final pLabel = pieceLabel();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '$sqftStr sqft',
              style: TextStyle(
                color: isPrimary ? _Glass.textPrimary : _Glass.textSecondary,
                fontSize: isPrimary ? 12 : 11,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '≈$piecesStr $pLabel',
              style: const TextStyle(
                color: _Glass.textMuted,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }
      // pcs or sqft without piece_to_sqft
      final s = numVal == numVal.toInt()
          ? numVal.toInt().toString()
          : numVal.toStringAsFixed(1);
      return Text(
        '$s $stockUnit',
        style: TextStyle(
          color: isPrimary ? _Glass.textPrimary : _Glass.textSecondary,
          fontSize: isPrimary ? 12 : 11,
          fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _Glass.borderMid, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            width: 90,
            child: Center(child: fmtWidget(current, isPrimary: true)),
          ),
          SizedBox(
            width: 90,
            child: Center(child: fmtWidget(restock, isPrimary: false)),
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
            width: 84,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: _Glass.textMuted,
                  ),
                  onPressed: onEditTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Edit material',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.qr_code_rounded,
                    size: 15,
                    color: _Glass.textMuted,
                  ),
                  onPressed: onQrTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'View QR Code',
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 15,
                    color: Colors.red.shade400,
                  ),
                  onPressed: onDeleteTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Delete material',
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
// Seed data
// =============================================================================
// piece_to_sqft = total sqft in 1 replenishment piece (roll / sheet)
// stock_unit = "sqft" (area-tracked) or "pcs" (discrete count)
// restock_level is always in the same unit as current_stock (sqft or pcs)
const _kInitialMaterials = [
  // ── Standard 30" (2.5ft) wide × 50m roll = 2.5 × 164.04 ≈ 410 sqft ──────
  {
    'material_id': 'RM-001',
    'material_name': 'Poster Glitter',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 2050.0, // 5 rolls
  },
  {
    'material_id': 'RM-002',
    'material_name': 'Vinyl Matte Sticker',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 2050.0,
  },
  {
    'material_id': 'RM-003',
    'material_name': 'Clear Matte Printable',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 2050.0,
  },
  {
    'material_id': 'RM-004',
    'material_name': 'Clear Glossy Printable',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 1230.0, // 3 rolls
  },
  {
    'material_id': 'RM-005',
    'material_name': 'Poster Paper Matte',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 1230.0,
  },
  {
    'material_id': 'RM-006',
    'material_name': 'Poster Paper Glossy',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 1230.0,
  },
  {
    'material_id': 'RM-007',
    'material_name': 'Vinyl Glossy Sticker',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 1230.0,
  },
  // ── 5ft wide × 50m roll = 5 × 164.04 ≈ 820 sqft ─────────────────────────
  {
    'material_id': 'RM-008',
    'material_name': '5ft Matte Sticker',
    'unit_description': 'Roll (5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 820.2,
    'restock_level': 2460.0, // 3 rolls
  },
  // ── Sheet materials (4×8ft = 32 sqft, 2×4ft = 8 sqft, etc.) ─────────────
  {
    'material_id': 'RM-009',
    'material_name': '3in Sticker Sheet',
    'unit_description': '4×5ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 20.0,
    'restock_level': 200.0, // 10 sheets
  },
  {
    'material_id': 'RM-010',
    'material_name': 'Composite Panel (4×8ft)',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 320.0, // 10 sheets
  },
  {
    'material_id': 'RM-011',
    'material_name': 'Composite Panel (2×4ft)',
    'unit_description': '2×4ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 8.0,
    'restock_level': 80.0,
  },
  {
    'material_id': 'RM-012',
    'material_name': 'Acrylic Clear 5mm',
    'unit_description': '3×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 24.0,
    'restock_level': 120.0, // 5 sheets
  },
  {
    'material_id': 'RM-013',
    'material_name': 'Acrylic Chalk White',
    'unit_description': '4×4ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 16.0,
    'restock_level': 80.0,
  },
  {
    'material_id': 'RM-014',
    'material_name': 'Acrylic Diffuser 3mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 160.0,
  },
  {
    'material_id': 'RM-015',
    'material_name': 'Acrylic Diffuser 1.5mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 160.0,
  },
  {
    'material_id': 'RM-016',
    'material_name': 'Acrylic Clear 3mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 160.0,
  },
  {
    'material_id': 'RM-017',
    'material_name': 'Acrylic Clear 1.5mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 160.0,
  },
  {
    'material_id': 'RM-018',
    'material_name': 'Sintra Board 3mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 320.0, // 10 sheets
  },
  {
    'material_id': 'RM-019',
    'material_name': 'Sintra Board 1.5mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 320.0,
  },
  {
    'material_id': 'RM-020',
    'material_name': 'Sintra Board 5mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 320.0,
  },
  // ── Tarpaulin: 10.5ft wide × 50m long = 10.5 × 164.042 ≈ 1722 sqft ───────
  {
    'material_id': 'RM-021',
    'material_name': 'Tarpaulin 13oz',
    'unit_description': 'Roll (10.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 1722.44,
    'restock_level': 5167.0, // 3 rolls
  },
  {
    'material_id': 'RM-022',
    'material_name': 'Tarpaulin 10oz',
    'unit_description': 'Roll (10.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 1722.44,
    'restock_level': 5167.0,
  },
  {
    'material_id': 'RM-023',
    'material_name': 'Sticker Matte',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 2050.0,
  },
  {
    'material_id': 'RM-024',
    'material_name': 'Sticker Glossy',
    'unit_description': 'Roll (2.5ft × 50m)',
    'stock_unit': 'sqft',
    'piece_to_sqft': 410.1,
    'restock_level': 2050.0,
  },
  {
    'material_id': 'RM-025',
    'material_name': 'Sintra Board 2mm',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 320.0,
  },
  {
    'material_id': 'RM-026',
    'material_name': 'Plastic PVC',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 160.0,
  },
  // ── Discrete piece materials ───────────────────────────────────────────────
  {
    'material_id': 'RM-027',
    'material_name': 'Adhesive',
    'unit_description': 'pcs / bottle',
    'stock_unit': 'pcs',
    'restock_level': 10.0,
  },
  {
    'material_id': 'RM-028',
    'material_name': 'Signage - Composite Panel',
    'unit_description': '4×8ft sheet',
    'stock_unit': 'sqft',
    'piece_to_sqft': 32.0,
    'restock_level': 160.0,
  },
  {
    'material_id': 'RM-029',
    'material_name': 'Signage - Metal Furring',
    'unit_description': 'pcs',
    'stock_unit': 'pcs',
    'restock_level': 20.0,
  },
];
