import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppNavBar extends StatelessWidget {
  final String activeItem;
  final Function(String) onTap;

  const AppNavBar({super.key, required this.activeItem, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = ["Home", "Inventory", "Logs & History", "Account"];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: AppTheme.navBarDecoration,
        child: Row(
          children: [
            // Logo image + brand name
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/imprentalogo.jpg',
                      fit: BoxFit.cover,
                      // Falls back to icon if image not found
                      errorBuilder: (context, error, stackTrace) => const Icon(
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
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Nav items
            ...items.map((item) {
              final isActive = item == activeItem;
              return GestureDetector(
                onTap: () => onTap(item),
                child: Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: isActive
                      ? BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        )
                      : null,
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
