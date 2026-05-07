import 'package:flutter/material.dart';
import 'app_theme.dart';

class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/imprentalogo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_print_shop,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: const Text(
                "IMPRENTA INC.",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gold,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Specializes in manufacturing of\ncustomized product printing.",
              style: TextStyle(fontSize: 15, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
