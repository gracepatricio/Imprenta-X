import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'app_theme.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Product Management',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text('Manage catalog, pricing, and availability',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openProductForm(context, null),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Product'),
              style: AppTheme.primaryButton(),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Category filter
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Chip(
                  label: 'All',
                  isActive: _categoryFilter == null,
                  onTap: () => setState(() => _categoryFilter = null)),
              ..._categories.map((c) => _Chip(
                    label: c,
                    isActive: _categoryFilter == c,
                    onTap: () => setState(() =>
                        _categoryFilter = _categoryFilter == c ? null : c),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Product list
        Expanded(
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
                return const Center(
                    child:
                        CircularProgressIndicator(color: Colors.white));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_outlined,
                          size: 56, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('No products yet',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 15)),
                      const SizedBox(height: 8),
                      const Text(
                          'Tap "Add Product" to create the first product',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data =
                      docs[i].data() as Map<String, dynamic>;
                  return _ProductTile(
                    data: data,
                    docId: docs[i].id,
                    onEdit: () => _openProductForm(
                        context, {'id': docs[i].id, ...data}),
                    onDelete: () => _confirmDelete(context, docs[i].id,
                        data['product_name']?.toString() ?? ''),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _openProductForm(
      BuildContext context, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductFormDialog(
        existing: existing,
        categories: _categories,
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, String docId, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        title: const Text('Delete Product',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
            'Are you sure you want to delete "$name"? This cannot be undone.',
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
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
                      backgroundColor: Colors.red.shade700),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Product tile ──────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile(
      {required this.data,
      required this.docId,
      required this.onEdit,
      required this.onDelete});

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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_outlined,
                        color: Colors.white24,
                        size: 22))
                : const Icon(Icons.image_outlined,
                    color: Colors.white24, size: 22),
          ),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(cat,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isFeatured) ...[
                      const Icon(Icons.star_rounded,
                          color: AppTheme.gold, size: 13),
                      const SizedBox(width: 4),
                    ],
                    if (price != null)
                      Text('₱$price${unit.isNotEmpty ? ' $unit' : ''}',
                          style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isAvailable
                                ? const Color(0xFF4CAF50)
                                    .withValues(alpha: 0.5)
                                : Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${isAvailable ? 'Available' : 'Unavailable'}${hasOverride ? ' (manual)' : ''}',
                        style: TextStyle(
                            color: isAvailable
                                ? const Color(0xFF4CAF50)
                                : Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppTheme.gold, size: 18),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.red.shade400, size: 18),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

// ── Product form dialog ───────────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final List<String> categories;

  const _ProductFormDialog(
      {required this.existing, required this.categories});

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
    _priceCtrl =
        TextEditingController(text: e?['price']?.toString() ?? '');
    _pricingUnitCtrl =
        TextEditingController(text: e?['pricing_unit'] ?? '');
    _minQtyCtrl = TextEditingController(
        text: e?['min_quantity']?.toString() ?? '1');
    _uomCtrl =
        TextEditingController(text: e?['unit_of_measurement'] ?? '');
    _selectedCategory = e?['category'];
    _isAvailable = e?['is_available'] as bool? ?? true;
    _availabilityOverride = e?['availability_override'] as bool?;
    _isFeatured = e?['featured'] as bool? ?? false;
    _imageUrl = e?['image_url'] ?? '';
    _bom = List<Map<String, dynamic>>.from(
        (e?['bill_of_materials'] as List?)?.map((x) => Map<String, dynamic>.from(x as Map)) ?? []);
    _bulkPricing = List<Map<String, dynamic>>.from(
        (e?['bulk_pricing'] as List?)?.map((x) => Map<String, dynamic>.from(x as Map)) ?? []);
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
            .map((d) => {
                  'id': d.id,
                  ...d.data(),
                })
            .toList();
        _materialsLoaded = true;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
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
    final ref = FirebaseStorage.instance
        .ref('products/$productId.$_pickedImageExt');
    final task = await ref.putData(
      _pickedImageBytes!,
      SettableMetadata(contentType: 'image/$_pickedImageExt'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a category'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final isEdit = widget.existing?['id'] != null;
      final docId = isEdit
          ? widget.existing!['id'] as String
          : FirebaseFirestore.instance.collection('Products').doc().id;

      final uploadedUrl = await _uploadImage(docId);

      // Use override if set; otherwise use the manual toggle.
      // BOM-based availability is recalculated automatically when employees update stock.
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
              '${_nameCtrl.text.trim()} ${isEdit ? 'updated' : 'created'}'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Dialog(
      backgroundColor: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: SizedBox(
        width: 560,
        height: MediaQuery.of(context).size.height * 0.88,
        child: Column(
          children: [
            // Dialog title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Product' : 'Add Product',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 16),

            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker
                      _sectionLabel('Product Image'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: _pickedImageBytes != null || _imageUrl.isNotEmpty
                                ? null
                                : _pickImage,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withValues(alpha: 0.07),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _pickedImageBytes != null
                                  ? Image.memory(_pickedImageBytes!,
                                      fit: BoxFit.cover)
                                  : _imageUrl.isNotEmpty
                                      ? Image.network(_imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.image_outlined,
                                                  color: Colors.white24,
                                                  size: 28))
                                      : const Icon(Icons.add_photo_alternate,
                                          color: Colors.white38, size: 32),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(
                                    Icons.upload_file_outlined,
                                    size: 14),
                                label: const Text('Upload Image',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.12),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                ),
                              ),
                              if (_pickedImageBytes != null ||
                                  _imageUrl.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: () => setState(() {
                                    _pickedImageBytes = null;
                                    _imageUrl = '';
                                  }),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: EdgeInsets.zero),
                                  child: const Text('Remove',
                                      style: TextStyle(fontSize: 11)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Name
                      _sectionLabel('Product Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration:
                            AppTheme.inputDecoration('e.g. Tarpaulin'),
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Category
                      _sectionLabel('Category *'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        items: widget.categories
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCategory = v),
                        dropdownColor: const Color(0xFF1a1a2e),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration:
                            AppTheme.inputDecoration('Select category'),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      _sectionLabel('Description'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        decoration:
                            AppTheme.inputDecoration('Brief description'),
                      ),
                      const SizedBox(height: 12),

                      // Price row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Price (₱)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: AppTheme.inputDecoration(
                                      'e.g. 25',
                                      icon: Icons.currency_exchange),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Pricing Unit'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _pricingUnitCtrl,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration: AppTheme.inputDecoration(
                                      'per sqft / piece / fixed'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Min qty + UOM row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Min. Quantity'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _minQtyCtrl,
                                  keyboardType:
                                      TextInputType.number,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration:
                                      AppTheme.inputDecoration('1'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Unit of Measurement'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _uomCtrl,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  decoration:
                                      AppTheme.inputDecoration(
                                          'pcs / sqft / roll'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Availability
                      _sectionLabel('Availability'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Manual override',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13)),
                                      const Text(
                                          'Force available/unavailable, ignoring BOM check',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _availabilityOverride != null,
                                  onChanged: (v) => setState(() =>
                                      _availabilityOverride = v
                                          ? _isAvailable
                                          : null),
                                  activeThumbColor: AppTheme.gold,
                                ),
                              ],
                            ),
                            if (_availabilityOverride != null) ...[
                              const Divider(
                                  color: Colors.white12, height: 16),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Set as available',
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13)),
                                  ),
                                  Switch(
                                    value:
                                        _availabilityOverride == true,
                                    onChanged: (v) => setState(() =>
                                        _availabilityOverride = v),
                                    activeThumbColor: const Color(0xFF4CAF50),
                                  ),
                                ],
                              ),
                            ],
                            if (_bom.isEmpty &&
                                _availabilityOverride == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                          'No BOM set — toggle availability manually',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                    ),
                                    Switch(
                                      value: _isAvailable,
                                      onChanged: (v) =>
                                          setState(() => _isAvailable = v),
                                      activeThumbColor: const Color(0xFF4CAF50),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Featured toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isFeatured
                              ? AppTheme.gold.withValues(alpha: 0.1)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isFeatured
                                ? AppTheme.gold.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_outline_rounded,
                              color: _isFeatured
                                  ? AppTheme.gold
                                  : Colors.white38,
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
                                            : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const Text(
                                    'Shows in the Featured Products section on the customer homepage',
                                    style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isFeatured,
                              onChanged: (v) =>
                                  setState(() => _isFeatured = v),
                              activeThumbColor: AppTheme.gold,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bill of Materials
                      Row(
                        children: [
                          _sectionLabel('Bill of Materials'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _materialsLoaded
                                ? () => _addBomItem()
                                : null,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Material',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_bom.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: const Text(
                              'No BOM set. Add materials to enable automatic availability tracking.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ),
                      ..._bom.asMap().entries.map((e) => _BomEditRow(
                            key: ValueKey('bom_${e.key}'),
                            item: e.value,
                            allMaterials: _allMaterials,
                            onChanged: (updated) =>
                                setState(() => _bom[e.key] = updated),
                            onRemove: () =>
                                setState(() => _bom.removeAt(e.key)),
                          )),
                      const SizedBox(height: 16),

                      // Bulk Pricing
                      Row(
                        children: [
                          _sectionLabel('Bulk Pricing (Optional)'),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _bulkPricing.add({
                                'min_quantity': 10,
                                'discount_type': 'rate',
                                'discount_value': 10.0,
                              });
                            }),
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Tier',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                                foregroundColor: AppTheme.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_bulkPricing.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                              'No bulk pricing. Add tiers to offer quantity discounts.',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ),
                      ..._bulkPricing
                          .asMap()
                          .entries
                          .map((e) => _BulkPricingRow(
                                item: e.value,
                                index: e.key,
                                onChanged: (updated) => setState(
                                    () => _bulkPricing[e.key] = updated),
                                onRemove: () => setState(
                                    () => _bulkPricing.removeAt(e.key)),
                              )),
                    ],
                  ),
                ),
              ),
            ),

            // Action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: AppTheme.primaryButton(),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : Text(widget.existing != null
                            ? 'Save Changes'
                            : 'Create Product'),
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

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600));
  }
}

// ── BOM edit row (interactive dropdown + qty) ─────────────────────────────────

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
        text: widget.item['quantity_per_unit']?.toString() ?? '1');

    // If stored ID not found in list, default to first material
    if (widget.allMaterials.isNotEmpty &&
        !widget.allMaterials.any((m) =>
            (m['material_id'] ?? m['id'])?.toString() == _materialId)) {
      final first = widget.allMaterials.first;
      _materialId =
          (first['material_id'] ?? first['id'])?.toString() ?? '';
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
                child: Text('Loading materials…',
                    style:
                        TextStyle(color: Colors.white38, fontSize: 12))),
            IconButton(
              icon: Icon(Icons.remove_circle_outline,
                  color: Colors.red.shade400, size: 16),
              onPressed: widget.onRemove,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      );
    }

    final valueExists = widget.allMaterials.any((m) =>
        (m['material_id'] ?? m['id'])?.toString() == _materialId);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Material dropdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Material',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: DropdownButton<String>(
                    value: valueExists ? _materialId : null,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1a1a2e),
                    underline: const SizedBox.shrink(),
                    hint: const Text('Select material',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 13)),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    items: widget.allMaterials.map((m) {
                      final id =
                          (m['material_id'] ?? m['id'])
                              ?.toString() ??
                              '';
                      final name =
                          m['material_name']?.toString() ?? '';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text('$id – $name',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      final mat = widget.allMaterials.firstWhere(
                          (m) =>
                              (m['material_id'] ?? m['id'])
                                  ?.toString() ==
                              id);
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
          const SizedBox(width: 8),
          // Qty field
          SizedBox(
            width: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qty/unit',
                    style: TextStyle(
                        color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 4),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  decoration: AppTheme.inputDecoration('1'),
                  onChanged: (_) => _notify(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Remove button
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                color: Colors.red.shade400, size: 18),
            onPressed: widget.onRemove,
            padding: const EdgeInsets.only(bottom: 2),
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

// ── Bulk pricing row ──────────────────────────────────────────────────────────

class _BulkPricingRow extends StatefulWidget {
  final Map<String, dynamic> item;
  final int index;
  final Function(Map<String, dynamic>) onChanged;
  final VoidCallback onRemove;

  const _BulkPricingRow(
      {required this.item,
      required this.index,
      required this.onChanged,
      required this.onRemove});

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
        text: widget.item['min_quantity']?.toString() ?? '10');
    _valueCtrl = TextEditingController(
        text: widget.item['discount_value']?.toString() ?? '10');
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('Tier ${widget.index + 1}',
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400, size: 16),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Min qty
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Min. Qty', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _minQtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: AppTheme.inputDecoration('10'),
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
                    const Text('Discount Type', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      value: _discountType,
                      dropdownColor: const Color(0xFF1a1a2e),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: AppTheme.inputDecoration(''),
                      items: const [
                        DropdownMenuItem(value: 'rate', child: Text('% Rate Off')),
                        DropdownMenuItem(value: 'fixed', child: Text('₱ Fixed Off')),
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
                    Text(_discountType == 'rate' ? 'Rate (%)' : 'Amount (₱)',
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _valueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: AppTheme.inputDecoration(_discountType == 'rate' ? '10' : '5'),
                      onChanged: (_) => _notify(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _discountType == 'rate'
                  ? 'Order ≥ ${_minQtyCtrl.text}: ${_valueCtrl.text}% off'
                  : 'Order ≥ ${_minQtyCtrl.text}: ₱${_valueCtrl.text} off per unit',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive
                  ? AppTheme.gold.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? AppTheme.gold : Colors.white60,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
