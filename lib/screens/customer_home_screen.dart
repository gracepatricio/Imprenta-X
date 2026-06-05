import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'customer_order_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  final void Function([String? category]) onViewProducts;
  const CustomerHomeScreen({super.key, required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final scrollCtrl = ScrollController();
        return Scrollbar(
          controller: scrollCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Hero(isWide: isWide, onViewProducts: onViewProducts),
                _FeaturedSection(
                  isWide: isWide,
                  onViewProducts: onViewProducts,
                ),
                _ServicesSection(
                  isWide: isWide,
                  onViewProducts: onViewProducts,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Frosted Glass Section Container ──────────────────────────────────────────

class _FrostedSectionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;

  const _FrostedSectionContainer({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(
                255,
                12,
                9,
                31,
              ).withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final bool isWide;
  final void Function([String? category]) onViewProducts;
  const _Hero({required this.isWide, required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(isWide ? 24 : 16, 20, isWide ? 24 : 16, 0),
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
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF5931C8).withValues(alpha: 0.25),
            blurRadius: 60,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiagonalLinePainter())),
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C3FD4).withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 60,
            bottom: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E6AE8).withValues(alpha: 0.40),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.gold.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isWide ? 48 : 32),
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _HeroText(onViewProducts: onViewProducts),
                      ),
                      const SizedBox(width: 32),
                      const _HeroLogo(),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: _HeroLogo()),
                      const SizedBox(height: 24),
                      _HeroText(onViewProducts: onViewProducts),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.055)
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroText extends StatelessWidget {
  final void Function([String? category]) onViewProducts;
  const _HeroText({required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulsingDot(),
              const SizedBox(width: 6),
              const Text(
                'QUALITY PRINTING SERVICES',
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
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            children: [
              TextSpan(text: 'Your Vision,\n'),
              TextSpan(
                text: 'Printed ',
                children: [
                  TextSpan(
                    text: 'Perfectly.',
                    style: TextStyle(color: AppTheme.gold),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'From large-format banners to custom stationery — we bring your ideas to life with precision and quality.',
          style: TextStyle(color: Color(0xFFBBB8CC), fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: onViewProducts,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: const Color(0xFF1A0A00),
            elevation: 4,
            shadowColor: AppTheme.gold.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Browse Products',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
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
    );
  }
}

class _HeroLogo extends StatelessWidget {
  const _HeroLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.55),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/imprentalogo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF4A0090), Color(0xFF0060C8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text(
                'IP',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Featured Products ─────────────────────────────────────────────────────────

class _FeaturedSection extends StatelessWidget {
  final bool isWide;
  final void Function([String? category]) onViewProducts;
  const _FeaturedSection({required this.isWide, required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    final h = isWide ? 24.0 : 16.0;
    return _FrostedSectionContainer(
      margin: EdgeInsets.fromLTRB(h, 24, h, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Featured Products'),
            const SizedBox(height: 18),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Products')
                  .where('featured', isEqualTo: true)
                  .where('is_available', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'No featured products yet',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (_, box) {
                    final isWideLayout = box.maxWidth >= 600;
                    // Show 3 full cards on wide screens; 1.2 cards on mobile (peek effect)
                    final visibleCount = isWideLayout ? 3.0 : 1.2;
                    const gap = 12.0;
                    final cardW =
                        (box.maxWidth - gap * (visibleCount - 1)) /
                        visibleCount;
                    final imgH = cardW * 0.72;
                    const textAreaH = 118.0;
                    final cardH = imgH + textAreaH;

                    final scrollCtrl = ScrollController();

                    return Scrollbar(
                      controller: scrollCtrl,
                      thumbVisibility: isWideLayout,
                      trackVisibility: isWideLayout,
                      thickness: 4,
                      radius: const Radius.circular(3),
                      child: SizedBox(
                        // Extra bottom space for scrollbar on wide screens
                        height: cardH + (isWideLayout ? 12 : 0),
                        child: ListView.separated(
                          controller: scrollCtrl,
                          scrollDirection: Axis.horizontal,
                          // Clip so partial card on mobile shows peek effect
                          clipBehavior: Clip.none,
                          padding: EdgeInsets.only(
                            bottom: isWideLayout ? 10 : 0,
                          ),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: gap),
                          itemBuilder: (context, i) {
                            final d = docs[i].data() as Map<String, dynamic>;
                            return SizedBox(
                              width: cardW,
                              child: _FeaturedCard(
                                data: d,
                                docId: docs[i].id,
                                cardWidth: cardW,
                                imageHeight: imgH,
                                totalHeight: cardH,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final double cardWidth;
  final double imageHeight;
  final double totalHeight;
  const _FeaturedCard({
    required this.data,
    required this.docId,
    required this.cardWidth,
    required this.imageHeight,
    required this.totalHeight,
  });

  @override
  State<_FeaturedCard> createState() => _FeaturedCardState();
}

class _FeaturedCardState extends State<_FeaturedCard> {
  bool _hovered = false;

  void _goToOrder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerOrderScreen(
          product: {'product_id': widget.docId, ...widget.data},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.data['product_name']?.toString() ?? 'Product';
    final price = widget.data['price'];
    final imageUrl = widget.data['image_url']?.toString() ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _goToOrder(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.totalHeight,
          transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _hovered
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: _hovered
                  ? AppTheme.gold.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.30),
              width: _hovered ? 1.5 : 1.2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.28),
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
            mainAxisSize: MainAxisSize.max,
            children: [
              // ── Image ──
              Stack(
                children: [
                  SizedBox(
                    height: widget.imageHeight,
                    width: double.infinity,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgPlaceholder(),
                          )
                        : _imgPlaceholder(),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 36,
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
                ],
              ),
              // ── Text + Button ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            price != null ? '₱$price' : 'See pricing',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              shadows: [
                                Shadow(
                                  color: AppTheme.gold.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: () => _goToOrder(context),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _hovered
                                  ? AppTheme.gold
                                  : AppTheme.gold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.gold.withValues(alpha: 0.65),
                              ),
                              boxShadow: _hovered
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.gold.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
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
                                const SizedBox(width: 4),
                                Text(
                                  'Order',
                                  style: TextStyle(
                                    color: _hovered
                                        ? const Color(0xFF1A0A00)
                                        : AppTheme.gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _imgPlaceholder() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.04),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white38, size: 30),
    ),
  );
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Our Services ──────────────────────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
  final bool isWide;
  final void Function([String? category]) onViewProducts;
  const _ServicesSection({required this.isWide, required this.onViewProducts});

  static const _services = [
    _ServiceItem(
      title: 'Large Format & Signage',
      subtitle: 'Tarpaulins, banners & sintra boards',
      icon: Icons.photo_size_select_actual_outlined,
      accentColor: Color(0xFF4C6EF5),
      iconColor: Color(0xFFAABEFF),
      bgColor: Color(0xFF1A2760),
      category: 'Large Format & Signage',
      tag: 'Popular',
    ),
    _ServiceItem(
      title: 'Stickers & Labels',
      subtitle: 'Custom stickers, vinyl & decals',
      icon: Icons.local_offer_outlined,
      accentColor: Color(0xFFE08C00),
      iconColor: Color(0xFFFFD166),
      bgColor: Color(0xFF3D2200),
      category: 'Stickers & Labels',
      tag: null,
    ),
    _ServiceItem(
      title: 'Photo & Card Prints',
      subtitle: 'Photos, calling cards & invitations',
      icon: Icons.credit_card_outlined,
      accentColor: Color(0xFF059669),
      iconColor: Color(0xFF6EE7B7),
      bgColor: Color(0xFF0A3326),
      category: 'Photo & Card Prints',
      tag: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final h = isWide ? 24.0 : 16.0;
    return _FrostedSectionContainer(
      margin: EdgeInsets.fromLTRB(h, 24, h, 0),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Our Services'),
            const SizedBox(height: 6),
            Text(
              'Everything you need, printed with precision.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final totalW = constraints.maxWidth;
                const gap = 12.0;

                // 3-col ≥ 560px | 2-col ≥ 360px | 1-col below
                final cols = totalW >= 560
                    ? 3
                    : totalW >= 360
                    ? 2
                    : 1;

                final cardW = (totalW - gap * (cols - 1)) / cols;

                // Build rows of `cols` cards
                final rows = <Widget>[];
                for (int i = 0; i < _services.length; i += cols) {
                  final rowChildren = <Widget>[];
                  for (int j = 0; j < cols; j++) {
                    final idx = i + j;
                    if (j > 0) rowChildren.add(const SizedBox(width: gap));
                    if (idx < _services.length) {
                      rowChildren.add(
                        SizedBox(
                          width: cardW,
                          child: _ServiceCard(
                            service: _services[idx],
                            compact: cols >= 2,
                            onTap: () =>
                                onViewProducts(_services[idx].category),
                          ),
                        ),
                      );
                    } else {
                      // Empty spacer to keep layout stable
                      rowChildren.add(SizedBox(width: cardW));
                    }
                  }
                  rows.add(
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: rowChildren,
                      ),
                    ),
                  );
                  if (i + cols < _services.length) {
                    rows.add(const SizedBox(height: gap));
                  }
                }

                return Column(children: rows);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color iconColor;
  final Color bgColor;
  final String category;
  final String? tag;
  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.iconColor,
    required this.bgColor,
    required this.category,
    this.tag,
  });
}

class _ServiceCard extends StatefulWidget {
  final _ServiceItem service;
  final bool compact;
  final VoidCallback onTap;
  const _ServiceCard({
    required this.service,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          padding: EdgeInsets.all(widget.compact ? 14 : 20),
          constraints: const BoxConstraints(minHeight: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _hovered
                ? Colors.white.withValues(alpha: 0.20)
                : Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: _hovered
                  ? s.iconColor.withValues(alpha: 0.75)
                  : s.accentColor.withValues(alpha: 0.55),
              width: _hovered ? 1.5 : 1.2,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: s.accentColor.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: s.accentColor.withValues(alpha: 0.32),
                      border: Border.all(
                        color: s.iconColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(s.icon, color: s.iconColor, size: 19),
                  ),
                  if (s.tag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.55),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Popular',
                        style: TextStyle(
                          color: AppTheme.gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: widget.compact ? 10 : 14),
              Text(
                s.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.subtitle,
                style: TextStyle(
                  color: s.iconColor.withValues(alpha: 0.65),
                  fontSize: widget.compact ? 11 : 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
