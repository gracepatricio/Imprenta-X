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
              ? const _ForecastPlaceholder()
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

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses
                  .map(
                    (s) => _SummaryCard(
                      status: s,
                      count: counts[s] ?? 0,
                      color: statusColor(s),
                      isActive: statusFilter == s,
                      onTap: () => onFilterTap(s),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusChip(
                  label: 'All',
                  isActive: statusFilter == null,
                  onTap: onClearFilter,
                ),
                ...statuses.map(
                  (s) => _StatusChip(
                    label: s,
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
    // ClipRRect ensures the horizontal scroll inside never bleeds past
    // the rounded corners of the outer container at any screen width.
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
              // Use LayoutBuilder so the header width matches available space,
              // expanding beyond _kTableMinWidth only when there is room.
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
                        'No materials with status "$statusFilter"',
                        style: const TextStyle(
                          color: _Glass.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : isNarrow
                  // On narrow screens: scroll horizontally with a minimum
                  // width, but expand to fill if the viewport is wider.
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
// Forecast placeholder
// =============================================================================
class _ForecastPlaceholder extends StatelessWidget {
  const _ForecastPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Glass.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: _Glass.card(radius: 20, elevated: true),
              child: const Icon(
                Icons.trending_up_rounded,
                size: 32,
                color: _Glass.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Forecast',
              style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Stock forecasting — coming soon',
              style: TextStyle(color: _Glass.textSecondary, fontSize: 13),
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

// ── Status chip ───────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.isActive,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xEE1A1A2E) : _Glass.surfaceThin,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isActive ? const Color(0x33FFFFFF) : _Glass.borderMid,
            width: 0.8,
          ),
          boxShadow: [_Glass.rowShadow],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : _Glass.textSecondary,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
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
