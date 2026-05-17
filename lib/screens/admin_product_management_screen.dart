import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'app_theme.dart';

// ── Breakpoint ────────────────────────────────────────────────────────────────
const double _kNarrow = 700.0;

// ── Amber color constant ──────────────────────────────────────────────────────
const Color _amber = Color.fromRGBO(180, 83, 9, 1);

// ── Liquid Glass Design Tokens ────────────────────────────────────────────────
class _Glass {
  static const Color surface = Color(0xEEFFFFFF);
  static const Color surfaceMid = Color(0xCCFFFFFF);
  static const Color surfaceThin = Color(0x99FFFFFF);

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

  // Input field decoration matching glass aesthetic
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
      borderSide: const BorderSide(color: borderMid, width: 0.8),
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
    errorStyle: const TextStyle(fontSize: 10, color: Color(0xFFE53935)),
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
    'Large Format Printing',
    'Sticker Printing',
    'Photo Printing',
    'Menu Board',
    'Invitations',
    'Calling Cards',
  ];

  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < _kNarrow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header panel ─────────────────────────────────────────────────
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
                  // Title row — stacks on narrow
                  if (isNarrow) ...[
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product Management',
                          style: TextStyle(
                            color: _Glass.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage catalog, pricing, and availability',
                          style: TextStyle(
                            color: _Glass.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _GlassButton(
                      label: 'Add Product',
                      icon: Icons.add_rounded,
                      isPrimary: true,
                      onPressed: () => _openProductForm(context, null),
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
                                'Product Management',
                                style: TextStyle(
                                  color: _Glass.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
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
                        _GlassButton(
                          label: 'Add Product',
                          icon: Icons.add_rounded,
                          isPrimary: true,
                          onPressed: () => _openProductForm(context, null),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Category filter chips — always horizontally scrollable
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _GlassChip(
                          label: 'All',
                          isActive: _categoryFilter == null,
                          onTap: () => setState(() => _categoryFilter = null),
                        ),
                        ..._categories.map(
                          (c) => _GlassChip(
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

            const SizedBox(height: 8),

            // ── Product list panel ────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _Glass.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _Glass.borderMid, width: 0.8),
                  boxShadow: const [_Glass.rowShadow],
                ),
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
                          color: _Glass.textPrimary.withValues(alpha: 0.4),
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
                              decoration: _Glass.card(
                                radius: 20,
                                elevated: true,
                              ),
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
                                fontSize: 16,
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

                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        return _ProductTile(
                          data: data,
                          docId: docs[i].id,
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
                ),
              ),
            ),
          ],
        );
      },
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
      builder: (_) => AlertDialog(
        backgroundColor: _Glass.surface,
        elevation: 32,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _Glass.borderMid, width: 1),
        ),
        title: const Text(
          'Delete Product',
          style: TextStyle(
            color: _Glass.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This cannot be undone.',
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
              await FirebaseFirestore.instance
                  .collection('Products')
                  .doc(docId)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"$name" deleted'),
                    backgroundColor: Colors.red.shade700,
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
}

// =============================================================================
// Product tile — liquid glass row
// =============================================================================
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.data,
    required this.docId,
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
      decoration: BoxDecoration(
        color: _Glass.surfaceMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
        boxShadow: const [_Glass.rowShadow],
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _Glass.surfaceThin,
              border: Border.all(color: _Glass.borderMid, width: 0.8),
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

          // Info
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  cat,
                  style: const TextStyle(color: _Glass.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (isFeatured) ...[
                      const Icon(
                        Icons.star_rounded,
                        color: _amber, // ← was AppTheme.gold
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (price != null) ...[
                      Text(
                        '₱$price${unit.isNotEmpty ? ' $unit' : ''}',
                        style: const TextStyle(
                          color: _amber, // ← was AppTheme.gold
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Availability badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.12)
                            : const Color(0xFFC62828).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: isAvailable
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
                              : const Color(0xFFC62828).withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${isAvailable ? 'Available' : 'Unavailable'}'
                        '${hasOverride ? ' (manual)' : ''}',
                        style: TextStyle(
                          color: isAvailable
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                          fontSize: 9.5,
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

          // Edit button
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xDD1A1A2E),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: const Color(0x44FFFFFF), width: 0.8),
                boxShadow: const [_Glass.rowShadow],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, color: Colors.white, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'Edit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Delete button
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.35),
                  width: 0.8,
                ),
                boxShadow: const [_Glass.rowShadow],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade500,
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.red.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
            // ── Dialog title bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
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
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(
                        color: _Glass.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _Glass.textMuted,
                      size: 18,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: _Glass.borderMid, height: 16, thickness: 0.8),

            // ── Scrollable form body ──────────────────────────────────────────
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
                                width: 0.8,
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
                              _GlassButton(
                                label: 'Upload Image',
                                icon: Icons.upload_file_outlined,
                                isPrimary: false,
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
                                      color: Color(0xFFC62828),
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

                      // ── Availability ────────────────────────────────────────
                      _SectionLabel('Availability'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _Glass.borderMid,
                            width: 0.8,
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
                                  activeColor: AppTheme.gold,
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
                                    activeColor: const Color(0xFF2E7D32),
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
                                    activeColor: const Color(0xFF2E7D32),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Featured toggle ─────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _isFeatured
                              ? AppTheme.gold.withValues(alpha: 0.08)
                              : _Glass.surfaceThin,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isFeatured
                                ? AppTheme.gold.withValues(alpha: 0.4)
                                : _Glass.borderMid,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_outline_rounded,
                              color: _isFeatured
                                  ? AppTheme.gold
                                  : _Glass.textMuted,
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
                                          ? AppTheme.gold
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
                              activeColor: AppTheme.gold,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Bill of Materials ───────────────────────────────────
                      Row(
                        children: [
                          _SectionLabel('Bill of Materials'),
                          const Spacer(),
                          _GlassButton(
                            label: 'Add Material',
                            icon: Icons.add_rounded,
                            isPrimary: false,
                            onPressed: _materialsLoaded ? _addBomItem : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_bom.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: const Text(
                            'No BOM set. Add materials to enable automatic availability tracking.',
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
                          onChanged: (updated) =>
                              setState(() => _bom[e.key] = updated),
                          onRemove: () => setState(() => _bom.removeAt(e.key)),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Bulk Pricing ────────────────────────────────────────
                      Row(
                        children: [
                          _SectionLabel('Bulk Pricing (Optional)'),
                          const Spacer(),
                          _GlassButton(
                            label: 'Add Tier',
                            icon: Icons.add_rounded,
                            isPrimary: false,
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

            // ── Action bar ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: _Glass.borderMid, width: 0.8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: _Glass.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  _GlassButton(
                    label: isEdit ? 'Save Changes' : 'Create Product',
                    isPrimary: true,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
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
      });
    });
  }
}

// =============================================================================
// BOM edit row — glass
// =============================================================================
class _BomEditRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> allMaterials;
  final Function(Map<String, dynamic>) onChanged;
  final VoidCallback onRemove;

  const _BomEditRow({
    super.key,
    required this.item,
    required this.allMaterials,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_BomEditRow> createState() => _BomEditRowState();
}

class _BomEditRowState extends State<_BomEditRow> {
  String _materialId = '';
  String _materialName = '';
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _materialId = widget.item['material_id']?.toString() ?? '';
    _materialName = widget.item['material_name']?.toString() ?? '';
    _qtyCtrl = TextEditingController(
      text: widget.item['quantity_per_unit']?.toString() ?? '1',
    );

    if (widget.allMaterials.isNotEmpty &&
        !widget.allMaterials.any(
          (m) => (m['material_id'] ?? m['id'])?.toString() == _materialId,
        )) {
      final first = widget.allMaterials.first;
      _materialId = (first['material_id'] ?? first['id'])?.toString() ?? '';
      _materialName = first['material_name']?.toString() ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
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
                color: Colors.red.shade400,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Glass.surfaceThin,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Glass.borderMid, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Material',
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
                    hint: const Text(
                      'Select material',
                      style: TextStyle(color: _Glass.textMuted, fontSize: 12),
                    ),
                    style: const TextStyle(
                      color: _Glass.textPrimary,
                      fontSize: 12,
                    ),
                    items: widget.allMaterials.map((m) {
                      final id =
                          (m['material_id'] ?? m['id'])?.toString() ?? '';
                      final name = m['material_name']?.toString() ?? '';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          '$id – $name',
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
                        (m) => (m['material_id'] ?? m['id'])?.toString() == id,
                      );
                      setState(() {
                        _materialId = id;
                        _materialName = mat['material_name']?.toString() ?? '';
                      });
                      _notify();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Qty/unit',
                  style: TextStyle(
                    color: _Glass.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
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
                  decoration: _Glass.field('1'),
                  onChanged: (_) => _notify(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.remove_circle_outline,
              color: Colors.red.shade400,
              size: 18,
            ),
            onPressed: widget.onRemove,
            padding: const EdgeInsets.only(bottom: 2),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Bulk pricing row — glass
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
        border: Border.all(color: _Glass.borderMid, width: 0.8),
      ),
      child: Column(
        children: [
          // Tier label + remove
          Row(
            children: [
              Text(
                'Tier ${widget.index + 1}',
                style: const TextStyle(
                  color: _amber, // ← was AppTheme.gold
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Colors.red.shade400,
                  size: 16,
                ),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Min qty
              SizedBox(
                width: 100,
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
              // Discount type
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
              // Value
              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _discountType == 'rate' ? 'Rate (%)' : 'Amount (₱)',
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
// Shared glass widgets
// =============================================================================

/// Pill button — primary (dark navy) or ghost (glass thin)
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
          boxShadow: const [_Glass.rowShadow],
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

/// Category filter chip
class _GlassChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _GlassChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xEE1A1A2E) : _Glass.surfaceThin,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isActive ? const Color(0x33FFFFFF) : _Glass.borderMid,
            width: 0.8,
          ),
          boxShadow: const [_Glass.rowShadow],
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
