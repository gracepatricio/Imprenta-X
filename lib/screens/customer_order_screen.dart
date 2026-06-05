import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/design_file_picker.dart';
import '../services/cart_manager.dart';
import 'app_theme.dart';

class CustomerOrderScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final CartItem? initialItem; // non-null when editing an existing cart item
  final int?      editIndex;   // index in CartManager.items to replace

  const CustomerOrderScreen({
    super.key,
    required this.product,
    this.initialItem,
    this.editIndex,
  });

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  // Size
  final _widthCtrl  = TextEditingController(text: '2');
  final _heightCtrl = TextEditingController(text: '3');
  double _widthFt  = 2;
  double _heightFt = 3;
  String _sizePreset = '2×3 ft';

  // Order options
  int     _quantity = 1;
  String? _material;

  // Files
  final List<CartFile> _files = [];
  bool _addingToCart = false;

  // Notes
  final _notesCtrl = TextEditingController();

  // ── Product accessors ────────────────────────────────────────────────────────

  String get _productName => widget.product['product_name']?.toString() ?? '';
  String get _category    => widget.product['category']?.toString() ?? '';
  String get _description => widget.product['description']?.toString() ?? '';
  double get _basePrice   => (widget.product['price'] as num?)?.toDouble() ?? 0;
  String get _pricingUnit => widget.product['pricing_unit']?.toString() ?? '';
  int    get _minQty      => (widget.product['min_quantity'] as num?)?.toInt() ?? 1;
  String get _imageUrl    => widget.product['image_url']?.toString() ?? '';

  // Show size inputs for area-based pricing (sq ft or sq in).
  bool get _needsSizeInput =>
      _pricingUnit == 'per_sqft' || _pricingUnit == 'per_sqin';

  // When true, size inputs are in inches; internally still stored as feet (÷12).
  bool get _sizeInInches => _pricingUnit == 'per_sqin';

  // Presets for sq ft products (in feet).
  static const _sizePresets = [
    '2×3 ft', '3×4 ft', '4×6 ft', '4×8 ft', '5×10 ft', 'Custom',
  ];
  static const _presetDims = {
    '2×3 ft':  (2.0, 3.0),
    '3×4 ft':  (3.0, 4.0),
    '4×6 ft':  (4.0, 6.0),
    '4×8 ft':  (4.0, 8.0),
    '5×10 ft': (5.0, 10.0),
  };

  // Presets for sq in products (values stored as feet = inches÷12).
  static const _sizePresetsIn = [
    '4×4 in', '4×6 in', '6×8 in', '8×10 in', '10×12 in', 'Custom',
  ];
  static final _presetDimsIn = <String, (double, double)>{
    '4×4 in':   (4 / 12.0,  4 / 12.0),
    '4×6 in':   (4 / 12.0,  6 / 12.0),
    '6×8 in':   (6 / 12.0,  8 / 12.0),
    '8×10 in':  (8 / 12.0, 10 / 12.0),
    '10×12 in': (10 / 12.0, 12 / 12.0),
  };

  // Material options (variants) come from product's material_options field.
  List<String> get _materialList {
    final raw = widget.product['material_options'] as List?;
    if (raw != null && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return [];
  }

  // Per-variant price override. Falls back to base price if no override set.
  double get _effectiveBasePrice {
    if (_material != null) {
      final vp = widget.product['variant_prices'] as Map?;
      if (vp != null) {
        final override = vp[_material];
        if (override != null) return (override as num).toDouble();
      }
    }
    return _basePrice;
  }

  // How many pieces per pricing "unit" (for per_qty products like calling cards).
  int get _pricingQty =>
      (widget.product['pricing_qty'] as num?)?.toInt() ?? 100;

  // ── Pricing ──────────────────────────────────────────────────────────────────

  double get _subtotal {
    if (_pricingUnit == 'per_sqin') {
      // widthFt/heightFt stored as feet; multiply ×144 for sq in.
      return _effectiveBasePrice * _widthFt * _heightFt * 144 * _quantity;
    }
    if (_needsSizeInput) {
      return _effectiveBasePrice * _widthFt * _heightFt * _quantity;
    }
    return _effectiveBasePrice * _quantity;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  // ── Turnaround computation ────────────────────────────────────────────────────

  double get _turnaroundExact {
    final cat = _category.toLowerCase();
    double d;

    if (cat.contains('calling card')) {
      if (_quantity <= 100) d = 0.5;
      else if (_quantity <= 500) d = 1.0;
      else d = (_quantity / 500).ceilToDouble().clamp(2.0, 7.0);
    } else if (cat.contains('sticker') || cat.contains('photo')) {
      if (_quantity <= 50)  d = 0.5;
      else if (_quantity <= 200) d = 1.0;
      else d = (_quantity / 200).ceilToDouble().clamp(2.0, 5.0);
    } else if (cat.contains('large format')) {
      final area = _needsSizeInput ? _widthFt * _heightFt : 4.0;
      if (area <= 6)       d = 0.5;
      else if (area <= 15) d = 1.0;
      else if (area <= 30) d = 1.5;
      else                 d = 2.0;
      if (_quantity > 1) d = (d * _quantity).clamp(d, 14.0);
    } else if (cat.contains('invitation')) {
      d = _quantity <= 50 ? 1.0 : (_quantity <= 200 ? 2.0 : 3.0);
    } else if (cat.contains('menu') || cat.contains('board')) {
      d = _quantity.toDouble().clamp(1.0, 3.0);
    } else {
      d = 1.0;
    }

    return d.clamp(0.5, 21.0);
  }

  String get _turnaroundLabel {
    final d = _turnaroundExact;
    if (d <= 0.5) return 'Same day';
    if (d <  1.0) return '< 1 day';
    if (d == 1.0) return '~1 day';
    if (d <= 1.5) return '~1–2 days';
    if (d <= 2.0) return '~2 days';
    return '~${d.ceil()} days';
  }

  @override
  void initState() {
    super.initState();

    final edit = widget.initialItem;
    if (edit != null) {
      // Pre-populate from existing cart item
      _quantity = edit.quantity;
      _material = edit.material;
      _notesCtrl.text = edit.notes;
      _files.addAll(edit.files);

      if (edit.widthFt != null) {
        _widthFt = edit.widthFt!;
        _widthCtrl.text = edit.widthFt!.toStringAsFixed(
            edit.widthFt! % 1 == 0 ? 0 : 1);
      }
      if (edit.heightFt != null) {
        _heightFt = edit.heightFt!;
        _heightCtrl.text = edit.heightFt!.toStringAsFixed(
            edit.heightFt! % 1 == 0 ? 0 : 1);
      }
      // Match size preset
      if (edit.widthFt != null && edit.heightFt != null) {
        final match = _presetDims.entries.firstWhere(
          (e) => e.value.$1 == edit.widthFt && e.value.$2 == edit.heightFt,
          orElse: () => const MapEntry('Custom', (0.0, 0.0)),
        );
        _sizePreset = match.key;
      }
    } else {
      _quantity = _minQty;
      if (_materialList.isNotEmpty) _material = _materialList.first;
      // For per_sqin, start at 4×4 inches (stored as feet).
      if (_sizeInInches) {
        _widthFt  = 4 / 12.0;
        _heightFt = 4 / 12.0;
        _widthCtrl.text  = '4';
        _heightCtrl.text = '4';
        _sizePreset = '4×4 in';
      }
    }
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── File picking ─────────────────────────────────────────────────────────────

  static const int _maxFileMB = 25;

  Future<void> _pickFiles() async {
    try {
      final picked = await pickDesignFiles(multiple: true);
      if (picked == null || !mounted) return;
      final rejected = <String>[];
      setState(() {
        for (final (name, bytes) in picked) {
          final mb = bytes.lengthInBytes / (1024 * 1024);
          if (mb > _maxFileMB) {
            rejected.add('$name (${mb.toStringAsFixed(1)} MB)');
          } else {
            _files.add(CartFile(name: name, bytes: bytes));
          }
        }
      });
      if (rejected.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Skipped (>${_maxFileMB}MB): ${rejected.join(', ')}'),
          backgroundColor: Colors.orange.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('File picker error: $e'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  // ── Add / Update cart ────────────────────────────────────────────────────────

  // For Large Format Printing, enforce minimum 2×3 ft (either orientation).
  bool get _sizeIsValid {
    if (!_needsSizeInput) return true;
    if (!_category.toLowerCase().contains('large format')) return true;
    // Valid if one side ≥ 3 and the other ≥ 2
    return ((_widthFt >= 3 && _heightFt >= 2) ||
            (_widthFt >= 2 && _heightFt >= 3));
  }

  Future<void> _addToCart() async {
    if (_addingToCart) return;
    if (_needsSizeInput && !_sizeIsValid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Minimum tarpaulin size is 2×3 ft (or 3×2 ft).'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    if (_materialList.isNotEmpty && _material == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a material / finish.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please upload at least one design file.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _addingToCart = true);

    // Upload files to Firebase Storage so they survive logout/refresh.
    final cartFiles = <CartFile>[];
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    for (final f in _files) {
      if (f.url != null) {
        cartFiles.add(f); // already uploaded (edit mode)
        continue;
      }
      try {
        final ext  = f.name.split('.').last.toLowerCase();
        final ts   = DateTime.now().millisecondsSinceEpoch;
        final path = 'cart_files/$uid/${ts}_${f.name}';
        final ref  = FirebaseStorage.instance.ref(path);
        final task = await ref.putData(
          f.bytes!,
          SettableMetadata(contentType: _mimeType(ext)),
        );
        final url = await task.ref.getDownloadURL();
        cartFiles.add(CartFile(name: f.name, bytes: f.bytes, url: url, path: path));
      } catch (_) {
        cartFiles.add(f); // keep bytes-only if upload fails
      }
    }

    if (!mounted) return;
    setState(() => _addingToCart = false);

    final item = CartItem(
      productId:   widget.product['product_id']?.toString() ?? '',
      productName: _productName,
      category:    _category,
      imageUrl:    _imageUrl,
      unitPrice:   _effectiveBasePrice, // uses variant price if selected
      pricingUnit: _pricingUnit,
      quantity:    _quantity,
      widthFt:     _needsSizeInput ? _widthFt  : null,
      heightFt:    _needsSizeInput ? _heightFt : null,
      material:    _material,
      files:       cartFiles,
      notes:       _notesCtrl.text.trim(),
    );

    final isEdit = widget.editIndex != null;
    if (isEdit) {
      CartManager.updateAt(widget.editIndex!, item);
    } else {
      CartManager.add(item);
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(isEdit ? '$_productName updated in cart!' : '$_productName added to cart!'),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 2),
    ));
  }

  String _mimeType(String ext) => switch (ext) {
    'pdf'           => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'psd'           => 'image/vnd.adobe.photoshop',
    'ai'            => 'application/postscript',
    _               => 'application/octet-stream',
  };

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
decoration: AppTheme.backgroundDecoration(context),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Customize Order',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) => constraints.maxWidth >= 700
                    ? _wideLayout()
                    : _narrowLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideLayout() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 28, 22, 68).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _productImage(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 28, 22, 68).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 6))],
                ),
                child: SingleChildScrollView(child: _orderForm()),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 28, 22, 68).withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 6))],
                    ),
                    child: _summary(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _addToCartBtn(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _narrowLayout() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    child: Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 28, 22, 68).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _productImage(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 28, 22, 68).withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 6))],
              ),
              child: _orderForm(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 28, 22, 68).withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 6))],
              ),
              child: _summary(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _addToCartBtn(),
      ],
    ),
  );

  Widget _productImage() {
    return _imageUrl.isNotEmpty
        ? Image.network(_imageUrl, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imgPlaceholder())
        : _imgPlaceholder();
  }

  Widget _imgPlaceholder() => Container(
    color: Colors.white.withValues(alpha: 0.06),
    child: const Center(
        child: Icon(Icons.image_outlined, color: Colors.white24, size: 48)),
  );

  // ── Order form ───────────────────────────────────────────────────────────────

  Widget _orderForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_productName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        if (_description.isNotEmpty)
          Text(_description,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),

        // ── Pricing info row ─────────────────────────────────────────────
        if (_pricingUnit.isNotEmpty) ...[
          Row(
            children: [
              Text(_category,
                  style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
              const SizedBox(width: 8),
              Text(
                _pricingUnit == 'per_qty'
                    ? '₱${_effectiveBasePrice.toStringAsFixed(0)} per $_pricingQty pcs'
                    : _pricingUnit == 'per_sqin'
                    ? '₱${_effectiveBasePrice.toStringAsFixed(2)} / sq in'
                    : _pricingUnit == 'per_sqft'
                    ? '₱${_effectiveBasePrice.toStringAsFixed(2)} / sq ft'
                    : '₱${_effectiveBasePrice.toStringAsFixed(2)} / piece',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
        ],

        // ── Size (sq ft or sq in products) ───────────────────────────────
        if (_needsSizeInput) ...[
          _label(_sizeInInches ? 'Size (in inches)' : 'Size (in feet)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: (_sizeInInches ? _sizePresetsIn : _sizePresets)
                .map((p) => _chip(p, _sizePreset == p, () {
                      final dims = _sizeInInches
                          ? _presetDimsIn[p]
                          : _presetDims[p];
                      setState(() {
                        _sizePreset = p;
                        if (dims != null) {
                          _widthFt  = dims.$1;
                          _heightFt = dims.$2;
                          // Display in the appropriate unit.
                          _widthCtrl.text  = _sizeInInches
                              ? (dims.$1 * 12).toStringAsFixed(0)
                              : dims.$1.toString();
                          _heightCtrl.text = _sizeInInches
                              ? (dims.$2 * 12).toStringAsFixed(0)
                              : dims.$2.toString();
                        }
                      });
                    }))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dimField(
                _sizeInInches ? 'Width (in)' : 'Width',
                _widthCtrl,
                (v) {
                  final d = double.tryParse(v);
                  if (d != null && d > 0) {
                    _widthFt = _sizeInInches ? d / 12.0 : d;
                    setState(() {});
                  }
                },
              )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('×',
                    style: TextStyle(color: Colors.white54, fontSize: 20)),
              ),
              Expanded(child: _dimField(
                _sizeInInches ? 'Height (in)' : 'Height',
                _heightCtrl,
                (v) {
                  final d = double.tryParse(v);
                  if (d != null && d > 0) {
                    _heightFt = _sizeInInches ? d / 12.0 : d;
                    setState(() {});
                  }
                },
              )),
            ],
          ),
          if (!_sizeInInches &&
              _category.toLowerCase().contains('large format') &&
              !_sizeIsValid) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orangeAccent, size: 13),
                const SizedBox(width: 6),
                const Text(
                  'Minimum size is 2×3 ft',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],

        // ── Quantity ─────────────────────────────────────────────────────
        _label(_pricingUnit == 'per_qty'
            ? 'Quantity (units of $_pricingQty pcs)'
            : 'Quantity'),
        const SizedBox(height: 8),
        Row(
          children: [
            _qtyBtn(Icons.remove,
                    () { if (_quantity > _minQty) setState(() => _quantity--); }),
            const SizedBox(width: 16),
            Text('$_quantity',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            _qtyBtn(Icons.add, () => setState(() => _quantity++)),
            const SizedBox(width: 10),
            Text(
              _pricingUnit == 'per_qty'
                  ? 'min. $_minQty unit = ${_minQty * _pricingQty} pcs'
                  : 'min. $_minQty',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Variant / Material ────────────────────────────────────────────
        if (_materialList.isNotEmpty) ...[
          _label('Variant'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _materialList
                .map((m) => _chip(
                m, _material == m, () => setState(() => _material = m)))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // ── File upload ──────────────────────────────────────────────────
        _label('Upload Design Files'),
        const SizedBox(height: 4),
        const Text('PDF, JPG, PNG, PSD, AI — max 25MB per file',
            style: TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickFiles,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    color: _files.isEmpty
                        ? Colors.white38
                        : AppTheme.gold,
                    size: 32),
                const SizedBox(height: 6),
                const Text('Click to upload files',
                    style:
                    TextStyle(color: Colors.white54, fontSize: 12)),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._files.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined,
                            size: 14, color: AppTheme.gold),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.value.name,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _files.removeAt(e.key)),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white38),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Notes ────────────────────────────────────────────────────────
        _label('Notes for our Team (optional)'),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: AppTheme.inputDecoration(
              'Special requests or instructions...'),
        ),
        const SizedBox(height: 16),

        // ── Pickup notice ────────────────────────────────────────────────
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
            Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.store_outlined, color: AppTheme.gold, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pick-Up Only — no delivery available.',
                  style:
                  TextStyle(color: AppTheme.gold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Summary ──────────────────────────────────────────────────────────────────

  Widget _summary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Summary',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_needsSizeInput)
          _sumRow(
            'Size',
            _sizeInInches
                ? '${(_widthFt * 12).toStringAsFixed(0)}in × ${(_heightFt * 12).toStringAsFixed(0)}in'
                : '${_widthFt}ft × ${_heightFt}ft',
          ),
        _sumRow(
          'Qty',
          _pricingUnit == 'per_qty'
              ? '$_quantity unit${_quantity == 1 ? '' : 's'} = ${_quantity * _pricingQty} pcs'
              : '$_quantity',
        ),
        if (_material != null) _sumRow('Variant', _material!),
        _sumRow('Shipping', 'Pick-Up'),
        _sumRow('Turnaround', _turnaroundLabel),
        const Divider(color: Colors.white12, height: 16),
        Row(
          children: [
            const Expanded(
              child: Text('Subtotal',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Text('₱${_subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('50% Downpayment Required',
                  style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('₱${(_subtotal * 0.5).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addToCartBtn() => SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: _addingToCart ? null : _addToCart,
      icon: _addingToCart
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(
              widget.editIndex != null ? Icons.check_rounded : Icons.shopping_cart_outlined,
              size: 18,
            ),
      label: Text(
        _addingToCart
            ? 'Uploading files…'
            : (widget.editIndex != null ? 'Update Cart Item' : 'Add to Cart'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      style: AppTheme.primaryButton(),
    ),
  );

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  Widget _chip(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.gold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.gold.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? AppTheme.gold : Colors.white70,
                  fontSize: 12)),
        ),
      );

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border:
        Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    ),
  );

  Widget _dimField(String label, TextEditingController ctrl,
      ValueChanged<String> onChanged) {
    return TextField(
      controller: ctrl,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: AppTheme.inputDecoration('$label (ft)'),
      onChanged: onChanged,
    );
  }

  Widget _sumRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12))),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}