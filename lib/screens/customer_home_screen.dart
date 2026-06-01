import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'customer_order_screen.dart';

class CustomerHomeScreen extends StatelessWidget {
  final VoidCallback onViewProducts;
  const CustomerHomeScreen({super.key, required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(isWide: isWide, onViewProducts: onViewProducts),
              _FeaturedSection(isWide: isWide),
              _ServicesSection(isWide: isWide),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ── Section container — dark but elevated ─────────────────────────────────────

class _SectionContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? margin;

  const _SectionContainer({required this.child, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  final bool isWide;
  final VoidCallback onViewProducts;
  const _Hero({required this.isWide, required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(isWide ? 24 : 16, 20, isWide ? 24 : 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF13101E), Color(0xFF1A1040)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DiagonalLinePainter())),
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4F23B4).withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 80,
            bottom: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E50C8).withValues(alpha: 0.3),
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
      ..color = AppTheme.gold.withValues(alpha: 0.04)
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
  final VoidCallback onViewProducts;
  const _HeroText({required this.onViewProducts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
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
                  letterSpacing: 1.2,
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
          style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: onViewProducts,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: const Color(0xFF1A0A00),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Browse Products',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppTheme.gold,
          shape: BoxShape.circle,
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
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/imprentalogo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF3a0060), Color(0xFF004fa3)],
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
                  fontSize: 22,
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
  const _FeaturedSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final h = isWide ? 24.0 : 16.0;
    return _SectionContainer(
      margin: EdgeInsets.fromLTRB(h, 20, h, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 0, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(right: h),
              child: const _SectionHeader(title: 'Featured Products'),
            ),
            const SizedBox(height: 14),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Products')
                  .where('featured', isEqualTo: true)
                  .where('is_available', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    ),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                    height: 100,
                    margin: EdgeInsets.only(right: h),
                    child: const Center(
                      child: Text(
                        'No featured products yet',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  );
                }
                return SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(right: h),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final docId = docs[i].id;
                      return _FeaturedCard(data: d, docId: docId);
                    },
                  ),
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
  const _FeaturedCard({required this.data, required this.docId});

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
      child: GestureDetector(
        onTap: () => _goToOrder(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 162,
          transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF252038),
            border: Border.all(
              color: _hovered
                  ? AppTheme.gold.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.10),
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 110,
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
                            const Color(0xFF252038).withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                : AppTheme.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.5),
                            ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: Colors.white.withValues(alpha: 0.06),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white24, size: 28),
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
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.gold,
            borderRadius: BorderRadius.circular(2),
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
  const _ServicesSection({required this.isWide});

  static const _services = [
    _ServiceItem(
      title: 'Large Format Printing',
      subtitle: 'Tarpaulins, banners & sintra boards',
      icon: Icons.photo_size_select_actual_outlined,
      accentColor: Color(0xFF3B5BDB),
      iconColor: Color(0xFF91A7FF),
      bgColor: Color(0xFF1B2A5E),
      tag: 'Popular',
    ),
    _ServiceItem(
      title: 'Menu Boards',
      subtitle: 'Backlit & printed menus for cafes',
      icon: Icons.menu_book_outlined,
      accentColor: Color(0xFF7C3AED),
      iconColor: Color(0xFFD0AEFF),
      bgColor: Color(0xFF2A1A52),
      tag: null,
    ),
    _ServiceItem(
      title: 'Stationery & Cards',
      subtitle: 'Calling cards, flyers & invitations',
      icon: Icons.credit_card_outlined,
      accentColor: Color(0xFF059669),
      iconColor: Color(0xFF6EE7B7),
      bgColor: Color(0xFF0D3528),
      tag: null,
    ),
    _ServiceItem(
      title: 'Sticker Printing',
      subtitle: 'Custom stickers, labels & decals',
      icon: Icons.local_offer_outlined,
      accentColor: Color(0xFFD97706),
      iconColor: Color(0xFFFCD34D),
      bgColor: Color(0xFF3D2200),
      tag: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final h = isWide ? 24.0 : 16.0;
    return _SectionContainer(
      margin: EdgeInsets.fromLTRB(h, 20, h, 0),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Our Services'),
            const SizedBox(height: 4),
            Text(
              'Everything you need, printed with precision.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            isWide
                ? Row(
                    children: _services
                        .map(
                          (s) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: s == _services.last ? 0 : 10,
                              ),
                              child: _ServiceCard(service: s, compact: false),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Column(
                    children: [
                      Row(
                        children: _services
                            .take(2)
                            .map(
                              (s) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: s == _services[0] ? 8 : 0,
                                  ),
                                  child: _ServiceCard(
                                    service: s,
                                    compact: true,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _services
                            .skip(2)
                            .map(
                              (s) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: s == _services[2] ? 8 : 0,
                                  ),
                                  child: _ServiceCard(
                                    service: s,
                                    compact: true,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
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
  final String? tag;
  const _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.iconColor,
    required this.bgColor,
    this.tag,
  });
}

class _ServiceCard extends StatefulWidget {
  final _ServiceItem service;
  final bool compact;
  const _ServiceCard({required this.service, required this.compact});

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        padding: EdgeInsets.all(widget.compact ? 14 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _hovered ? s.bgColor : s.bgColor.withValues(alpha: 0.85),
          border: Border.all(
            color: _hovered
                ? s.iconColor.withValues(alpha: 0.5)
                : s.accentColor.withValues(alpha: 0.3),
            width: _hovered ? 1.2 : 0.8,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: s.accentColor.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: s.accentColor.withValues(alpha: 0.28),
                  ),
                  child: Icon(s.icon, color: s.iconColor, size: 19),
                ),
                if (s.tag != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.gold.withValues(alpha: 0.4),
                      ),
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
            SizedBox(height: widget.compact ? 10 : 12),
            Text(
              s.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 12 : 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              s.subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: widget.compact ? 10 : 11,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
