import 'dart:ui';
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

  static const _defaultItems = [
    "Home",
    "Inventory",
    "Products",
    "Logs & History",
    "Account",
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // ← original
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(
                0xFF1A1A2E,
              ).withValues(alpha: 0.82), // ← original
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14), // ← original
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 24,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 680;
                final navItems = items ?? _defaultItems;
                return Row(
                  children: [
                    const _Logo(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: isWide
                            ? navItems
                                  .map(
                                    (item) => _NavItem(
                                      label: item,
                                      isActive: item == activeItem,
                                      onTap: () => onTap(item),
                                    ),
                                  )
                                  .toList()
                            : [
                                _CompactMenu(
                                  items: navItems,
                                  activeItem: activeItem,
                                  onTap: onTap,
                                ),
                              ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Logo ───────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/imprentalogo.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_print_shop,
                color: AppTheme.gold,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "IMPRENTA INC.",
          style: TextStyle(
            color: AppTheme.gold,
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

// ── Nav item — full pill hover ─────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(left: 2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isActive
                ? const Color(0xFFF5F0C0)
                : _hovered
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xFFF5F0C0).withValues(alpha: 0.40)
                  : _hovered
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFF5F0C0).withValues(alpha: 0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isActive
                  ? const Color(0xFF1A1200)
                  : _hovered
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.60),
              fontSize: 14,
              fontWeight: widget.isActive || _hovered
                  ? FontWeight.w700
                  : FontWeight.w400,
              letterSpacing: 0.1,
            ),
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
      color: const Color(0xFF1E1E30), // ← original
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ), // ← original
      ),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Icon(
          Icons.menu,
          color: Colors.white.withValues(alpha: 0.80),
          size: 20,
        ),
      ),
      itemBuilder: (_) => items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: item == activeItem
                      ? const Color(0xFFF5F0C0)
                      : Colors.white.withValues(alpha: 0.75),
                  fontWeight: item == activeItem
                      ? FontWeight.w700
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
