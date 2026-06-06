import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'customer_order_screen.dart';

class CustomerProductsScreen extends StatefulWidget {
  final String? initialCategory;
  const CustomerProductsScreen({super.key, this.initialCategory});

  @override
  State<CustomerProductsScreen> createState() => _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerProductsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _searchQuery = '';
  String? _selectedCategory;
  Map<String, double> _stockMap = {};
  bool _stockLoaded = false;

  static const _categories = [
    'Large Format & Signage',
    'Stickers & Labels',
    'Photo & Card Prints',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _loadStockMap();
  }

  Future<void> _loadStockMap() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('RawMaterials').get();
      if (!mounted) return;
      final map = <String, double>{};
      for (final doc in snap.docs) {
        map[doc.id] = (doc.data()['current_stock'] as num?)?.toDouble() ?? 0.0;
      }
      setState(() { _stockMap = map; _stockLoaded = true; });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final h = isWide ? 24.0 : 16.0;
        final cols = isWide ? (constraints.maxWidth >= 900 ? 4 : 3) : 2;

        // StreamBuilder is the outer widget so Scrollbar can directly wrap
        // CustomScrollView — the same pattern admin/employee screens use.
        return StreamBuilder<QuerySnapshot>(
          stream: _buildQuery(),
          builder: (context, snapshot) {
            List<QueryDocumentSnapshot> products = [];
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;

            if (!isLoading && snapshot.hasData) {
              products = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map;
                if (data['is_available'] == false) return false;
                if (_searchQuery.isEmpty) return true;
                final name =
                    data['product_name']?.toString().toLowerCase() ?? '';
                return name.contains(_searchQuery.toLowerCase());
              }).toList();
            }

            return Scrollbar(
              controller: _scrollCtrl,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 6,
              radius: const Radius.circular(3),
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  // ── Page header banner ──────────────────────────────
                  SliverToBoxAdapter(child: _PageBanner(isWide: isWide)),

                  // ── Search + filters ────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(h, 20, h, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SearchBar(
                            controller: _searchCtrl,
                            onChanged: (v) =>
                                setState(() => _searchQuery = v),
                          ),
                          const SizedBox(height: 16),
                          _CategoryGrid(
                            categories: _categories,
                            selected: _selectedCategory,
                            onSelect: (cat) =>
                                setState(() => _selectedCategory = cat),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Loading indicator ───────────────────────────────
                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.gold),
                      ),
                    )
                  // ── Empty state ─────────────────────────────────────
                  else if (products.isEmpty)
                    SliverFillRemaining(
                      child: _EmptyState(
                        query:
                            _searchQuery.isNotEmpty ? _searchQuery : null,
                        category: _selectedCategory,
                      ),
                    )
                  // ── Frosted glass enclosure with label + grid ───────
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(h, 20, h, 32),
                      sliver: SliverToBoxAdapter(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 12, 9, 31)
                                    .withValues(alpha: 0.40),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.30),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.18),
                                    blurRadius: 32,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(
                                    category: _selectedCategory,
                                    count: products.length,
                                    isLoading: isLoading,
                                    onLight: true,
                                  ),
                                  const SizedBox(height: 14),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: cols,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 0.60,
                                    ),
                                    itemCount: products.length,
                                    itemBuilder: (_, i) => _ProductCard(
                                      data: products[i].data()
                                          as Map<String, dynamic>,
                                      docId: products[i].id,
                                      stockMap: _stockMap,
                                      stockLoaded: _stockLoaded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('Products');
    if (_selectedCategory != null) {
      q = q.where('category', isEqualTo: _selectedCategory);
    }
    return q.snapshots();
  }
}

// ── Section label — updates when category is selected ────────────────────────

class _SectionLabel extends StatelessWidget {
  final String? category;
  final int count;
  final bool isLoading;
  final bool onLight;

  const _SectionLabel({
    required this.category,
    required this.count,
    required this.isLoading,
    this.onLight = false,
  });

  @override
  Widget build(BuildContext context) {
    // Shows selected category name; falls back to 'All Products'
    final label = category ?? 'All Products';
    // Dark text when on the frosted light container, white otherwise
    final textColor = onLight
        ? const Color.fromARGB(255, 255, 255, 255)
        : Colors.white;

    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: onLight ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.50)),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Page banner ───────────────────────────────────────────────────────────────

class _PageBanner extends StatelessWidget {
  final bool isWide;
  const _PageBanner({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final h = isWide ? 24.0 : 16.0;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(h, 20, h, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F0B1C), Color(0xFF1C0F4A), Color(0xFF0D1E52)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 36,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF5931C8).withValues(alpha: 0.22),
            blurRadius: 56,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiagonalPainter())),
          Positioned(
            right: -20,
            top: -20,
            child: _Glow(
              size: 220,
              color: const Color(0xFF6C3FD4).withValues(alpha: 0.45),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -30,
            child: _Glow(
              size: 160,
              color: AppTheme.gold.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 24,
              vertical: isWide ? 32 : 24,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _BannerText(showPills: false)),
                      const SizedBox(width: 24),
                      const _BannerTrustPills(),
                    ],
                  )
                : _BannerText(showPills: true),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;
  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

class _BannerText extends StatelessWidget {
  final bool showPills;
  const _BannerText({required this.showPills});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'ALL PRODUCTS',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Browse Our\n'),
              TextSpan(
                text: 'Print ',
                children: [
                  TextSpan(
                    text: 'Catalogue.',
                    style: TextStyle(color: AppTheme.gold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tarpaulins, menus, stickers & more — filter by category or search below.',
          style: TextStyle(color: Color(0xFFBBB8CC), fontSize: 13, height: 1.6),
        ),
        if (showPills) ...[
          const SizedBox(height: 16),
          const _BannerTrustPills(),
        ],
      ],
    );
  }
}

// ── Trust pills ───────────────────────────────────────────────────────────────

class _BannerTrustPills extends StatelessWidget {
  const _BannerTrustPills();

  @override
  Widget build(BuildContext context) {
    const pills = [
      _TrustPill(icon: Icons.bolt_rounded, label: 'Fast Turnaround'),
      _TrustPill(icon: Icons.verified_outlined, label: 'Quality Print'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pills
          .map(
            (p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.icon,
                    size: 14,
                    color: AppTheme.gold.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p.label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TrustPill {
  final IconData icon;
  final String label;
  const _TrustPill({required this.icon, required this.label});
}

class _DiagonalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    const spacing = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF6C3FD4).withValues(alpha: 0.06),
            blurRadius: 24,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: AppTheme.gold.withValues(alpha: 0.75),
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

// ── Category grid ─────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final all = ['All', ...categories];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: all.map((cat) {
        final isAll = cat == 'All';
        final isSelected = isAll ? selected == null : selected == cat;
        return _CategoryChip(
          label: cat,
          isSelected: isSelected,
          onTap: () {
            if (isAll) {
              onSelect(null);
            } else {
              onSelect(isSelected ? null : cat);
            }
          },
        );
      }).toList(),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.gold : const Color(0xFF1F1B30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppTheme.gold
                : Colors.white.withValues(alpha: 0.13),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.20),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF1A0A00)
                : Colors.white.withValues(alpha: 0.70),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: isSelected ? 0.1 : 0,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? query;
  final String? category;
  const _EmptyState({this.query, this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1F1B30),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: Colors.white24,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              query != null
                  ? 'No results for "$query"'
                  : category != null
                  ? 'No products in "$category"'
                  : 'No products available',
              style: const TextStyle(
                color: Color(0xFFBBB8CC),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or category filter.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final Map<String, double> stockMap;
  final bool stockLoaded;
  const _ProductCard({
    required this.data,
    required this.docId,
    required this.stockMap,
    required this.stockLoaded,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.data['product_name']?.toString() ?? 'Product';
    // Use short_description on the card; fall back to description for old products.
    final cardDesc = (widget.data['short_description']?.toString().isNotEmpty == true
            ? widget.data['short_description']
            : widget.data['description'])
        ?.toString() ?? '';
    final price = widget.data['price'];
    final rawUnit = widget.data['pricing_unit']?.toString() ?? '';
    final pricingQty = widget.data['pricing_qty'];
    final unitSuffix = rawUnit == 'per_sqft'
        ? ' / sq ft'
        : rawUnit == 'per_sqin'
        ? ' / sq in'
        : rawUnit == 'per_piece'
        ? ' / piece'
        : rawUnit == 'per_qty'
        ? ' / ${pricingQty ?? 100} pcs'
        : (rawUnit.isNotEmpty ? ' $rawUnit' : '');

    // Build price display — show range when variant prices differ.
    final variantPrices = widget.data['variant_prices'] as Map?;
    String priceText;
    if (variantPrices != null && variantPrices.isNotEmpty) {
      final prices = variantPrices.values
          .map((v) => (v as num).toDouble())
          .toList()
        ..sort();
      if (prices.first == prices.last) {
        priceText = '₱${prices.first.toStringAsFixed(prices.first % 1 == 0 ? 0 : 2)}$unitSuffix';
      } else {
        priceText =
            '₱${prices.first.toStringAsFixed(prices.first % 1 == 0 ? 0 : 2)}–'
            '₱${prices.last.toStringAsFixed(prices.last % 1 == 0 ? 0 : 2)}$unitSuffix';
      }
    } else if (price != null) {
      priceText = '₱$price$unitSuffix';
    } else {
      priceText = 'See pricing';
    }
    final imageUrl = widget.data['image_url']?.toString() ?? '';
    final category = widget.data['category']?.toString() ?? '';
    final variants = (widget.data['material_options'] as List?) ?? [];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerOrderScreen(
              product: {'product_id': widget.docId, ...widget.data},
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? AppTheme.gold.withValues(alpha: 0.70)
                  : Colors.white.withValues(alpha: 0.30),
              width: _hovered ? 1.5 : 1.2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image ──
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (category.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.60),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Color(0xFFBBB8CC),
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Info ──
              Expanded(
                flex: 4,
                child: Padding(
padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cardDesc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          cardDesc,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (variants.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: variants.take(3).map((v) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20)),
                            ),
                            child: Text(
                              v.toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        priceText,
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: AppTheme.gold.withValues(alpha: 0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (widget.stockLoaded) Builder(builder: (_) {
                        final bom = (widget.data['bill_of_materials'] as List?) ?? [];
                        if (bom.isEmpty) return const SizedBox.shrink();
                        final max = _maxForCard(widget.data, widget.stockMap);
                        final inStock = max > 0;
                        final color = inStock ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(children: [
                            Container(width: 6, height: 6,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(inStock ? 'In stock' : 'Out of stock',
                              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }),
const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _hovered
                                ? AppTheme.gold
                                : AppTheme.gold.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.55),
                            ),
                            boxShadow: _hovered
                                ? [
                                    BoxShadow(
                                      color: AppTheme.gold.withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 13,
                                color: _hovered
                                    ? const Color(0xFF1A0A00)
                                    : AppTheme.gold,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Add to Cart',
                                style: TextStyle(
                                  color: _hovered
                                      ? const Color(0xFF1A0A00)
                                      : AppTheme.gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF6C3FD4).withValues(alpha: 0.10),
          Colors.white.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.image_outlined, color: Colors.white24, size: 32),
  );
}

// Returns the max orderable quantity for a product card (best-case across all variants).
// Infinity = no BOM / always available. 0 = nothing in stock.
double _maxForCard(Map<String, dynamic> data, Map<String, double> stockMap) {
  final bom = (data['bill_of_materials'] as List?) ?? [];
  if (bom.isEmpty) return double.infinity;

  double itemMin(List items) {
    double? m;
    for (final e in items) {
      final matId = (e['material_id'] as String?) ?? '';
      if (matId.isEmpty) continue;
      final qpu = (e['quantity_per_unit'] as num?)?.toDouble() ?? 1.0;
      if (qpu <= 0) continue;
      final v = (stockMap[matId] ?? 0.0) / qpu;
      if (m == null || v < m) m = v;
    }
    return m ?? double.infinity;
  }

  final shared = bom.where((e) {
    final opt = (e['for_material_option'] as String?)?.trim() ?? '';
    return opt.isEmpty;
  }).toList();
  final sharedMin = itemMin(shared);

  final matOpts = (data['material_options'] as List?) ?? [];
  if (matOpts.isEmpty) return sharedMin;

  // For each variant, compute combined available qty; return best across variants.
  double best = 0;
  for (final v in matOpts) {
    final vStr = v.toString().trim();
    final varItems = bom.where((e) {
      final opt = (e['for_material_option'] as String?)?.trim() ?? '';
      return opt.isNotEmpty && opt == vStr;
    }).toList();
    final varMin = itemMin(varItems);
    final combined = sharedMin < varMin ? sharedMin : varMin;
    if (combined > best) best = combined;
  }
  return best;
}
