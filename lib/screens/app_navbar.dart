import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppNavBar extends StatelessWidget {
  final String activeItem;
  final Function(String) onTap;
  final List<String>? items;

  const AppNavBar({
    super.key,
    required this.activeItem,
    required this.onTap,
    this.items,
  });

  static const _defaultItems = ["Home", "Inventory", "Logs & History", "Account"];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: AppTheme.navBarDecoration,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Logo ≈ 190px + 4 nav items ≈ 430px = ~620px total needed.
            // Only expand to full nav when we have comfortable headroom.
            final isWide   = constraints.maxWidth >= 680;
            final navItems = items ?? _defaultItems;
            return Row(
              children: [
                _Logo(),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: isWide
                        ? navItems
                            .map((item) => _NavItem(
                                  label:    item,
                                  isActive: item == activeItem,
                                  onTap:    () => onTap(item),
                                ))
                            .toList()
                        : [
                            _CompactMenu(
                              items:      navItems,
                              activeItem: activeItem,
                              onTap:      onTap,
                            ),
                          ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Logo ───────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha:0.15),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/imprentalogo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_print_shop,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          "IMPRENTA INC.",
          style: TextStyle(
            color: AppTheme.gold,
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ── Full nav item ──────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Compact hamburger menu ─────────────────────────────────────────────────

class _CompactMenu extends StatelessWidget {
  final List<String> items;
  final String activeItem;
  final Function(String) onTap;

  const _CompactMenu({
    required this.items,
    required this.activeItem,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onTap,
      color: const Color(0xFF1a1a2e),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha:0.15)),
      ),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.menu, color: Colors.white, size: 20),
      ),
      itemBuilder: (_) => items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: item == activeItem ? AppTheme.gold : Colors.white,
                  fontWeight:
                      item == activeItem ? FontWeight.bold : FontWeight.normal,
                  fontFamily: 'Spartan',
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
