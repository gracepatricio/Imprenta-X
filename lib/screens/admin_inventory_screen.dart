import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'app_theme.dart';

// ── Breakpoints ───────────────────────────────────────────────────────────────
const double _kTableMinWidth = 548.0;

// ── Shared colour constants (same as product management & admin logs) ─────────
const Color _amber = Color(0xFFB45309);
const Color _navyBlue = Color(0xFF0F1A2E);

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
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

// ── Shared blur filter ────────────────────────────────────────────────────────
final _blurFilter = ImageFilter.blur(sigmaX: 14, sigmaY: 14);

// ── Sub-tab enum ──────────────────────────────────────────────────────────────
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

  @override
  void initState() {
    super.initState();
    _syncRawMaterials();
  }

  // One-time migration: replaces all raw material documents with the new
  // authoritative list of 33 materials.  Idempotent — checks RM-001 name
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
      // Silent — retries on next open until it succeeds.
    }
  }

  // Counts derived from the live stream — kept here so the header can use them.
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

      // Only seed materials that do not already exist — never overwrite
      // existing documents so configured dimensions and stock are preserved.
      final existingSnap = await col.get();
      final existingIds = existingSnap.docs.map((d) => d.id).toSet();

      final missing = _kInitialMaterials
          .where((m) => !existingIds.contains(m['material_id'] as String))
          .toList();

      if (missing.isEmpty) {
        if (mounted) _snack('All materials already exist — nothing to seed', _Glass.accentEmerald);
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

  // ── build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header card ──────────────────────────────────────────────────────
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
                  // ── Row 1: icon + title + Add Material + Re-seed ────────────
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
                              'Raw materials — stock levels and forecast',
                              style: TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Re-seed (ghost pill, right of title, left of Add)
                      if (_activeTab == _InventoryTab.inventory) ...[
                        GestureDetector(
                          onTap: _seeding ? null : _seedInitialData,
                          child: AnimatedOpacity(
                            opacity: _seeding ? 0.5 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: _Glass.surfaceThin,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _Glass.borderMid,
                                  width: 0.9,
                                ),
                                boxShadow: const [_Glass.rowShadow],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _seeding
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _Glass.textSecondary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh_rounded,
                                          size: 14,
                                          color: _Glass.textSecondary,
                                        ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Re-seed',
                                    style: TextStyle(
                                      color: _Glass.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Add Material (primary pill)
                      GestureDetector(
                        onTap: _handleAddMaterial,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: _Glass.solidPill(_navyBlue, glow: true),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
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
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(height: 1, color: _Glass.borderDim),
                  const SizedBox(height: 12),

                  // ── Row 2: sub-tab pills ────────────────────────────────────
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

                  // ── Row 3: status filter pills with counts (Inventory tab only)
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

        // ── Body ─────────────────────────────────────────────────────────────
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

  // ── Dialogs ─────────────────────────────────────────────────────────────────
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
// _TabPill — pill-shaped sub-tab (same style as category pills)
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
// _FilterPill — status filter pill with inline count
// Design: dot + label run together; count sits in a clean filled chip,
// no border — just background tint. Consistent across all states.
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
            // Dot — always the status color; on active navy bg a thin white
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

            // Count chip — borderless, just a tinted background
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
          width: 150,
          child: Text('Available Stock', style: _h, textAlign: TextAlign.center),
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
    final subLine      = _buildMatSubLine(data);
    final isStructured = su.isNotEmpty;
    final isPiece      = su == 'Piece';

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
          SizedBox(width: 150, child: Center(child: stockCell)),
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
  String _baseUom  = 'pc'; // 'pc' | 'sheet' — only relevant for Piece type
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
              // ── Title bar ─────────────────────────────────────────────────
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

              // ── Form ──────────────────────────────────────────────────────
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
                            '→ ${_fmtNum(_unitSizeSqft)} sheets per pack',
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

              // ── Action bar ────────────────────────────────────────────────
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
// Forecast content (unchanged algorithm, updated tokens & styling)
// =============================================================================
class _ForecastContent extends StatefulWidget {
  const _ForecastContent();
  @override
  State<_ForecastContent> createState() => _ForecastContentState();
}

class _ForecastContentState extends State<_ForecastContent> {
  bool _loading = true;
  String? _error;
  List<_FItem> _items = [];
  String _filter = 'All';
  String _sort = 'Days Left';

  static const _winDays = 90;
  static const _perDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final nowTs = Timestamp.fromDate(now);
      final p1Start = Timestamp.fromDate(
        now.subtract(const Duration(days: 30)),
      );
      final p2Start = Timestamp.fromDate(
        now.subtract(const Duration(days: 60)),
      );
      final p3Start = Timestamp.fromDate(
        now.subtract(const Duration(days: 90)),
      );

      final matSnap = await db.collection('RawMaterials').get();
      final mats = {for (final d in matSnap.docs) d.id: d.data()};

      final prodSnap = await db.collection('Products').get();
      final bomById = <String, List<Map<String, dynamic>>>{};
      final bomByName = <String, List<Map<String, dynamic>>>{};
      for (final d in prodSnap.docs) {
        final bom =
            (d.data()['bill_of_materials'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        bomById[d.id] = bom;
        final n = d.data()['product_name']?.toString() ?? '';
        if (n.isNotEmpty) bomByName[n] = bom;
      }

      void accum(
        List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
        Timestamp from,
        Timestamp to,
        Map<String, double> out,
      ) {
        for (final doc in docs) {
          final ts = doc.data()['created_at'] as Timestamp?;
          if (ts == null || ts.compareTo(from) < 0 || ts.compareTo(to) >= 0)
            continue;
          for (final p
              in (doc.data()['products'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  []) {
            final pid = p['product_id']?.toString() ?? '';
            final nm = p['name']?.toString() ?? '';
            final qty = (p['qty'] as num?)?.toDouble() ?? 1;
            for (final b in bomById[pid] ?? bomByName[nm] ?? []) {
              final mid = b['material_id']?.toString() ?? '';
              final qpu = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1;
              if (mid.isNotEmpty) out[mid] = (out[mid] ?? 0) + qty * qpu;
            }
          }
        }
      }

      // Fetch completed orders, sales records and inventory logs in parallel
      final fetchResults = await Future.wait([
        db.collection('Orders').where('status', isEqualTo: 'completed').get(),
        db.collection('Sales_Records').get(),
        db.collection('InventoryLogs').get(),
      ]);
      final orderSnap    = fetchResults[0];
      final salesRecSnap = fetchResults[1];
      final logSnap      = fetchResults[2];

      final c1 = <String, double>{};
      final c2 = <String, double>{};
      final c3 = <String, double>{};

      // From completed Orders (uses created_at)
      accum(orderSnap.docs, p1Start, nowTs, c1);
      accum(orderSnap.docs, p2Start, p1Start, c2);
      accum(orderSnap.docs, p3Start, p2Start, c3);

      // From Sales_Records (uses sale_date + product_name → BOM)
      for (final period in [
        (p1Start, nowTs,   c1),
        (p2Start, p1Start, c2),
        (p3Start, p2Start, c3),
      ]) {
        for (final doc in salesRecSnap.docs) {
          final ts = doc.data()['sale_date'] as Timestamp?;
          if (ts == null) continue;
          if (ts.compareTo(period.$1) < 0) continue;
          if (ts.compareTo(period.$2) >= 0) continue;
          final productName = doc.data()['product_name']?.toString() ?? '';
          final qty = (doc.data()['quantity'] as num?)?.toDouble() ?? 1.0;
          if (productName.isEmpty || qty <= 0) continue;
          final bom = bomByName[productName] ?? [];
          for (final b in bom) {
            final mid = b['material_id']?.toString() ?? '';
            final qpu = (b['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
            if (mid.isNotEmpty) period.$3[mid] = (period.$3[mid] ?? 0) + qty * qpu;
          }
        }
      }

      final repMap = <String, double>{};
      for (final d in logSnap.docs) {
        final ts = d.data()['timestamp'] as Timestamp?;
        if (ts != null && ts.compareTo(p3Start) < 0) continue;
        final mid = d.data()['material_id']?.toString() ?? '';
        final qty = (d.data()['quantity_added'] as num?)?.toDouble() ?? 0;
        if (mid.isNotEmpty) repMap[mid] = (repMap[mid] ?? 0) + qty;
      }

      final items = <_FItem>[];
      for (final e in mats.entries) {
        final mid  = e.key;
        final data = e.value;
        final name = data['material_name']?.toString() ?? mid;
        final su       = data['stocking_unit']?.toString() ?? '';
        final unitSqft = (data['unit_size_sqft'] as num?)?.toDouble() ?? 0;
        final unitDesc = data['unit_description']?.toString() ?? '';
        final unit = unitDesc.isNotEmpty ? unitDesc : (su.isNotEmpty ? su : '');

        final rawStk = (data['current_stock'] as num?)?.toDouble() ?? 0;
        final rawRst = (data['restock_level'] as num?)?.toDouble() ?? 0;

        // Convert base units (sqft) → stocking units for display
        final isNewStyle = unitSqft > 0.001 && su.isNotEmpty;
        final stk = isNewStyle ? rawStk / unitSqft : rawStk;
        final rst = isNewStyle ? rawRst / unitSqft : rawRst;

        final rawV1 = c1[mid] ?? 0.0;
        final rawV2 = c2[mid] ?? 0.0;
        final rawV3 = c3[mid] ?? 0.0;
        final v1 = isNewStyle ? rawV1 / unitSqft : rawV1;
        final v2 = isNewStyle ? rawV2 / unitSqft : rawV2;
        final v3 = isNewStyle ? rawV3 / unitSqft : rawV3;

        final r1 = v1 / _perDays;
        final r2 = v2 / _perDays;
        final r3 = v3 / _perDays;
        final total = v1 + v2 + v3;

        final rawRep = repMap[mid] ?? 0.0;
        final rep = isNewStyle ? rawRep / unitSqft : rawRep;

        final daily = total > 0
            ? total / _winDays
            : (rep > 0 ? rep / _winDays : 0.0);
        double? mape;
        {
          final errs = <double>[];
          if (r2 > 0.001 && r3 > 0) errs.add(((r2 - r3) / r2).abs() * 100);
          if (r1 > 0.001 && r2 > 0) errs.add(((r1 - r2) / r1).abs() * 100);
          if (errs.isNotEmpty)
            mape = errs.reduce((a, b) => a + b) / errs.length;
        }
        final dOut = daily > 0.001 ? stk / daily : double.infinity;
        final dRe = (daily > 0.001 && stk > rst)
            ? (stk - rst) / daily
            : (stk <= rst ? 0.0 : double.infinity);
        final rec = daily > 0 ? math.max(0.0, daily * 30 - stk) : 0.0;
        items.add(
          _FItem(
            id: mid,
            name: name,
            unit: unit,
            stock: stk,
            restock: rst,
            daily: daily,
            r1: r1,
            r2: r2,
            r3: r3,
            dOut: dOut,
            dRe: dRe,
            consumed: total,
            replenished: rep,
            rec30: rec,
            mape: mape,
          ),
        );
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_FItem> get _filtered {
    var list = _items.where((it) {
      switch (_filter) {
        case 'Critical':
          return it.urgency == _FUrg.critical;
        case 'At Risk':
          return it.urgency == _FUrg.atRisk;
        case 'Healthy':
          return it.urgency == _FUrg.healthy;
        default:
          return true;
      }
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case 'Name':
          return a.name.compareTo(b.name);
        case 'Consumption':
          return b.daily.compareTo(a.daily);
        case 'MAPE':
          return (b.mape ?? double.infinity).compareTo(
            a.mape ?? double.infinity,
          );
        default:
          return (a.dOut.isInfinite ? 99999.0 : a.dOut).compareTo(
            b.dOut.isInfinite ? 99999.0 : b.dOut,
          );
      }
    });
    return list;
  }

  int _cnt(_FUrg u) => _items.where((it) => it.urgency == u).length;

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: _navyBlue.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
            const SizedBox(height: 14),
            const Text(
              'Analysing forecast…',
              style: TextStyle(color: _Glass.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: _Glass.accentRose,
                size: 44,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: _Glass.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _load,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: _Glass.solidPill(_navyBlue, glow: true),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Retry',
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
      );
    } else if (_items.isEmpty) {
      body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up_rounded, size: 44, color: _Glass.textMuted),
            SizedBox(height: 12),
            Text(
              'No materials found',
              style: TextStyle(color: _Glass.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    } else {
      final filtered = _filtered;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Forecast header band
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFAFBFC),
              border: Border(
                bottom: BorderSide(color: _Glass.borderDim, width: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inventory Forecast',
                            style: TextStyle(
                              color: _Glass.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Based on last 90 days · MAPE accuracy',
                            style: TextStyle(
                              color: _Glass.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _load,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _Glass.borderMid,
                            width: 0.9,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 14,
                              color: _Glass.textSecondary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Refresh',
                              style: TextStyle(
                                color: _Glass.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Urgency tiles
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FTile(
                        label: 'Critical',
                        count: _cnt(_FUrg.critical),
                        color: _Glass.accentRose,
                        icon: Icons.warning_amber_rounded,
                        isActive: _filter == 'Critical',
                        onTap: () => setState(
                          () => _filter = _filter == 'Critical'
                              ? 'All'
                              : 'Critical',
                        ),
                      ),
                      _FTile(
                        label: 'At Risk',
                        count: _cnt(_FUrg.atRisk),
                        color: _amber,
                        icon: Icons.access_time_rounded,
                        isActive: _filter == 'At Risk',
                        onTap: () => setState(
                          () => _filter = _filter == 'At Risk'
                              ? 'All'
                              : 'At Risk',
                        ),
                      ),
                      _FTile(
                        label: 'Healthy',
                        count: _cnt(_FUrg.healthy),
                        color: _Glass.accentEmerald,
                        icon: Icons.check_circle_outline_rounded,
                        isActive: _filter == 'Healthy',
                        onTap: () => setState(
                          () => _filter = _filter == 'Healthy'
                              ? 'All'
                              : 'Healthy',
                        ),
                      ),
                      _FTile(
                        label: 'No Data',
                        count: _cnt(_FUrg.noData),
                        color: _Glass.textMuted,
                        icon: Icons.help_outline_rounded,
                        isActive: false,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Sort chips
                Row(
                  children: [
                    const Text(
                      'Sort: ',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                    ),
                    ...['Days Left', 'Name', 'Consumption', 'MAPE'].map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _sort = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _sort == s
                                  ? _navyBlue
                                  : _Glass.surfaceThin,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: _sort == s
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : _Glass.borderMid,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                color: _sort == s
                                    ? Colors.white
                                    : _Glass.textSecondary,
                                fontSize: 12,
                                fontWeight: _sort == s
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: const [
                    _FLDot(color: _Glass.accentRose, label: 'Critical ≤7d'),
                    _FLDot(color: _amber, label: 'At Risk ≤21d'),
                    _FLDot(color: _Glass.accentEmerald, label: 'Healthy >21d'),
                    _FLDot(
                      color: _Glass.accentEmerald,
                      label: 'MAPE Excellent <10%',
                    ),
                    _FLDot(color: Color(0xFF65A30D), label: 'Good 10–25%'),
                    _FLDot(color: _amber, label: 'Fair 25–50%'),
                    _FLDot(color: _Glass.accentRose, label: 'Poor ≥50%'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No materials in "$_filter"',
                      style: const TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  )
                : Builder(builder: (ctx) {
                    final scrollCtrl = ScrollController();
                    return Scrollbar(
                      controller: scrollCtrl,
                      thumbVisibility: true,
                      trackVisibility: true,
                      child: ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(14),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _FCard(item: filtered[i]),
                      ),
                    );
                  }),
          ),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: _blurFilter,
        child: Container(
          decoration: _Glass.glass(radius: 20, elevated: true),
          child: body,
        ),
      ),
    );
  }
}

// ── Forecast model ────────────────────────────────────────────────────────────
enum _FUrg { critical, atRisk, healthy, noData }

enum _FMGrade { excellent, good, fair, poor, unavailable }

class _FItem {
  final String id, name, unit;
  final double stock, restock, daily, r1, r2, r3;
  final double dOut, dRe, consumed, replenished, rec30;
  final double? mape;

  const _FItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.restock,
    required this.daily,
    required this.r1,
    required this.r2,
    required this.r3,
    required this.dOut,
    required this.dRe,
    required this.consumed,
    required this.replenished,
    required this.rec30,
    required this.mape,
  });

  _FUrg get urgency {
    if (daily < 0.001) return _FUrg.noData;
    if (dOut <= 7 || stock <= 0) return _FUrg.critical;
    if (dOut <= 21 || stock <= restock) return _FUrg.atRisk;
    return _FUrg.healthy;
  }

  Color get uColor {
    switch (urgency) {
      case _FUrg.critical:
        return _Glass.accentRose;
      case _FUrg.atRisk:
        return _amber;
      case _FUrg.healthy:
        return _Glass.accentEmerald;
      case _FUrg.noData:
        return _Glass.textMuted;
    }
  }

  String get uLabel {
    switch (urgency) {
      case _FUrg.critical:
        return 'Critical';
      case _FUrg.atRisk:
        return 'At Risk';
      case _FUrg.healthy:
        return 'Healthy';
      case _FUrg.noData:
        return 'No Data';
    }
  }

  String get daysLabel => dOut.isInfinite ? '∞' : dOut.toStringAsFixed(0);

  _FMGrade get mapeGrade {
    if (mape == null) return _FMGrade.unavailable;
    if (mape! < 10) return _FMGrade.excellent;
    if (mape! < 25) return _FMGrade.good;
    if (mape! < 50) return _FMGrade.fair;
    return _FMGrade.poor;
  }

  String get mapeLabel => mape == null ? 'N/A' : '${mape!.toStringAsFixed(1)}%';
  String get mapeGradeLabel {
    switch (mapeGrade) {
      case _FMGrade.excellent:
        return 'Excellent';
      case _FMGrade.good:
        return 'Good';
      case _FMGrade.fair:
        return 'Fair';
      case _FMGrade.poor:
        return 'Poor';
      case _FMGrade.unavailable:
        return 'N/A';
    }
  }

  Color get mColor {
    switch (mapeGrade) {
      case _FMGrade.excellent:
        return _Glass.accentEmerald;
      case _FMGrade.good:
        return const Color(0xFF65A30D);
      case _FMGrade.fair:
        return _amber;
      case _FMGrade.poor:
        return _Glass.accentRose;
      case _FMGrade.unavailable:
        return _Glass.textMuted;
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
    final it = widget.item;
    final color = it.uColor;
    final stockPct = it.restock > 0
        ? (it.stock / (it.restock * 3)).clamp(0.0, 1.0)
        : (it.stock > 0 ? 1.0 : 0.0);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _expanded ? color.withValues(alpha: 0.04) : _Glass.surfaceMid,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded ? color.withValues(alpha: 0.35) : _Glass.borderMid,
            width: _expanded ? 1.0 : 0.8,
          ),
          boxShadow: const [_Glass.rowShadow],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.10),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            it.daysLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: it.daysLabel.length > 3 ? 9 : 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'days',
                            style: TextStyle(
                              color: color.withValues(alpha: 0.6),
                              fontSize: 7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.name,
                                style: const TextStyle(
                                  color: _Glass.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.35),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                it.uLabel,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stockPct,
                            minHeight: 4,
                            backgroundColor: _Glass.borderMid.withValues(
                              alpha: 0.4,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              it.unit.isNotEmpty
                                  ? 'Stock: ${_fmt(it.stock)} × ${it.unit}'
                                  : 'Stock: ${_fmt(it.stock)}',
                              style: const TextStyle(
                                color: _Glass.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: it.mColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: it.mColor.withValues(alpha: 0.30),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.analytics_outlined,
                                    color: it.mColor,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'MAPE ${it.mapeLabel}',
                                    style: TextStyle(
                                      color: it.mColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down,
                        color: _Glass.textMuted,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: _Glass.borderDim, height: 1),
                    const SizedBox(height: 10),
                    _FMapePanel(item: it),
                    const SizedBox(height: 8),
                    _FPeriodTrend(item: it),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _FStatChip(
                          label: 'Days to Stockout',
                          value: it.dOut.isInfinite
                              ? '∞'
                              : '~${it.dOut.toStringAsFixed(0)} days',
                          color: color,
                        ),
                        _FStatChip(
                          label: 'Days to Restock',
                          value: it.daily < 0.001
                              ? '—'
                              : it.dRe <= 0
                              ? 'Already below!'
                              : '~${it.dRe.toStringAsFixed(0)} days',
                          color: _amber,
                        ),
                        _FStatChip(
                          label: '90d Consumed',
                          value: it.consumed > 0
                              ? _fmt(it.consumed)
                              : 'No data',
                          color: const Color(0xFF1D4ED8),
                        ),
                        _FStatChip(
                          label: '90d Replenished',
                          value: it.replenished > 0
                              ? _fmt(it.replenished)
                              : 'None',
                          color: _Glass.accentEmerald,
                        ),
                        _FStatChip(
                          label: 'Restock Level',
                          value: _fmt(it.restock),
                          color: _Glass.textSecondary,
                        ),
                      ],
                    ),
                    if (it.daily > 0.001) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: color.withValues(alpha: 0.20),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              color: color,
                              size: 14,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _rec(it),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            color: _Glass.borderMid,
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _Glass.textMuted,
                              size: 13,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'No consumption data in the last 90 days. '
                                'Forecast updates once orders for this material complete.',
                                style: TextStyle(
                                  color: _Glass.textMuted,
                                  fontSize: 11,
                                  height: 1.4,
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
          ],
        ),
      ),
    );
  }

  String _rec(_FItem it) {
    final dStr = it.dOut.isInfinite
        ? 'no foreseeable stockout'
        : '~${it.dOut.toStringAsFixed(0)} days until stockout';
    final mn = it.mape != null
        ? ' (MAPE ${it.mapeLabel} — ${it.mapeGradeLabel})'
        : '';
    if (it.urgency == _FUrg.critical)
      return 'Urgent: $dStr$mn. Order at least ${_fmt(it.rec30)} ${it.unit} immediately.';
    if (it.urgency == _FUrg.atRisk)
      return 'Reorder soon — $dStr$mn. 30-day buffer: ${_fmt(it.rec30)} ${it.unit}.';
    return 'Healthy ($dStr)$mn. 30-day top-up if needed: ${_fmt(it.rec30)} ${it.unit}.';
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
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: color, size: 13),
              const SizedBox(width: 5),
              Text(
                'Forecast Accuracy (MAPE)',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${item.mapeLabel}  •  ${item.mapeGradeLabel}',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (item.mape != null) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (_, c) {
                final w = c.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        height: 6,
                        color: _Glass.borderMid.withValues(alpha: 0.4),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: FractionallySizedBox(
                        widthFactor: (item.mape! / 100).clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFF65A30D),
                                Color(0xFFB45309),
                                Color(0xFFEF4444),
                              ],
                              stops: [0.0, 0.25, 0.50, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final pct in [10.0, 25.0, 50.0])
                      Positioned(
                        left: w * (pct / 100) - 0.5,
                        child: Container(
                          width: 1,
                          height: 6,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Text(
                  '0%',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 8),
                ),
                Spacer(),
                Text(
                  '10',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 8),
                ),
                SizedBox(width: 24),
                Text(
                  '25',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 8),
                ),
                SizedBox(width: 24),
                Text(
                  '50',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 8),
                ),
                Spacer(),
                Text(
                  '100%',
                  style: TextStyle(color: _Glass.textMuted, fontSize: 8),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _FApeRows(item: item),
            const SizedBox(height: 4),
            Text(
              'MAPE = avg |actual − forecast| / actual × 100 across 30-day windows.',
              style: TextStyle(
                color: color.withValues(alpha: 0.65),
                fontSize: 9,
                height: 1.4,
              ),
            ),
          ] else ...[
            const SizedBox(height: 5),
            const Text(
              'Need at least two 30-day periods with order data to compute MAPE.',
              style: TextStyle(
                color: _Glass.textMuted,
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FApeRows extends StatelessWidget {
  final _FItem item;
  const _FApeRows({required this.item});

  Color _ac(double v) {
    if (v < 10) return _Glass.accentEmerald;
    if (v < 25) return const Color(0xFF65A30D);
    if (v < 50) return _amber;
    return _Glass.accentRose;
  }

  @override
  Widget build(BuildContext context) {
    final r1 = item.r1;
    final r2 = item.r2;
    final r3 = item.r3;
    final a1 = (r2 > 0.001 && r3 > 0) ? ((r2 - r3) / r2).abs() * 100 : null;
    final a2 = (r1 > 0.001 && r2 > 0) ? ((r1 - r2) / r1).abs() * 100 : null;
    if (a1 == null && a2 == null) return const SizedBox.shrink();
    String f(double v) => v.toStringAsFixed(2);
    final sfx = item.unit.isNotEmpty ? ' ${item.unit}/d' : '/d';

    Widget row(String lbl, double fc, double ac, double ape) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              lbl,
              style: const TextStyle(color: _Glass.textMuted, fontSize: 9),
            ),
          ),
          Text(
            'F: ${f(fc)}$sfx',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 9),
          ),
          const SizedBox(width: 5),
          Text(
            'A: ${f(ac)}$sfx',
            style: const TextStyle(color: _Glass.textSecondary, fontSize: 9),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _ac(ape).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'APE ${ape.toStringAsFixed(1)}%',
              style: TextStyle(
                color: _ac(ape),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Period breakdown:',
          style: TextStyle(color: _Glass.textMuted, fontSize: 9),
        ),
        const SizedBox(height: 3),
        if (a1 != null) row('60–90 d → 30–60 d', r3, r2, a1),
        if (a2 != null) row('30–60 d → last 30 d', r2, r1, a2),
      ],
    );
  }
}

// ── Period trend ──────────────────────────────────────────────────────────────
class _FPeriodTrend extends StatelessWidget {
  final _FItem item;
  const _FPeriodTrend({required this.item});

  @override
  Widget build(BuildContext context) {
    final r3 = item.r3;
    final r2 = item.r2;
    final r1 = item.r1;
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
      return d > 0 ? _amber : _Glass.accentEmerald;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consumption trend  (avg daily rate per 30-day period)',
            style: TextStyle(color: _Glass.textMuted, fontSize: 9),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _FTCell(label: '60–90 d ago', rate: fmt(r3), unit: item.unit),
              Text(
                ' ${arrow(r3, r2)} ',
                style: TextStyle(
                  color: arrowC(r3, r2),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _FTCell(label: '30–60 d ago', rate: fmt(r2), unit: item.unit),
              Text(
                ' ${arrow(r2, r1)} ',
                style: TextStyle(
                  color: arrowC(r2, r1),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _FTCell(
                label: 'Last 30 d',
                rate: fmt(r1),
                unit: item.unit,
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FTCell extends StatelessWidget {
  final String label, rate, unit;
  final bool highlight;
  const _FTCell({
    required this.label,
    required this.rate,
    required this.unit,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: highlight
          ? BoxDecoration(
              color: _navyBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _Glass.borderMid, width: 0.8),
            )
          : null,
      child: Column(
        children: [
          Text(
            rate,
            style: TextStyle(
              color: highlight ? _Glass.textPrimary : _Glass.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${unit.isNotEmpty ? '$unit/' : ''}day',
            style: const TextStyle(color: _Glass.textMuted, fontSize: 7),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: highlight ? _Glass.textSecondary : _Glass.textMuted,
              fontSize: 7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

// ── Forecast summary tile ─────────────────────────────────────────────────────
class _FTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _FTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? _navyBlue : _Glass.surfaceMid,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.20)
              : _Glass.borderMid,
          width: 0.8,
        ),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? color.withValues(alpha: 0.9) : color,
            size: 14,
          ),
          const SizedBox(width: 7),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  color: isActive ? Colors.white : _Glass.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.7)
                      : _Glass.textSecondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _FStatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20), width: 0.8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FLDot extends StatelessWidget {
  final Color color;
  final String label;
  const _FLDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: _Glass.textMuted, fontSize: 9)),
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

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

String _stockUnitLabel(String su) {
  if (su == 'Sheet') return 'sheet';
  if (su == 'Roll') return 'roll';
  return 'pc';
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
// Authoritative raw-material list — 33 materials (replaces old seed list)
// =============================================================================
const _kNewMaterials = [
  // ── Rolls — width in ft, length in m ──────────────────────────────────────
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
  // ── Sheets — width & length in ft ─────────────────────────────────────────
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
  // ── Piece — no dimensions ─────────────────────────────────────────────────
  {'material_id':'RM-023','material_name':'Metal Furring','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':10.0,'current_stock':0.0},
  // ── Roll — Panaflex ───────────────────────────────────────────────────────
  {'material_id':'RM-024','material_name':'Panaflex Flex','stocking_unit':'Roll','width_value':10.0,'width_unit':'ft','length_value':50.0,'length_unit':'m','unit_size_sqft':1640.42,'base_uom':'sqft','unit_description':'Roll (10ft × 50m)','restock_level':4921.26,'current_stock':0.0},
  // ── Photo paper packs — base UoM = sheet ─────────────────────────────────
  {'material_id':'RM-025','material_name':'Photo Paper 4R','stocking_unit':'Piece','unit_size_sqft':100.0,'base_uom':'sheet','unit_description':'Pack (100 sheets)','restock_level':200.0,'current_stock':0.0},
  // ── Sheets — Card stock ───────────────────────────────────────────────────
  {'material_id':'RM-026','material_name':'Card Stock Matte','stocking_unit':'Sheet','width_value':1.083,'width_unit':'ft','length_value':0.875,'length_unit':'ft','unit_size_sqft':0.95,'base_uom':'sqft','unit_description':'Sheet (1.083ft × 0.875ft)','restock_level':4.74,'current_stock':0.0},
  {'material_id':'RM-027','material_name':'Card Stock Glossy','stocking_unit':'Sheet','width_value':1.083,'width_unit':'ft','length_value':0.875,'length_unit':'ft','unit_size_sqft':0.95,'base_uom':'sqft','unit_description':'Sheet (1.083ft × 0.875ft)','restock_level':4.74,'current_stock':0.0},
  // ── Stand units ───────────────────────────────────────────────────────────
  {'material_id':'RM-028','material_name':'Roll-up Stand','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':5.0,'current_stock':0.0},
  // ── More photo paper packs ────────────────────────────────────────────────
  {'material_id':'RM-029','material_name':'Photo Paper 3R','stocking_unit':'Piece','unit_size_sqft':100.0,'base_uom':'sheet','unit_description':'Pack (100 sheets)','restock_level':100.0,'current_stock':0.0},
  {'material_id':'RM-030','material_name':'Photo Paper 5R','stocking_unit':'Piece','unit_size_sqft':100.0,'base_uom':'sheet','unit_description':'Pack (100 sheets)','restock_level':100.0,'current_stock':0.0},
  {'material_id':'RM-031','material_name':'Photo Paper 8R/A4','stocking_unit':'Piece','unit_size_sqft':50.0,'base_uom':'sheet','unit_description':'Pack (50 sheets)','restock_level':50.0,'current_stock':0.0},
  // ── Equipment units ───────────────────────────────────────────────────────
  {'material_id':'RM-032','material_name':'X-banner Frame','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':5.0,'current_stock':0.0},
  {'material_id':'RM-033','material_name':'PVC ID Card Blank','stocking_unit':'Piece','unit_size_sqft':1.0,'base_uom':'pc','unit_description':'Piece','restock_level':20.0,'current_stock':0.0},
];

// =============================================================================
// Legacy seed data (kept for reference — superseded by _kNewMaterials)
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
