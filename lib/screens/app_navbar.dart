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
    "Accounting",
    "Account",
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        // ── Dark translucent glass — original style, slightly more see-through ──
        decoration: BoxDecoration(
          color: const Color.fromARGB(
            255,
            228,
            228,
            228,
          ).withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.13),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 680;
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
            color: Colors.white.withValues(alpha: 0.15),
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

// ── Full nav item — with iOS-style hover animation ─────────────────────────

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

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _bgOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _bgOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _hovered = true);
    _ctrl.forward();
  }

  void _onExit(_) {
    setState(() => _hovered = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Dark navbar — white text like the original
    final activeColor = Colors.white;
    final inactiveColor = Colors.white.withValues(alpha: 0.75);
    final hoveredColor = Colors.white;

    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? Colors.white.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.09 * _bgOpacity.value),
                  borderRadius: BorderRadius.circular(20),
                  border: widget.isActive
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                          width: 1,
                        )
                      : Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.18 * _bgOpacity.value,
                          ),
                          width: 1,
                        ),
                ),
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isActive
                        ? activeColor
                        : _hovered
                        ? hoveredColor
                        : inactiveColor,
                    fontSize: 14,
                    fontWeight: widget.isActive
                        ? FontWeight.w700
                        : _hovered
                        ? FontWeight.w600
                        : FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            );
          },
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
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
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
                  fontWeight: item == activeItem
                      ? FontWeight.bold
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
