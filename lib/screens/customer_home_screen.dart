import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

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
      padding: EdgeInsets.all(isWide ? 48 : 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3a0060).withValues(alpha: 0.85),
            const Color(0xFF004fa3).withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                Expanded(child: _HeroText(onViewProducts: onViewProducts)),
                const SizedBox(width: 32),
                _HeroLogo(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _HeroLogo()),
                const SizedBox(height: 20),
                _HeroText(onViewProducts: onViewProducts),
              ],
            ),
    );
  }
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
          ),
          child: const Text(
            'QUALITY PRINTING SERVICES',
            style: TextStyle(
              color: AppTheme.gold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Your Vision,\nPrinted Perfectly.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'From large-format banners to custom stationery — we bring your ideas to life with precision and quality.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onViewProducts,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            'Browse Products',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _HeroLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/imprentalogo.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.local_print_shop,
            color: Colors.white70,
            size: 48,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(right: isWide ? 24 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Featured Products',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Admin curated',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
                    child: CircularProgressIndicator(color: Colors.white38),
                  ),
                );
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Container(
                  height: 120,
                  margin: EdgeInsets.only(right: isWide ? 24 : 16),
                  decoration: AppTheme.glassCard(opacity: 0.1),
                  child: const Center(
                    child: Text(
                      'No featured products yet',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
                );
              }
              return SizedBox(
                height: 170,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(right: isWide ? 24 : 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return _FeaturedCard(data: d);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _FeaturedCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name     = data['product_name']?.toString() ?? 'Product';
    final price    = data['price'];
    final imageUrl = data['image_url']?.toString() ?? '';

    return Container(
      width: 140,
      decoration: AppTheme.glassCard(opacity: 0.18, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                    width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  price != null ? '₱$price' : 'See pricing',
                  style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
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

// ── Our Services ──────────────────────────────────────────────────────────────

class _ServicesSection extends StatelessWidget {
  final bool isWide;
  const _ServicesSection({required this.isWide});

  static const _services = [
    _ServiceItem('Large Format\nPrinting', Icons.photo_size_select_actual_outlined, Color(0xFF004fa3)),
    _ServiceItem('Menu Boards', Icons.menu_book_outlined, Color(0xFF3a0060)),
    _ServiceItem('Stationery\n& Cards', Icons.credit_card_outlined, Color(0xFF006644)),
    _ServiceItem('Sticker\nPrinting', Icons.local_offer_outlined, Color(0xFF7a3000)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 28, isWide ? 24 : 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Our Services',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.3 : 1.4,
            children: _services
                .map((s) => _ServiceCard(service: s))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final String label;
  final IconData icon;
  final Color color;
  const _ServiceItem(this.label, this.icon, this.color);
}

class _ServiceCard extends StatelessWidget {
  final _ServiceItem service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            service.color.withValues(alpha: 0.7),
            service.color.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(service.icon, color: Colors.white, size: 32),
          const SizedBox(height: 10),
          Text(
            service.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
