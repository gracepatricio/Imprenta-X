import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_theme.dart';

// ── Breakpoint ────────────────────────────────────────────────────────────────
const double _kNarrow = 700.0;
const double _kTableMinWidth = 560.0;

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
        batch.set(ref, {
          ...mat,
          'current_stock': 0.0,
          'last_updated': null,
          'last_updated_by': '',
          'last_updated_by_uid': '',
        });
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
              ? const _ForecastContent()
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
                    label: 'Unit description  (e.g. 1 roll, 4x8ft sheet)',
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
                              return 'Invalid number';
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
                              return 'Invalid number';
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
                setDlg(() {});
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

  const _TablePanel({
    required this.isNarrow,
    required this.filtered,
    required this.statusColor,
    required this.statusFilter,
    required this.onQrTap,
    required this.onDeleteTap,
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
// =============================================================================
// Forecast content  (replaces _ForecastPlaceholder)
// Uses the same _Glass tokens as the rest of this file.
// Algorithm: 90-day window split into three 30-day periods; naive
// period-over-period MAPE for forecast accuracy.
// =============================================================================
class _ForecastContent extends StatefulWidget {
  const _ForecastContent();
  @override
  State<_ForecastContent> createState() => _ForecastContentState();
}

class _ForecastContentState extends State<_ForecastContent> {
  bool    _loading = true;
  String? _error;
  List<_FItem> _items = [];
  String _filter = 'All';
  String _sort   = 'Days Left';

  static const _winDays = 90;
  static const _perDays = 30;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db  = FirebaseFirestore.instance;
      final now = DateTime.now();

      final nowTs   = Timestamp.fromDate(now);
      final p1Start = Timestamp.fromDate(now.subtract(const Duration(days: 30)));
      final p2Start = Timestamp.fromDate(now.subtract(const Duration(days: 60)));
      final p3Start = Timestamp.fromDate(now.subtract(const Duration(days: 90)));

      final matSnap = await db.collection('RawMaterials').get();
      final mats    = { for (final d in matSnap.docs) d.id: d.data() };

      final prodSnap  = await db.collection('Products').get();
      final bomById   = <String, List<Map<String, dynamic>>>{};
      final bomByName = <String, List<Map<String, dynamic>>>{};
      for (final d in prodSnap.docs) {
        final bom = (d.data()['bill_of_materials'] as List?)
            ?.cast<Map<String, dynamic>>() ?? [];
        bomById[d.id] = bom;
        final n = d.data()['product_name']?.toString() ?? '';
        if (n.isNotEmpty) bomByName[n] = bom;
      }

      void accum(
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
          Timestamp from, Timestamp to, Map<String, double> out,
          ) {
        for (final doc in docs) {
          final ts = doc.data()['created_at'] as Timestamp?;
          if (ts == null || ts.compareTo(from) < 0 || ts.compareTo(to) >= 0) continue;
          for (final p in (doc.data()['products'] as List?)
              ?.cast<Map<String, dynamic>>() ?? []) {
            final pid  = p['product_id']?.toString() ?? '';
            final nm   = p['name']?.toString() ?? '';
            final qty  = (p['qty'] as num?)?.toDouble() ?? 1;
            for (final b in bomById[pid] ?? bomByName[nm] ?? []) {
              final mid = b['material_id']?.toString() ?? '';
              final qpu = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1;
              if (mid.isNotEmpty) out[mid] = (out[mid] ?? 0) + qty * qpu;
            }
          }
        }
      }

      final orderSnap = await db.collection('Orders')
          .where('status', isEqualTo: 'completed').get();
      final c1 = <String, double>{};
      final c2 = <String, double>{};
      final c3 = <String, double>{};
      accum(orderSnap.docs, p1Start, nowTs,   c1);
      accum(orderSnap.docs, p2Start, p1Start, c2);
      accum(orderSnap.docs, p3Start, p2Start, c3);

      final repMap = <String, double>{};
      final logSnap = await db.collection('InventoryLogs').get();
      for (final d in logSnap.docs) {
        final ts = d.data()['timestamp'] as Timestamp?;
        if (ts != null && ts.compareTo(p3Start) < 0) continue;
        final mid = d.data()['material_id']?.toString() ?? '';
        final qty = (d.data()['quantity_added'] as num?)?.toDouble() ?? 0;
        if (mid.isNotEmpty) repMap[mid] = (repMap[mid] ?? 0) + qty;
      }

      final items = <_FItem>[];
      for (final e in mats.entries) {
        final mid  = e.key;  final data = e.value;
        final name = data['material_name']?.toString() ?? mid;
        final unit = data['unit_description']?.toString() ?? '';
        final stk  = (data['current_stock'] as num?)?.toDouble() ?? 0;
        final rst  = (data['restock_level']  as num?)?.toDouble() ?? 0;

        final v1 = c1[mid] ?? 0.0; final v2 = c2[mid] ?? 0.0; final v3 = c3[mid] ?? 0.0;
        final r1 = v1 / _perDays;  final r2 = v2 / _perDays;  final r3 = v3 / _perDays;

        final total = v1 + v2 + v3;
        final rep   = repMap[mid] ?? 0.0;
        final daily = total > 0 ? total / _winDays : (rep > 0 ? rep / _winDays : 0.0);

        double? mape;
        {
          final errs = <double>[];
          if (r2 > 0.001 && r3 > 0) errs.add(((r2 - r3) / r2).abs() * 100);
          if (r1 > 0.001 && r2 > 0) errs.add(((r1 - r2) / r1).abs() * 100);
          if (errs.isNotEmpty) mape = errs.reduce((a, b) => a + b) / errs.length;
        }

        final dOut = daily > 0.001 ? stk / daily : double.infinity;
        final dRe  = (daily > 0.001 && stk > rst) ? (stk - rst) / daily
            : (stk <= rst ? 0.0 : double.infinity);
        final rec  = daily > 0 ? math.max(0.0, daily * 30 - stk) : 0.0;

        items.add(_FItem(
          id: mid, name: name, unit: unit,
          stock: stk, restock: rst, daily: daily,
          r1: r1, r2: r2, r3: r3,
          dOut: dOut, dRe: dRe,
          consumed: total, replenished: rep, rec30: rec, mape: mape,
        ));
      }

      setState(() { _items = items; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<_FItem> get _filtered {
    var list = _items.where((it) {
      switch (_filter) {
        case 'Critical': return it.urgency == _FUrg.critical;
        case 'At Risk':  return it.urgency == _FUrg.atRisk;
        case 'Healthy':  return it.urgency == _FUrg.healthy;
        default:         return true;
      }
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'Name':        return a.name.compareTo(b.name);
        case 'Consumption': return b.daily.compareTo(a.daily);
        case 'MAPE':
          return (b.mape ?? double.infinity).compareTo(a.mape ?? double.infinity);
        default:
          return (a.dOut.isInfinite ? 99999.0 : a.dOut)
              .compareTo(b.dOut.isInfinite ? 99999.0 : b.dOut);
      }
    });
    return list;
  }

  int _cnt(_FUrg u) => _items.where((it) => it.urgency == u).length;

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: _Glass.textPrimary.withValues(alpha: 0.4)),
        const SizedBox(height: 14),
        const Text('Analysing forecast…',
            style: TextStyle(color: _Glass.textMuted, fontSize: 13)),
      ]));
    } else if (_error != null) {
      body = Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Color(0xFFBF360C), size: 44),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _Glass.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          _GlassButton(label: 'Retry', icon: Icons.refresh_rounded,
              isPrimary: true, onPressed: _load),
        ]),
      ));
    } else if (_items.isEmpty) {
      body = const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 44, color: _Glass.textMuted),
        SizedBox(height: 12),
        Text('No materials found',
            style: TextStyle(color: _Glass.textSecondary, fontSize: 14)),
      ]));
    } else {
      final filtered = _filtered;
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          decoration: BoxDecoration(
            color: const Color(0xF2F4F6F8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(
                bottom: BorderSide(color: _Glass.borderMid, width: 0.8)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title + refresh
            Row(children: [
              const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Inventory Forecast',
                    style: TextStyle(color: _Glass.textPrimary, fontSize: 17,
                        fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                SizedBox(height: 2),
                Text('Based on last 90 days of orders · MAPE accuracy',
                    style: TextStyle(color: _Glass.textMuted, fontSize: 11)),
              ])),
              _GlassButton(label: 'Refresh', icon: Icons.refresh_rounded,
                  isPrimary: false, onPressed: _load),
            ]),
            const SizedBox(height: 12),

            // Summary tiles
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FTile(label: 'Critical',
                    count: _cnt(_FUrg.critical), color: const Color(0xFFBF360C),
                    icon: Icons.warning_amber_rounded,
                    isActive: _filter == 'Critical',
                    onTap: () => setState(() =>
                    _filter = _filter == 'Critical' ? 'All' : 'Critical')),
                _FTile(label: 'At Risk',
                    count: _cnt(_FUrg.atRisk), color: const Color(0xFFF57F17),
                    icon: Icons.access_time_rounded,
                    isActive: _filter == 'At Risk',
                    onTap: () => setState(() =>
                    _filter = _filter == 'At Risk' ? 'All' : 'At Risk')),
                _FTile(label: 'Healthy',
                    count: _cnt(_FUrg.healthy), color: const Color(0xFF2E7D32),
                    icon: Icons.check_circle_outline_rounded,
                    isActive: _filter == 'Healthy',
                    onTap: () => setState(() =>
                    _filter = _filter == 'Healthy' ? 'All' : 'Healthy')),
                _FTile(label: 'No Data',
                    count: _cnt(_FUrg.noData), color: _Glass.textMuted,
                    icon: Icons.help_outline_rounded,
                    isActive: false, onTap: () {}),
              ]),
            ),
            const SizedBox(height: 10),

            // Sort chips
            Row(children: [
              const Text('Sort: ',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 11)),
              ...['Days Left', 'Name', 'Consumption', 'MAPE'].map((s) =>
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _sort = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _sort == s
                              ? const Color(0xEE1A1A2E) : _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _sort == s
                                ? const Color(0x33FFFFFF) : _Glass.borderMid,
                            width: 0.8,
                          ),
                        ),
                        child: Text(s, style: TextStyle(
                          color: _sort == s ? Colors.white : _Glass.textSecondary,
                          fontSize: 11,
                          fontWeight: _sort == s
                              ? FontWeight.w700 : FontWeight.w500,
                        )),
                      ),
                    ),
                  ),
              ),
            ]),
            const SizedBox(height: 8),

            // Legends
            Wrap(spacing: 14, runSpacing: 4, children: const [
              _FLDot(color: Color(0xFFBF360C), label: 'Critical ≤7d'),
              _FLDot(color: Color(0xFFF57F17), label: 'At Risk ≤21d'),
              _FLDot(color: Color(0xFF2E7D32), label: 'Healthy >21d'),
              _FLDot(color: Color(0xFF2E7D32), label: 'MAPE Excellent <10%'),
              _FLDot(color: Color(0xFF558B2F), label: 'Good 10–25%'),
              _FLDot(color: Color(0xFFF57F17), label: 'Fair 25–50%'),
              _FLDot(color: Color(0xFFBF360C), label: 'Poor ≥50%'),
            ]),
          ]),
        ),

        // ── Cards ─────────────────────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No materials in "$_filter" category',
              style: const TextStyle(color: _Glass.textMuted, fontSize: 13)))
              : ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _FCard(item: filtered[i]),
          ),
        ),
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        color: _Glass.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: body,
    );
  }
}

// ── Forecast data model ───────────────────────────────────────────────────────
enum _FUrg   { critical, atRisk, healthy, noData }
enum _FMGrade { excellent, good, fair, poor, unavailable }

class _FItem {
  final String id, name, unit;
  final double stock, restock, daily, r1, r2, r3;
  final double dOut, dRe, consumed, replenished, rec30;
  final double? mape;

  const _FItem({
    required this.id, required this.name, required this.unit,
    required this.stock, required this.restock, required this.daily,
    required this.r1, required this.r2, required this.r3,
    required this.dOut, required this.dRe,
    required this.consumed, required this.replenished,
    required this.rec30, required this.mape,
  });

  _FUrg get urgency {
    if (daily < 0.001)                  return _FUrg.noData;
    if (dOut <= 7 || stock <= 0)        return _FUrg.critical;
    if (dOut <= 21 || stock <= restock) return _FUrg.atRisk;
    return _FUrg.healthy;
  }

  Color get uColor {
    switch (urgency) {
      case _FUrg.critical: return const Color(0xFFBF360C);
      case _FUrg.atRisk:   return const Color(0xFFF57F17);
      case _FUrg.healthy:  return const Color(0xFF2E7D32);
      case _FUrg.noData:   return _Glass.textMuted;
    }
  }

  String get uLabel {
    switch (urgency) {
      case _FUrg.critical: return 'Critical';
      case _FUrg.atRisk:   return 'At Risk';
      case _FUrg.healthy:  return 'Healthy';
      case _FUrg.noData:   return 'No Data';
    }
  }

  String get daysLabel => dOut.isInfinite ? '∞' : dOut.toStringAsFixed(0);

  _FMGrade get mapeGrade {
    if (mape == null) return _FMGrade.unavailable;
    if (mape! < 10)   return _FMGrade.excellent;
    if (mape! < 25)   return _FMGrade.good;
    if (mape! < 50)   return _FMGrade.fair;
    return _FMGrade.poor;
  }

  String get mapeLabel => mape == null ? 'N/A' : '${mape!.toStringAsFixed(1)}%';

  String get mapeGradeLabel {
    switch (mapeGrade) {
      case _FMGrade.excellent:   return 'Excellent';
      case _FMGrade.good:        return 'Good';
      case _FMGrade.fair:        return 'Fair';
      case _FMGrade.poor:        return 'Poor';
      case _FMGrade.unavailable: return 'N/A';
    }
  }

  Color get mColor {
    switch (mapeGrade) {
      case _FMGrade.excellent:   return const Color(0xFF2E7D32);
      case _FMGrade.good:        return const Color(0xFF558B2F);
      case _FMGrade.fair:        return const Color(0xFFF57F17);
      case _FMGrade.poor:        return const Color(0xFFBF360C);
      case _FMGrade.unavailable: return _Glass.textMuted;
    }
  }
}

// ── Forecast card ─────────────────────────────────────────────────────────────
class _FCard extends StatefulWidget {
  final _FItem item;
  const _FCard({required this.item});
  @override
  State<_FCard> createState() => _FCardState();
}

class _FCardState extends State<_FCard> {
  bool _expanded = false;
  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final it       = widget.item;
    final color    = it.uColor;
    final stockPct = it.restock > 0
        ? (it.stock / (it.restock * 3)).clamp(0.0, 1.0)
        : (it.stock > 0 ? 1.0 : 0.0);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _expanded ? color.withValues(alpha: 0.04) : _Glass.surfaceMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _expanded ? color.withValues(alpha: 0.35) : _Glass.borderMid,
            width: _expanded ? 1.0 : 0.8,
          ),
          boxShadow: const [_Glass.rowShadow],
        ),
        child: Column(children: [
          // ── Collapsed row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              // Days circle
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(it.daysLabel, style: TextStyle(
                      color: color,
                      fontSize: it.daysLabel.length > 3 ? 9 : 13,
                      fontWeight: FontWeight.w800)),
                  Text('days', style: TextStyle(
                      color: color.withValues(alpha: 0.6), fontSize: 7)),
                ])),
              ),
              const SizedBox(width: 10),

              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(it.name,
                      style: const TextStyle(color: _Glass.textPrimary,
                          fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: color.withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: Text(it.uLabel, style: TextStyle(
                        color: color, fontSize: 9,
                        fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 5),

                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stockPct, minHeight: 4,
                    backgroundColor: _Glass.borderMid.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 4),

                Row(children: [
                  Text(
                    it.unit.isNotEmpty
                        ? 'Stock: ${_fmt(it.stock)} × ${it.unit}'
                        : 'Stock: ${_fmt(it.stock)}',
                    style: const TextStyle(
                        color: _Glass.textSecondary, fontSize: 10),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: it.mColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: it.mColor.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.analytics_outlined,
                          color: it.mColor, size: 8),
                      const SizedBox(width: 3),
                      Text('MAPE ${it.mapeLabel}', style: TextStyle(
                          color: it.mColor, fontSize: 9,
                          fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ]),
              ])),

              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: _Glass.textMuted, size: 16),
                ),
              ),
            ]),
          ),

          // ── Expanded detail ────────────────────────────────────────────────
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Divider(color: _Glass.borderMid, height: 1),
                const SizedBox(height: 10),

                _FMapePanel(item: it),
                const SizedBox(height: 8),

                _FPeriodTrend(item: it),
                const SizedBox(height: 8),

                Wrap(spacing: 6, runSpacing: 6, children: [
                  _FStatChip(label: 'Days to Stockout',
                      value: it.dOut.isInfinite ? '∞'
                          : '~${it.dOut.toStringAsFixed(0)} days',
                      color: color),
                  _FStatChip(label: 'Days to Restock',
                      value: it.daily < 0.001 ? '—'
                          : it.dRe <= 0 ? 'Already below!'
                          : '~${it.dRe.toStringAsFixed(0)} days',
                      color: const Color(0xFFF57F17)),
                  _FStatChip(label: '90d Consumed',
                      value: it.consumed > 0 ? _fmt(it.consumed) : 'No data',
                      color: const Color(0xFF1565C0)),
                  _FStatChip(label: '90d Replenished',
                      value: it.replenished > 0
                          ? _fmt(it.replenished) : 'None',
                      color: const Color(0xFF00695C)),
                  _FStatChip(label: 'Restock Level',
                      value: _fmt(it.restock),
                      color: _Glass.textSecondary),
                ]),

                if (it.daily > 0.001) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: color.withValues(alpha: 0.2), width: 0.8),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline_rounded,
                              color: color, size: 14),
                          const SizedBox(width: 7),
                          Expanded(child: Text(_rec(it), style: TextStyle(
                              color: color, fontSize: 11, height: 1.4))),
                        ]),
                  ),
                ],

                if (it.daily < 0.001) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _Glass.surfaceThin,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _Glass.borderMid, width: 0.8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          color: _Glass.textMuted, size: 13),
                      SizedBox(width: 7),
                      Expanded(child: Text(
                        'No consumption data in the last 90 days. '
                            'Forecast updates once orders for this material complete.',
                        style: TextStyle(color: _Glass.textMuted,
                            fontSize: 11, height: 1.4),
                      )),
                    ]),
                  ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }

  String _rec(_FItem it) {
    final dStr = it.dOut.isInfinite
        ? 'no foreseeable stockout'
        : '~${it.dOut.toStringAsFixed(0)} days until stockout';
    final mn = it.mape != null
        ? ' (MAPE ${it.mapeLabel} — ${it.mapeGradeLabel})' : '';
    if (it.urgency == _FUrg.critical)
      return 'Urgent: $dStr$mn. '
          'Order at least ${_fmt(it.rec30)} ${it.unit} immediately.';
    if (it.urgency == _FUrg.atRisk)
      return 'Reorder soon — $dStr$mn. '
          '30-day buffer: ${_fmt(it.rec30)} ${it.unit}.';
    return 'Healthy ($dStr)$mn. '
        '30-day top-up if needed: ${_fmt(it.rec30)} ${it.unit}.';
  }
}

// ── MAPE panel ────────────────────────────────────────────────────────────────
class _FMapePanel extends StatelessWidget {
  final _FItem item;
  const _FMapePanel({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.mColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.analytics_outlined, color: color, size: 13),
          const SizedBox(width: 5),
          Text('Forecast Accuracy (MAPE)', style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Text('${item.mapeLabel}  •  ${item.mapeGradeLabel}',
                style: TextStyle(color: color, fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ]),

        if (item.mape != null) ...[
          const SizedBox(height: 8),
          LayoutBuilder(builder: (_, c) {
            final w = c.maxWidth;
            return Stack(clipBehavior: Clip.none, children: [
              ClipRRect(borderRadius: BorderRadius.circular(3),
                  child: Container(height: 6,
                      color: _Glass.borderMid.withValues(alpha: 0.4))),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                  child: FractionallySizedBox(
                    widthFactor: (item.mape! / 100).clamp(0.0, 1.0),
                    child: Container(height: 6, decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF558B2F),
                          Color(0xFFF57F17), Color(0xFFBF360C)],
                        stops: [0.0, 0.25, 0.50, 1.0],
                      ),
                    )),
                  )),
              for (final pct in [10.0, 25.0, 50.0])
                Positioned(left: w * (pct / 100) - 0.5,
                    child: Container(width: 1, height: 6,
                        color: Colors.white.withValues(alpha: 0.7))),
            ]);
          }),
          const SizedBox(height: 4),
          const Row(children: [
            Text('0%',   style: TextStyle(color: _Glass.textMuted, fontSize: 8)),
            Spacer(),
            Text('10',   style: TextStyle(color: _Glass.textMuted, fontSize: 8)),
            SizedBox(width: 24),
            Text('25',   style: TextStyle(color: _Glass.textMuted, fontSize: 8)),
            SizedBox(width: 24),
            Text('50',   style: TextStyle(color: _Glass.textMuted, fontSize: 8)),
            Spacer(),
            Text('100%', style: TextStyle(color: _Glass.textMuted, fontSize: 8)),
          ]),
          const SizedBox(height: 6),
          _FApeRows(item: item),
          const SizedBox(height: 4),
          Text('MAPE = avg |actual − forecast| / actual × 100 across 30-day windows.',
              style: TextStyle(color: color.withValues(alpha: 0.65),
                  fontSize: 9, height: 1.4)),
        ] else ...[
          const SizedBox(height: 5),
          const Text('Need at least two 30-day periods with order data to compute MAPE.',
              style: TextStyle(color: _Glass.textMuted, fontSize: 10, height: 1.4)),
        ],
      ]),
    );
  }
}

class _FApeRows extends StatelessWidget {
  final _FItem item;
  const _FApeRows({required this.item});

  Color _ac(double v) {
    if (v < 10) return const Color(0xFF2E7D32);
    if (v < 25) return const Color(0xFF558B2F);
    if (v < 50) return const Color(0xFFF57F17);
    return const Color(0xFFBF360C);
  }

  @override
  Widget build(BuildContext context) {
    final r1 = item.r1; final r2 = item.r2; final r3 = item.r3;
    final a1 = (r2 > 0.001 && r3 > 0) ? ((r2 - r3) / r2).abs() * 100 : null;
    final a2 = (r1 > 0.001 && r2 > 0) ? ((r1 - r2) / r1).abs() * 100 : null;
    if (a1 == null && a2 == null) return const SizedBox.shrink();

    String f(double v) => v.toStringAsFixed(2);
    final sfx = item.unit.isNotEmpty ? ' ${item.unit}/d' : '/d';

    Widget row(String lbl, double fc, double ac, double ape) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(child: Text(lbl,
            style: const TextStyle(color: _Glass.textMuted, fontSize: 9))),
        Text('F: ${f(fc)}$sfx',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 9)),
        const SizedBox(width: 5),
        Text('A: ${f(ac)}$sfx',
            style: const TextStyle(color: _Glass.textSecondary, fontSize: 9)),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
              color: _ac(ape).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4)),
          child: Text('APE ${ape.toStringAsFixed(1)}%', style: TextStyle(
              color: _ac(ape), fontSize: 9, fontWeight: FontWeight.w700)),
        ),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Period breakdown:',
          style: TextStyle(color: _Glass.textMuted, fontSize: 9)),
      const SizedBox(height: 3),
      if (a1 != null) row('60–90 d → 30–60 d',   r3, r2, a1),
      if (a2 != null) row('30–60 d → last 30 d', r2, r1, a2),
    ]);
  }
}

// ── Period trend ──────────────────────────────────────────────────────────────
class _FPeriodTrend extends StatelessWidget {
  final _FItem item;
  const _FPeriodTrend({required this.item});

  @override
  Widget build(BuildContext context) {
    final r3 = item.r3; final r2 = item.r2; final r1 = item.r1;
    String fmt(double r) => r < 0.001 ? '—' : r.toStringAsFixed(2);

    String arrow(double p, double c) {
      if (p < 0.001 || c < 0.001) return '•';
      final d = c - p;
      if (d.abs() < p * 0.05) return '→';
      return d > 0 ? '↑' : '↓';
    }
    Color arrowC(double p, double c) {
      if (p < 0.001 || c < 0.001) return _Glass.textMuted;
      final d = c - p;
      if (d.abs() < p * 0.05) return _Glass.textSecondary;
      return d > 0 ? const Color(0xFFF57F17) : const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Consumption trend  (avg daily rate per 30-day period)',
            style: TextStyle(color: _Glass.textMuted, fontSize: 9)),
        const SizedBox(height: 6),
        Row(children: [
          _FTCell(label: '60–90 d ago', rate: fmt(r3), unit: item.unit),
          Text(' ${arrow(r3, r2)} ', style: TextStyle(
              color: arrowC(r3, r2), fontSize: 14, fontWeight: FontWeight.w800)),
          _FTCell(label: '30–60 d ago', rate: fmt(r2), unit: item.unit),
          Text(' ${arrow(r2, r1)} ', style: TextStyle(
              color: arrowC(r2, r1), fontSize: 14, fontWeight: FontWeight.w800)),
          _FTCell(label: 'Last 30 d', rate: fmt(r1),
              unit: item.unit, highlight: true),
        ]),
      ]),
    );
  }
}

class _FTCell extends StatelessWidget {
  final String label, rate, unit;
  final bool highlight;
  const _FTCell({required this.label, required this.rate,
    required this.unit, this.highlight = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: highlight ? BoxDecoration(
        color: const Color(0xEE1A1A2E).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
      ) : null,
      child: Column(children: [
        Text(rate, style: TextStyle(
            color: highlight ? _Glass.textPrimary : _Glass.textSecondary,
            fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 1),
        Text('${unit.isNotEmpty ? '$unit/' : ''}day',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 7)),
        const SizedBox(height: 1),
        Text(label, style: TextStyle(
            color: highlight ? _Glass.textSecondary : _Glass.textMuted,
            fontSize: 7), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// ── Forecast summary tile ─────────────────────────────────────────────────────
class _FTile extends StatelessWidget {
  final String label; final int count; final Color color;
  final IconData icon; final bool isActive; final VoidCallback onTap;
  const _FTile({required this.label, required this.count, required this.color,
    required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xEE1A1A2E) : _Glass.surfaceMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isActive ? const Color(0x33FFFFFF) : _Glass.borderMid,
            width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            color: isActive ? color.withValues(alpha: 0.9) : color, size: 14),
        const SizedBox(width: 7),
        Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count.toString(), style: TextStyle(
                  color: isActive ? Colors.white : _Glass.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.w800, height: 1)),
              Text(label, style: TextStyle(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.7) : _Glass.textSecondary,
                  fontSize: 9)),
            ]),
      ]),
    ),
  );
}

// ── Stat chip ─────────────────────────────────────────────────────────────────
class _FStatChip extends StatelessWidget {
  final String label, value; final Color color;
  const _FStatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 0.8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.7),
          fontSize: 9, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontSize: 11,
          fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Legend dot ────────────────────────────────────────────────────────────────
class _FLDot extends StatelessWidget {
  final Color color; final String label;
  const _FLDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: _Glass.textMuted, fontSize: 9)),
      ]);
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

  const _GlassField({
    required this.controller,
    required this.label,
    this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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

// ── Material row ──────────────────────────────────────────────────────────────
class _MaterialRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final bool isLast;
  final VoidCallback onQrTap;
  final VoidCallback onDeleteTap;

  const _MaterialRow({
    required this.data,
    required this.statusColor,
    required this.onQrTap,
    required this.onDeleteTap,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
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