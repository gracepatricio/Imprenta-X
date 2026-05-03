import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/cart_manager.dart';
import 'app_theme.dart';

class CustomerOrderScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  const CustomerOrderScreen({super.key, required this.product});

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

  // Show size inputs only when pricing is area-based (per sq ft / sq m)
  bool get _needsSizeInput => _pricingUnit.toLowerCase().contains('sq');

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

  static const _materialMap = {
    'Large Format Printing': ['Standard Tarp', 'Premium Tarp', 'Mesh Tarp'],
    'Sticker Printing':      ['Glossy Vinyl', 'Matte Vinyl', 'Clear Vinyl'],
    'Photo Printing':        ['Glossy', 'Matte', 'Satin'],
    'Menu Board':            ['Standard', 'Premium Backlit'],
    'Invitations':           ['Matte', 'Glossy', 'Kraft Paper'],
    'Calling Cards':         ['Matte', 'Glossy', 'UV Coated'],
  };

  List<String> get _materialList => _materialMap[_category] ?? [];

  // ── Pricing ──────────────────────────────────────────────────────────────────

  double get _subtotal {
    if (_needsSizeInput) return _basePrice * _widthFt * _heightFt * _quantity;
    return _basePrice * _quantity;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _quantity = _minQty;
    if (_materialList.isNotEmpty) _material = _materialList.first;
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
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'psd', 'ai'],
        withData: true,
      );
      if (result == null || !mounted) return;
      final rejected = <String>[];
      setState(() {
        for (final f in result.files) {
          if (f.bytes == null) continue;
          final mb = f.bytes!.lengthInBytes / (1024 * 1024);
          if (mb > _maxFileMB) {
            rejected.add('${f.name} (${mb.toStringAsFixed(1)} MB)');
          } else {
            _files.add(CartFile(name: f.name, bytes: f.bytes!));
          }
        }
      });
      if (rejected.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Skipped (>${_maxFileMB}MB): ${rejected.join(', ')}'),
          backgroundColor: Colors.orange.shade700,
        ));
      }
    } catch (_) {}
  }

  // ── Add to cart ───────────────────────────────────────────────────────────────

  void _addToCart() {
    // Validate required fields
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
    CartManager.add(CartItem(
      productId:   widget.product['product_id']?.toString() ?? '',
      productName: _productName,
      category:    _category,
      imageUrl:    _imageUrl,
      unitPrice:   _basePrice,
      pricingUnit: _pricingUnit,
      quantity:    _quantity,
      widthFt:     _needsSizeInput ? _widthFt  : null,
      heightFt:    _needsSizeInput ? _heightFt : null,
      material:    _material,
      files:       List.from(_files),
      notes:       _notesCtrl.text.trim(),
    ));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text('$_productName added to cart!'),
      backgroundColor: Colors.green.shade700,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: AppTheme.glassCard(opacity: 0.15),
            clipBehavior: Clip.antiAlias,
            child: _productImage(),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassCard(opacity: 0.15),
            child: SingleChildScrollView(child: _orderForm()),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(opacity: 0.18),
                child: _summary(),
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
          child: Container(
            decoration: AppTheme.glassCard(opacity: 0.15),
            clipBehavior: Clip.antiAlias,
            child: _productImage(),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(opacity: 0.15),
          child: _orderForm(),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard(opacity: 0.18),
          child: _summary(),
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
        const SizedBox(height: 2),
        Row(
          children: [
            Text(_category,
                style: const TextStyle(color: AppTheme.gold, fontSize: 12)),
            if (_pricingUnit.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text('₱${_basePrice.toStringAsFixed(0)} / $_pricingUnit',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11)),
            ],
          ],
        ),
        if (_description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_description,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 16),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),

        // ── Size (only if priced per sq ft) ──────────────────────────────
        if (_needsSizeInput) ...[
          _label('Size (in feet)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _sizePresets.map((p) => _chip(p, _sizePreset == p, () {
              final dims = _presetDims[p];
              setState(() {
                _sizePreset = p;
                if (dims != null) {
                  _widthFt  = dims.$1;
                  _heightFt = dims.$2;
                  _widthCtrl.text  = dims.$1.toString();
                  _heightCtrl.text = dims.$2.toString();
                }
              });
            })).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dimField('Width', _widthCtrl, (v) {
                final d = double.tryParse(v);
                if (d != null && d > 0) { _widthFt = d; setState(() {}); }
              })),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('×',
                    style: TextStyle(color: Colors.white54, fontSize: 20)),
              ),
              Expanded(child: _dimField('Height', _heightCtrl, (v) {
                final d = double.tryParse(v);
                if (d != null && d > 0) { _heightFt = d; setState(() {}); }
              })),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Quantity ─────────────────────────────────────────────────────
        _label('Quantity'),
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
            Text('min. $_minQty',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 16),

        // ── Material ─────────────────────────────────────────────────────
        if (_materialList.isNotEmpty) ...[
          _label('Material / Finish'),
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
          _sumRow('Size', '${_widthFt}ft × ${_heightFt}ft'),
        _sumRow('Qty', '$_quantity'),
        if (_material != null) _sumRow('Material', _material!),
        _sumRow('Shipping', 'Pick-Up'),
        _sumRow('Turnaround', '2-3 days'),
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
      onPressed: _addToCart,
      icon: const Icon(Icons.shopping_cart_outlined, size: 18),
      label: const Text('Add to Cart',
          style:
          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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