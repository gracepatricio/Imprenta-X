import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_theme.dart';

class AdminInventoryScreen extends StatefulWidget {
  const AdminInventoryScreen({super.key});

  @override
  State<AdminInventoryScreen> createState() => _AdminInventoryScreenState();
}

class _AdminInventoryScreenState extends State<AdminInventoryScreen> {
  String? _statusFilter;
  bool _seeding = false;

  static const _statuses = ['In Stock', 'Low Stock', 'Critical', 'Out of Stock'];

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('29 raw materials seeded successfully'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Seed error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('RawMaterials')
          .orderBy('material_id')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Inventory',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('Raw materials — view and adjust stock',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddMaterialDialog(context, materials),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Material'),
                  style: AppTheme.primaryButton(),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _seeding ? null : _seedInitialData,
                  icon: _seeding
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white38))
                      : const Icon(Icons.refresh, size: 14),
                  label: const Text('Re-seed',
                      style: TextStyle(fontSize: 11)),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Status summary cards
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _statuses
                    .map((s) => _SummaryCard(
                          status: s,
                          count: counts[s] ?? 0,
                          color: _statusColor(s),
                          isActive: _statusFilter == s,
                          onTap: () => setState(() =>
                              _statusFilter =
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
                        onTap: () => setState(() =>
                            _statusFilter =
                                _statusFilter == s ? null : s),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 10),

            const _TableHeader(),
            const SizedBox(height: 4),

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
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _MaterialRow(
                        data: filtered[i],
                        statusColor:
                            _statusColor(filtered[i]['_status'] as String),
                        onQrTap: () => _showQr(context, filtered[i]),
                        onDeleteTap: () =>
                            _confirmDelete(context, filtered[i]),
                      ),
                    ),
            ),
          ],
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

  // ── Add material dialog ──────────────────────────────────────────────────────

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
                  // Material ID
                  TextFormField(
                    controller: idCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: AppTheme.inputDecoration('Material ID',
                        icon: Icons.tag),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  // Name
                  TextFormField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: AppTheme.inputDecoration('Material Name',
                        icon: Icons.inventory_2_outlined),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  // Unit description
                  TextFormField(
                    controller: unitCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: AppTheme.inputDecoration(
                        'Unit description  (e.g. 1 roll, 4x8ft sheet)',
                        icon: Icons.straighten),
                  ),
                  const SizedBox(height: 10),
                  // Restock level + initial stock row
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

  // ── Delete confirmation ──────────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, Map<String, dynamic> m) {
    final docId = m['doc_id']?.toString() ?? '';
    final name = m['material_name']?.toString() ?? docId;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: const Text('Delete Material',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'Delete "$name"? This cannot be undone and will also remove it from any bill of materials.',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
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
                messenger.showSnackBar(SnackBar(
                  content: Text('"$name" deleted'),
                  backgroundColor: Colors.red.shade700,
                ));
              } catch (e) {
                messenger.showSnackBar(SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── QR dialog ───────────────────────────────────────────────────────────────

  void _showQr(BuildContext context, Map<String, dynamic> m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: Text(
          m['material_name']?.toString() ?? '',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 204,
              height: 204,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: m['material_id']?.toString() ?? 'NO-ID',
                version: QrVersions.auto,
                size: 180,
                gapless: false,
                backgroundColor: Colors.white,
                errorStateBuilder: (ctx, err) => const Center(
                  child: Text('QR error',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              m['material_id']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Print and attach to raw material storage',
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close',
                style: TextStyle(color: AppTheme.gold)),
          ),
        ],
      ),
    );
  }

}

// ── Widgets ───────────────────────────────────────────────────────────────────

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
          const Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No inventory data',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Seed the 29 initial raw materials to get started',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: seeding ? null : onSeed,
            icon: seeding
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.add_box_outlined, size: 18),
            label: const Text('Seed Initial Materials'),
            style: AppTheme.primaryButton(),
          ),
        ],
      ),
    );
  }
}

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
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(status,
                style:
                    const TextStyle(color: Colors.white60, fontSize: 10)),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          SizedBox(width: 74, child: Text('Code', style: _h)),
          Expanded(child: Text('Material Name', style: _h)),
          SizedBox(
              width: 80,
              child: Text('Stock', style: _h, textAlign: TextAlign.center)),
          SizedBox(
              width: 80,
              child: Text('Restock At',
                  style: _h, textAlign: TextAlign.center)),
          SizedBox(
              width: 96,
              child: Text('Status', style: _h, textAlign: TextAlign.center)),
          SizedBox(width: 66),
        ],
      ),
    );
  }

  static const _h = TextStyle(
      color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold);
}

class _MaterialRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color statusColor;
  final VoidCallback onQrTap;
  final VoidCallback onDeleteTap;

  const _MaterialRow(
      {required this.data,
      required this.statusColor,
      required this.onQrTap,
      required this.onDeleteTap});

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
                  style:
                      const TextStyle(color: Colors.white, fontSize: 12),
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
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.45)),
                ),
                child: Text(status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          // Actions: QR + Delete (admin is view-only for stock)
          SizedBox(
            width: 66,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code,
                      size: 15, color: Colors.white38),
                  onPressed: onQrTap,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  tooltip: 'View QR Code',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 15, color: Colors.red.shade400),
                  onPressed: onDeleteTap,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
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

// ── Seed data ─────────────────────────────────────────────────────────────────

const _kInitialMaterials = [
  {'material_id': 'RM-001', 'material_name': 'Poster Glitter', 'unit_description': '1 roll', 'restock_level': 5.0},
  {'material_id': 'RM-002', 'material_name': 'Vinyl Matte Sticker', 'unit_description': '1 roll', 'restock_level': 5.0},
  {'material_id': 'RM-003', 'material_name': 'Clear Matte Printable', 'unit_description': '1 roll', 'restock_level': 5.0},
  {'material_id': 'RM-004', 'material_name': 'Clear Glossy Printable', 'unit_description': '1/2 roll', 'restock_level': 3.0},
  {'material_id': 'RM-005', 'material_name': 'Poster Paper Matte', 'unit_description': '1/2 roll', 'restock_level': 3.0},
  {'material_id': 'RM-006', 'material_name': 'Poster Paper Glossy', 'unit_description': '3/4 roll', 'restock_level': 3.0},
  {'material_id': 'RM-007', 'material_name': 'Vinyl Glossy Sticker', 'unit_description': '3/4 roll', 'restock_level': 3.0},
  {'material_id': 'RM-008', 'material_name': '5ft Matte Sticker', 'unit_description': '1/4 roll', 'restock_level': 3.0},
  {'material_id': 'RM-009', 'material_name': '3in Sticker', 'unit_description': '4x5ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-010', 'material_name': 'Composite Panel (4x8ft)', 'unit_description': '4x8ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-011', 'material_name': 'Composite Panel (2x4ft)', 'unit_description': '2x4ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-012', 'material_name': 'Acrylic Clear 5mm', 'unit_description': '3x8ft sheet', 'restock_level': 5.0},
  {'material_id': 'RM-013', 'material_name': 'Acrylic Chalk White', 'unit_description': '4x4ft sheet', 'restock_level': 5.0},
  {'material_id': 'RM-014', 'material_name': 'Acrylic Diffuser 3mm', 'unit_description': '4x8ft sheet', 'restock_level': 5.0},
  {'material_id': 'RM-015', 'material_name': 'Acrylic Diffuser 1.5mm', 'unit_description': '4x8ft sheet', 'restock_level': 5.0},
  {'material_id': 'RM-016', 'material_name': 'Acrylic Clear 3mm', 'unit_description': '4x8ft sheet', 'restock_level': 5.0},
  {'material_id': 'RM-017', 'material_name': 'Acrylic Clear 1.5mm', 'unit_description': '4x8ft sheet', 'restock_level': 5.0},
  {'material_id': 'RM-018', 'material_name': 'Sintra Board 3mm', 'unit_description': '4x8ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-019', 'material_name': 'Sintra Board 1.5mm', 'unit_description': '4x8ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-020', 'material_name': 'Sintra Board 5mm', 'unit_description': '4x8ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-021', 'material_name': 'Tarpaulin 13oz', 'unit_description': 'Roll (13oz)', 'restock_level': 3.0},
  {'material_id': 'RM-022', 'material_name': 'Tarpaulin 10oz', 'unit_description': 'Roll (10oz)', 'restock_level': 3.0},
  {'material_id': 'RM-023', 'material_name': 'Sticker Matte', 'unit_description': 'Roll', 'restock_level': 5.0},
  {'material_id': 'RM-024', 'material_name': 'Sticker Glossy', 'unit_description': 'Roll', 'restock_level': 5.0},
  {'material_id': 'RM-025', 'material_name': 'Sintra Board 2mm', 'unit_description': '4x8ft sheet', 'restock_level': 10.0},
  {'material_id': 'RM-026', 'material_name': 'Plastic PVC', 'unit_description': 'Sheet', 'restock_level': 5.0},
  {'material_id': 'RM-027', 'material_name': 'Adhesive', 'unit_description': 'pcs / bottle', 'restock_level': 10.0},
  {'material_id': 'RM-028', 'material_name': 'Signage - Composite Panel', 'unit_description': 'Sheet', 'restock_level': 5.0},
  {'material_id': 'RM-029', 'material_name': 'Signage - Metal Furring', 'unit_description': 'pcs', 'restock_level': 20.0},
];
