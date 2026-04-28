import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class CustomerProductsScreen extends StatefulWidget {
  const CustomerProductsScreen({super.key});

  @override
  State<CustomerProductsScreen> createState() => _CustomerProductsScreenState();
}

class _CustomerProductsScreenState extends State<CustomerProductsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery    = '';
  String? _selectedCategory; // null = All

  static const _categories = [
    'Large Format Printing',
    'Menu Boards',
    'Stationery & Cards',
    'Sticker Printing',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 20, isWide ? 24 : 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Browse our customized printing products',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  // Search
                  TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: AppTheme.inputDecoration(
                      'Search products...',
                      icon: Icons.search,
                    ),
                  ),
                ],
              ),
            ),

            // ── Category filter chips ──────────────────────────────────
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
                children: [
                  _Chip(
                    label: 'All',
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  ..._categories.map((cat) => _Chip(
                        label: cat,
                        isSelected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory == cat
                            ? _selectedCategory = null
                            : _selectedCategory = cat),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Product grid ───────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _buildQuery(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.white));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _EmptyState(
                        query: _searchQuery.isNotEmpty ? _searchQuery : null,
                        category: _selectedCategory);
                  }

                  var products = snapshot.data!.docs.where((doc) {
                    if (_searchQuery.isEmpty) return true;
                    final name = (doc.data() as Map)['product_name']
                            ?.toString()
                            .toLowerCase() ??
                        '';
                    return name.contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (products.isEmpty) {
                    return _EmptyState(query: _searchQuery);
                  }

                  final cols = isWide
                      ? (constraints.maxWidth >= 900 ? 4 : 3)
                      : 2;

                  return GridView.builder(
                    padding: EdgeInsets.fromLTRB(
                        isWide ? 24 : 16, 4, isWide ? 24 : 16, 20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) => _ProductCard(
                      data: products[i].data() as Map<String, dynamic>,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    var q = FirebaseFirestore.instance
        .collection('Products')
        .where('is_available', isEqualTo: true);
    if (_selectedCategory != null) {
      q = q.where('category', isEqualTo: _selectedCategory);
    }
    return q.snapshots();
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.gold.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.gold.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.gold : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 56, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              query != null
                  ? 'No results for "$query"'
                  : category != null
                      ? 'No products in "$category"'
                      : 'No products available',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProductCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name        = data['product_name']?.toString() ?? 'Product';
    final description = data['description']?.toString() ?? '';
    final price       = data['price'];
    final imageUrl    = data['image_url']?.toString() ?? '';
    final category    = data['category']?.toString() ?? '';

    return Container(
      decoration: AppTheme.glassCard(opacity: 0.15, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
                if (category.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const Spacer(),
                  Text(
                    price != null ? '₱$price' : 'See pricing',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Widget _placeholder() => Container(
        color: Colors.white.withValues(alpha: 0.06),
        child: const Center(
          child: Icon(Icons.image_outlined, color: Colors.white24, size: 32),
        ),
      );
}
