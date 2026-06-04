import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'app_theme.dart';

// ── Breakpoint ────────────────────────────────────────────────────────────────
const double _kNarrow = 700.0;
const double _kCompact = 480.0;

// ── Amber / navy — shared with admin_logs_screen ──────────────────────────────
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
  static const Color accentViolet = Color(0xFF8B5CF6);

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

  static InputDecoration field(
    String hint, {
    IconData? icon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: textMuted, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, size: 16, color: textMuted) : null,
    filled: true,
    fillColor: surfaceThin,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: borderMid, width: 0.9),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _amber.withValues(alpha: 0.7)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: accentRose),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: accentRose),
    ),
    errorStyle: const TextStyle(fontSize: 10, color: accentRose),
  );
}

// =============================================================================
// Reusable frosted-glass card wrapper (matches admin_logs)
// =============================================================================
class _BlurCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool elevated;
  final Color? tintBorder;

  const _BlurCard({
    required this.child,
    this.padding,
    this.radius = 18,
    this.elevated = false,
    this.tintBorder,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        decoration: _Glass.glass(
          radius: radius,
          elevated: elevated,
          tintBorder: tintBorder,
        ),
        padding: padding,
        child: child,
      ),
    ),
  );
}

// =============================================================================
class AdminProductManagementScreen extends StatefulWidget {
  const AdminProductManagementScreen({super.key});

  @override
  State<AdminProductManagementScreen> createState() =>
      _AdminProductManagementScreenState();
}

class _AdminProductManagementScreenState
    extends State<AdminProductManagementScreen> {
  static const _categories = [
    'Large Format & Signage',
    'Stickers & Labels',
    'Photo & Card Prints',
  ];

  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Unified header card (matches admin_logs pattern) ─────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: _Glass.glass(radius: 20, elevated: true),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
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
                          Icons.storefront_outlined,
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
                              'Product Management',
                              style: TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 1),
                            Text(
                              'Manage catalog, pricing, and availability',
                              style: TextStyle(
                                color: _Glass.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add Product pill button
                      GestureDetector(
                        onTap: () => _openProductForm(context, null),
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
                                'Add Product',
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

                  // Category filter pills — no ClipRRect so glows aren't cut
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CategoryPill(
                          label: 'All',
                          isActive: _categoryFilter == null,
                          onTap: () => setState(() => _categoryFilter = null),
                        ),
                        ..._categories.map(
                          (c) => _CategoryPill(
                            label: c,
                            isActive: _categoryFilter == c,
                            onTap: () => setState(
                              () => _categoryFilter = _categoryFilter == c
                                  ? null
                                  : c,
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

        const SizedBox(height: 10),

        // ── Product list ─────────────────────────────────────────────────────
        Expanded(
          child: _BlurCard(
            radius: 20,
            elevated: true,
            child: StreamBuilder<QuerySnapshot>(
              stream: _categoryFilter != null
                  ? FirebaseFirestore.instance
                        .collection('Products')
                        .where('category', isEqualTo: _categoryFilter)
                        .snapshots()
                  : FirebaseFirestore.instance
                        .collection('Products')
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
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: _Glass.glass(radius: 22),
                          child: const Icon(
                            Icons.storefront_outlined,
                            size: 32,
                            color: _Glass.textMuted,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No products yet',
                          style: TextStyle(
                            color: _Glass.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "Add Product" to create the first product',
                          style: TextStyle(
                            color: _Glass.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < _kCompact;
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        return _ProductTile(
                          data: data,
                          docId: docs[i].id,
                          isCompact: isCompact,
                          onEdit: () => _openProductForm(context, {
                            'id': docs[i].id,
                            ...data,
                          }),
                          onDelete: () => _confirmDelete(
                            context,
                            docs[i].id,
                            data['product_name']?.toString() ?? '',
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _openProductForm(BuildContext context, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (_) =>
          _ProductFormDialog(existing: existing, categories: _categories),
    );
  }

  void _confirmDelete(BuildContext context, String docId, String name) {
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
              'Delete Product',
              style: TextStyle(
                color: _Glass.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This cannot be undone.',
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
              await FirebaseFirestore.instance
                  .collection('Products')
                  .doc(docId)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$name" deleted'),
                    backgroundColor: _Glass.accentRose,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
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
}

// =============================================================================
// Category filter pill (no ClipRRect — shadows render fully)
// =============================================================================
class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: isActive
          ? _Glass.solidPill(_navyBlue, glow: true)
          : BoxDecoration(
              color: _Glass.surfaceThin,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _Glass.borderMid, width: 0.9),
            ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : _Glass.textSecondary,
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

// =============================================================================
// Product tile — liquid glass row, responsive
// =============================================================================
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isCompact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.data,
    required this.docId,
    required this.isCompact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = data['product_name']?.toString() ?? '';
    final cat = data['category']?.toString() ?? '';
    final price = data['price'];
    final unit = data['pricing_unit']?.toString() ?? '';
    final imageUrl = data['image_url']?.toString() ?? '';
    final isAvailable = data['is_available'] as bool? ?? false;
    final hasOverride = data['availability_override'] != null;
    final isFeatured = data['featured'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _Glass.glass(radius: 14),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _Glass.surfaceThin,
              border: Border.all(color: _Glass.borderMid, width: 0.9),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_outlined,
                      color: _Glass.textMuted,
                      size: 22,
                    ),
                  )
                : const Icon(
                    Icons.image_outlined,
                    color: _Glass.textMuted,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),

          // Info — Expanded so it never overflows
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _Glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cat,
                  style: const TextStyle(color: _Glass.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Chips row — wrap so narrow screens don't overflow
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isFeatured)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _amber.withValues(alpha: 0.40),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star_rounded, color: _amber, size: 11),
                            SizedBox(width: 3),
                            Text(
                              'Featured',
                              style: TextStyle(
                                color: _amber,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (price != null)
                      Text(
                        '₱$price${unit.isNotEmpty ? ' $unit' : ''}',
                        style: const TextStyle(
                          color: _amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    // Availability badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? _Glass.accentEmerald.withValues(alpha: 0.12)
                            : _Glass.accentRose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: isAvailable
                              ? _Glass.accentEmerald.withValues(alpha: 0.40)
                              : _Glass.accentRose.withValues(alpha: 0.40),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${isAvailable ? 'Available' : 'Unavailable'}'
                        '${hasOverride ? ' (manual)' : ''}',
                        style: TextStyle(
                          color: isAvailable
                              ? _Glass.accentEmerald
                              : _Glass.accentRose,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Action buttons — icon-only on compact, pill on wider
          if (isCompact)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconPill(
                  icon: Icons.edit_outlined,
                  color: _navyBlue,
                  onTap: onEdit,
                ),
                const SizedBox(width: 6),
                _IconPill(
                  icon: Icons.delete_outline_rounded,
                  color: _Glass.accentRose,
                  onTap: onDelete,
                ),
              ],
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PillActionButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  bgColor: _navyBlue,
                  textColor: Colors.white,
                  onTap: onEdit,
                ),
                const SizedBox(width: 8),
                _PillActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  bgColor: _Glass.accentRose.withValues(alpha: 0.10),
                  textColor: _Glass.accentRose,
                  borderColor: _Glass.accentRose.withValues(alpha: 0.35),
                  onTap: onDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Icon-only pill (compact) ──────────────────────────────────────────────────
class _IconPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconPill({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == _navyBlue ? 1.0 : 0.10),
        shape: BoxShape.circle,
        border: Border.all(
          color: color == _navyBlue
              ? Colors.white.withValues(alpha: 0.25)
              : color.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color == _navyBlue ? Colors.white : color,
        size: 15,
      ),
    ),
  );
}

// ── Labeled pill action button ────────────────────────────────────────────────
class _PillActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _PillActionButton({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.25),
          width: 0.8,
        ),
        boxShadow: [_Glass.rowShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
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
// Product form dialog — liquid glass
// =============================================================================
class _ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<String> categories;

  const _ProductFormDialog({required this.existing, required this.categories});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _pricingUnitCtrl;
  late final TextEditingController _minQtyCtrl;
  late final TextEditingController _uomCtrl;

  String? _selectedCategory;
  bool _isAvailable = true;
  bool? _availabilityOverride;
  bool _isFeatured = false;
  String _imageUrl = '';
  Uint8List? _pickedImageBytes;
  String _pickedImageExt = 'jpg';
  bool _saving = false;

  List<Map<String, dynamic>> _bom = [];
  List<Map<String, dynamic>> _bulkPricing = [];
  List<Map<String, dynamic>> _allMaterials = [];
  bool _materialsLoaded = false;
  List<String> _materialOptions = [];
  final List<TextEditingController> _optionControllers = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['product_name'] ?? '');
    _descCtrl = TextEditingController(text: e?['description'] ?? '');
    _priceCtrl = TextEditingController(text: e?['price']?.toString() ?? '');
    _pricingUnitCtrl = TextEditingController(text: e?['pricing_unit'] ?? '');
    _minQtyCtrl = TextEditingController(
      text: e?['min_quantity']?.toString() ?? '1',
    );
    _uomCtrl = TextEditingController(text: e?['unit_of_measurement'] ?? '');
    _selectedCategory = e?['category'];
    // If the product has an old category not in the current list, clear it
    // so the dropdown doesn't throw an assertion error.
    if (_selectedCategory != null &&
        !widget.categories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }
    _isAvailable = e?['is_available'] as bool? ?? true;
    _availabilityOverride = e?['availability_override'] as bool?;
    _isFeatured = e?['featured'] as bool? ?? false;
    _imageUrl = e?['image_url'] ?? '';
    _bom = List<Map<String, dynamic>>.from(
      (e?['bill_of_materials'] as List?)?.map(
            (x) => Map<String, dynamic>.from(x as Map),
          ) ??
          [],
    );
    _bulkPricing = List<Map<String, dynamic>>.from(
      (e?['bulk_pricing'] as List?)?.map(
            (x) => Map<String, dynamic>.from(x as Map),
          ) ??
          [],
    );
    _materialOptions = List<String>.from(
      (e?['material_options'] as List?)?.map((x) => x.toString()) ?? [],
    );
    for (final opt in _materialOptions) {
      _optionControllers.add(TextEditingController(text: opt));
    }
    _loadMaterials();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _pricingUnitCtrl.dispose();
    _minQtyCtrl.dispose();
    _uomCtrl.dispose();
    for (final c in _optionControllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    final snap = await FirebaseFirestore.instance
        .collection('RawMaterials')
        .orderBy('material_id')
        .get();
    if (mounted) {
      setState(() {
        _allMaterials = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _materialsLoaded = true;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExt = ext;
    });
  }

  Future<String?> _uploadImage(String productId) async {
    if (_pickedImageBytes == null) return _imageUrl;
    final ref = FirebaseStorage.instance.ref(
      'products/$productId.$_pickedImageExt',
    );
    final task = await ref.putData(
      _pickedImageBytes!,
      SettableMetadata(contentType: 'image/$_pickedImageExt'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final isEdit = widget.existing?['id'] != null;
      final docId = isEdit
          ? widget.existing!['id'] as String
          : FirebaseFirestore.instance.collection('Products').doc().id;

      final uploadedUrl = await _uploadImage(docId);
      final computedAvailable = _availabilityOverride ?? _isAvailable;

      final data = {
        'product_name': _nameCtrl.text.trim(),
        'category': _selectedCategory,
        'description': _descCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()),
        'pricing_unit': _pricingUnitCtrl.text.trim(),
        'min_quantity': int.tryParse(_minQtyCtrl.text.trim()) ?? 1,
        'unit_of_measurement': _uomCtrl.text.trim(),
        'image_url': uploadedUrl ?? '',
        'is_available': computedAvailable,
        'availability_override': _availabilityOverride,
        'featured': _isFeatured,
        'material_options': _optionControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'bill_of_materials': _bom,
        'bulk_pricing': _bulkPricing,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (!isEdit) {
        data['created_at'] = FieldValue.serverTimestamp();
        data['product_id'] = docId;
      }

      await FirebaseFirestore.instance
          .collection('Products')
          .doc(docId)
          .set(data, SetOptions(merge: true));

      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_nameCtrl.text.trim()} ${isEdit ? 'updated' : 'created'}',
          ),
          backgroundColor: _Glass.accentEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _Glass.accentRose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: _Glass.surface,
      elevation: 32,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _Glass.borderMid, width: 1),
      ),
      child: SizedBox(
        width: 560,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            // ── Dialog title bar ────────────────────────────────────────────
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
                    child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.add_box_outlined,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _Glass.surfaceThin,
                        shape: BoxShape.circle,
                        border: Border.all(color: _Glass.borderMid, width: 0.9),
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
            const Divider(color: _Glass.borderMid, height: 16, thickness: 0.8),

            // ── Scrollable form body ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker
                      _SectionLabel('Product Image'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: _Glass.surfaceThin,
                              border: Border.all(
                                color: _Glass.borderMid,
                                width: 0.9,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _pickedImageBytes != null
                                ? Image.memory(
                                    _pickedImageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : _imageUrl.isNotEmpty
                                ? Image.network(
                                    _imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_outlined,
                                      color: _Glass.textMuted,
                                      size: 28,
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_photo_alternate,
                                    color: _Glass.textMuted,
                                    size: 32,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FormPillButton(
                                label: 'Upload Image',
                                icon: Icons.upload_file_outlined,
                                onPressed: _pickImage,
                              ),
                              if (_pickedImageBytes != null ||
                                  _imageUrl.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _pickedImageBytes = null;
                                    _imageUrl = '';
                                  }),
                                  child: const Text(
                                    'Remove',
                                    style: TextStyle(
                                      color: _Glass.accentRose,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Product Name
                      _SectionLabel('Product Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _Glass.field('e.g. Tarpaulin'),
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Category
                      _SectionLabel('Category *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: widget.categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        dropdownColor: _Glass.surface,
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _Glass.field('Select category'),
                        validator: (v) =>
                            v == null ? 'Please select a category' : null,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      _SectionLabel('Description'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: _Glass.field('Brief description'),
                      ),
                      const SizedBox(height: 12),

                      // Price + Pricing Unit
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Price (₱)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                  ),
                                  decoration: _Glass.field(
                                    'e.g. 25',
                                    icon: Icons.currency_exchange,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty)
                                      return 'Required';
                                    if (double.tryParse(v.trim()) == null)
                                      return 'Invalid number';
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
                                _SectionLabel('Pricing Unit'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _pricingUnitCtrl,
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                  ),
                                  decoration: _Glass.field(
                                    'per sqft / piece / fixed',
                                  ),
                                  validator: (v) => v?.trim().isEmpty == true
                                      ? 'Required'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Min Qty + UOM
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Min. Quantity'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _minQtyCtrl,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                  ),
                                  decoration: _Glass.field('1'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Unit of Measurement'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _uomCtrl,
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                  ),
                                  decoration: _Glass.field('pcs / sqft / roll'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Availability ────────────────────────────────────
                      _SectionLabel('Availability'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _Glass.borderMid,
                            width: 0.9,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Manual override',
                                        style: TextStyle(
                                          color: _Glass.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Force available/unavailable, ignoring BOM check',
                                        style: TextStyle(
                                          color: _Glass.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _availabilityOverride != null,
                                  onChanged: (v) => setState(
                                    () => _availabilityOverride = v
                                        ? _isAvailable
                                        : null,
                                  ),
                                  activeColor: _amber,
                                ),
                              ],
                            ),
                            if (_availabilityOverride != null) ...[
                              Divider(
                                color: _Glass.borderDim,
                                height: 16,
                                thickness: 0.8,
                              ),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Set as available',
                                      style: TextStyle(
                                        color: _Glass.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _availabilityOverride == true,
                                    onChanged: (v) => setState(
                                      () => _availabilityOverride = v,
                                    ),
                                    activeColor: _Glass.accentEmerald,
                                  ),
                                ],
                              ),
                            ],
                            if (_bom.isEmpty &&
                                _availabilityOverride == null) ...[
                              Divider(
                                color: _Glass.borderDim,
                                height: 16,
                                thickness: 0.8,
                              ),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'No BOM set — toggle availability manually',
                                      style: TextStyle(
                                        color: _Glass.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _isAvailable,
                                    onChanged: (v) =>
                                        setState(() => _isAvailable = v),
                                    activeColor: _Glass.accentEmerald,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Featured toggle ─────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _isFeatured
                              ? _amber.withValues(alpha: 0.08)
                              : _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFeatured
                                ? _amber.withValues(alpha: 0.40)
                                : _Glass.borderMid,
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_outline_rounded,
                              color: _isFeatured ? _amber : _Glass.textMuted,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Feature on Homepage',
                                    style: TextStyle(
                                      color: _isFeatured
                                          ? _amber
                                          : _Glass.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    'Shows in the Featured Products section on the customer homepage',
                                    style: TextStyle(
                                      color: _Glass.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isFeatured,
                              onChanged: (v) => setState(() => _isFeatured = v),
                              activeColor: _amber,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Material Options ────────────────────────────────
                      Row(
                        children: [
                          _SectionLabel('Material Options'),
                          const Spacer(),
                          _FormPillButton(
                            label: 'Add Option',
                            icon: Icons.add_rounded,
                            onPressed: () => setState(() {
                              _materialOptions.add('');
                              _optionControllers.add(TextEditingController());
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'e.g. "13oz", "10oz" — customers choose one when ordering.',
                        style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      if (_materialOptions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No options — all customers will use the same materials.',
                            style: TextStyle(
                              color: _Glass.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ..._materialOptions.asMap().entries.map((entry) {
                        final ctrl = _optionControllers[entry.key];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: ctrl,
                                  style: const TextStyle(
                                    color: _Glass.textPrimary,
                                    fontSize: 13,
                                  ),
                                  decoration: _Glass.field(
                                    'Option name, e.g. 13oz',
                                  ),
                                  onChanged: (v) =>
                                      _materialOptions[entry.key] = v,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline,
                                  color: _Glass.accentRose,
                                  size: 18,
                                ),
                                onPressed: () => setState(() {
                                  _materialOptions.removeAt(entry.key);
                                  _optionControllers
                                      .removeAt(entry.key)
                                      .dispose();
                                }),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 18),

                      // ── Bill of Materials ───────────────────────────────
                      Row(
                        children: [
                          _SectionLabel('Bill of Materials'),
                          const Spacer(),
                          _FormPillButton(
                            label: 'Add Material',
                            icon: Icons.add_rounded,
                            onPressed: _materialsLoaded ? _addBomItem : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Set quantity_per_unit = sqft consumed per sqft ordered '
                        '(for area-based prints), or pcs per piece ordered.',
                        style: TextStyle(color: _Glass.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      if (_bom.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No BOM set. Add materials to enable automatic inventory deduction.',
                            style: TextStyle(
                              color: _Glass.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ..._bom.asMap().entries.map(
                        (e) => _BomEditRow(
                          key: ValueKey('bom_${e.key}'),
                          item: e.value,
                          allMaterials: _allMaterials,
                          materialOptions: _materialOptions,
                          onChanged: (updated) =>
                              setState(() => _bom[e.key] = updated),
                          onRemove: () => setState(() => _bom.removeAt(e.key)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Bulk Pricing ────────────────────────────────────
                      Row(
                        children: [
                          _SectionLabel('Bulk Pricing (Optional)'),
                          const Spacer(),
                          _FormPillButton(
                            label: 'Add Tier',
                            icon: Icons.add_rounded,
                            onPressed: () => setState(() {
                              _bulkPricing.add({
                                'min_quantity': 10,
                                'discount_type': 'rate',
                                'discount_value': 10.0,
                              });
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_bulkPricing.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No bulk pricing. Add tiers to offer quantity discounts.',
                            style: TextStyle(
                              color: _Glass.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ..._bulkPricing.asMap().entries.map(
                        (e) => _BulkPricingRow(
                          item: e.value,
                          index: e.key,
                          onChanged: (updated) =>
                              setState(() => _bulkPricing[e.key] = updated),
                          onRemove: () =>
                              setState(() => _bulkPricing.removeAt(e.key)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Action bar ────────────────────────────────────────────────
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
                    onTap: _saving ? null : () => Navigator.pop(context),
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
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      decoration: _Glass.solidPill(_navyBlue, glow: true),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_saving)
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
                          Text(
                            isEdit ? 'Save Changes' : 'Create Product',
                            style: const TextStyle(
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
    );
  }

  void _addBomItem() {
    if (_allMaterials.isEmpty) return;
    final first = _allMaterials.first;
    setState(() {
      _bom.add({
        'material_id': first['material_id'] ?? first['id'],
        'material_name': first['material_name'] ?? '',
        'quantity_per_unit': 1.0,
        'for_material_option': '',
      });
    });
  }
}

// =============================================================================
// BOM edit row
// =============================================================================
class _BomEditRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allMaterials;
  final List<String> materialOptions;
  final Function(Map<String, dynamic>) onChanged;
  final VoidCallback onRemove;

  const _BomEditRow({
    super.key,
    required this.item,
    required this.allMaterials,
    required this.materialOptions,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_BomEditRow> createState() => _BomEditRowState();
}

class _BomEditRowState extends State<_BomEditRow> {
  String _materialId = '';
  String _materialName = '';
  String _forMaterialOption = '';
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _materialId = widget.item['material_id']?.toString() ?? '';
    _materialName = widget.item['material_name']?.toString() ?? '';
    _forMaterialOption = widget.item['for_material_option']?.toString() ?? '';
    _qtyCtrl = TextEditingController(
      text: widget.item['quantity_per_unit']?.toString() ?? '1',
    );
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged({
      'material_id': _materialId,
      'material_name': _materialName,
      'quantity_per_unit': double.tryParse(_qtyCtrl.text) ?? 1.0,
      'for_material_option': _forMaterialOption,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allMaterials.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Loading materials…',
                style: TextStyle(color: _Glass.textMuted, fontSize: 12),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: _Glass.accentRose,
                size: 16,
              ),
              onPressed: widget.onRemove,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }

    final valueExists = widget.allMaterials.any(
      (m) => (m['material_id'] ?? m['id'])?.toString() == _materialId,
    );
    String unitHint = '';
    if (valueExists) {
      final mat = widget.allMaterials.firstWhere(
        (m) => (m['material_id'] ?? m['id'])?.toString() == _materialId,
        orElse: () => {},
      );
      final su = mat['stock_unit']?.toString() ?? 'pcs';
      unitHint = su == 'sqft' ? 'sqft / sqft ordered' : 'pcs / piece ordered';
    }

    final validOptions = widget.materialOptions
        .where((o) => o.isNotEmpty)
        .toList();
    final optionItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '',
        child: Text(
          'All options',
          style: TextStyle(color: _Glass.textMuted, fontSize: 12),
        ),
      ),
      ...validOptions.map(
        (o) => DropdownMenuItem(
          value: o,
          child: Text(
            o,
            style: const TextStyle(color: _Glass.textPrimary, fontSize: 12),
          ),
        ),
      ),
    ];

    final forOptionValue = validOptions.contains(_forMaterialOption)
        ? _forMaterialOption
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: valueExists ? _Glass.borderMid : Colors.orange.shade300,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Raw Material',
                      style: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _Glass.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _Glass.borderMid, width: 0.8),
                      ),
                      child: DropdownButton<String>(
                        value: valueExists ? _materialId : null,
                        isExpanded: true,
                        dropdownColor: _Glass.surface,
                        underline: const SizedBox.shrink(),
                        hint: Text(
                          valueExists
                              ? 'Select material'
                              : '⚠ Unknown: $_materialId',
                          style: TextStyle(
                            color: valueExists
                                ? _Glass.textMuted
                                : Colors.orange.shade700,
                            fontSize: 12,
                          ),
                        ),
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 12,
                        ),
                        items: widget.allMaterials.map((m) {
                          final id =
                              (m['material_id'] ?? m['id'])?.toString() ?? '';
                          final name = m['material_name']?.toString() ?? '';
                          final su = m['stock_unit']?.toString() ?? 'pcs';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              '$id – $name ($su)',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _Glass.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id == null) return;
                          final mat = widget.allMaterials.firstWhere(
                            (m) =>
                                (m['material_id'] ?? m['id'])?.toString() == id,
                          );
                          setState(() {
                            _materialId = id;
                            _materialName =
                                mat['material_name']?.toString() ?? '';
                          });
                          _notify();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: _Glass.accentRose,
                  size: 18,
                ),
                onPressed: widget.onRemove,
                padding: const EdgeInsets.only(bottom: 2, left: 4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unitHint.isNotEmpty ? 'Qty ($unitHint)' : 'Qty/unit',
                      style: const TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _Glass.field('1.0'),
                      onChanged: (_) => _notify(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'For option',
                      style: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _Glass.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _Glass.borderMid, width: 0.8),
                      ),
                      child: DropdownButton<String>(
                        value: forOptionValue,
                        isExpanded: true,
                        dropdownColor: _Glass.surface,
                        underline: const SizedBox.shrink(),
                        style: const TextStyle(
                          color: _Glass.textPrimary,
                          fontSize: 12,
                        ),
                        items: optionItems,
                        onChanged: validOptions.isEmpty
                            ? null
                            : (val) {
                                setState(() => _forMaterialOption = val ?? '');
                                _notify();
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bulk pricing row
// =============================================================================
class _BulkPricingRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final Function(Map<String, dynamic>) onChanged;
  final VoidCallback onRemove;

  const _BulkPricingRow({
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_BulkPricingRow> createState() => _BulkPricingRowState();
}

class _BulkPricingRowState extends State<_BulkPricingRow> {
  late final TextEditingController _minQtyCtrl;
  late final TextEditingController _valueCtrl;
  late String _discountType;

  @override
  void initState() {
    super.initState();
    _minQtyCtrl = TextEditingController(
      text: widget.item['min_quantity']?.toString() ?? '10',
    );
    _valueCtrl = TextEditingController(
      text: widget.item['discount_value']?.toString() ?? '10',
    );
    _discountType = widget.item['discount_type'] ?? 'rate';
  }

  @override
  void dispose() {
    _minQtyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged({
      'min_quantity': int.tryParse(_minQtyCtrl.text) ?? 10,
      'discount_type': _discountType,
      'discount_value': double.tryParse(_valueCtrl.text) ?? 10.0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Glass.borderMid, width: 0.9),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: _amber.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Tier ${widget.index + 1}',
                  style: const TextStyle(
                    color: _amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _Glass.accentRose.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _Glass.accentRose.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.remove_rounded,
                    color: _Glass.accentRose,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Min. Qty',
                      style: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _minQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _Glass.field('10'),
                      onChanged: (_) => _notify(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discount Type',
                      style: TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _discountType,
                      dropdownColor: _Glass.surface,
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _Glass.field(''),
                      items: const [
                        DropdownMenuItem(
                          value: 'rate',
                          child: Text('% Rate Off'),
                        ),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('₱ Fixed Off'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() => _discountType = v ?? 'rate');
                        _notify();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _discountType == 'rate' ? 'Rate (%)' : 'Amt (₱)',
                      style: const TextStyle(
                        color: _Glass.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _Glass.field(
                        _discountType == 'rate' ? '10' : '5',
                      ),
                      onChanged: (_) => _notify(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _discountType == 'rate'
                  ? 'Order ≥ ${_minQtyCtrl.text}: ${_valueCtrl.text}% off'
                  : 'Order ≥ ${_minQtyCtrl.text}: ₱${_valueCtrl.text} off per unit',
              style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared small widgets
// =============================================================================

/// Ghost pill button used inside the form dialog
class _FormPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const _FormPillButton({required this.label, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: onPressed != null
            ? _Glass.surfaceThin
            : _Glass.surfaceThin.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _Glass.borderMid, width: 0.9),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: onPressed != null
                  ? _Glass.textSecondary
                  : _Glass.textMuted,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: onPressed != null
                  ? _Glass.textSecondary
                  : _Glass.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Small bold section label inside the dialog form
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
