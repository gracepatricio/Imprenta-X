import 'package:flutter/material.dart';

class AppTheme {
  // Background image — replace sysbackground.jpg with your actual image
  static const DecorationImage backgroundImage = DecorationImage(
    image: AssetImage('assets/images/sysbackground.jpg'),
    fit: BoxFit.cover,
  );

  // Gradient fallback (used if image fails to load)
  static const Gradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF0d0d1a),
      Color(0xFF3a0060),
      Color(0xFF004fa3),
      Color(0xFF00b89c),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Main background — image with gradient fallback
  static BoxDecoration get backgroundDecoration => const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/sysbackground.jpg'),
      fit: BoxFit.cover,
    ),
  );

  // Frosted glass card
  static BoxDecoration glassCard({double opacity = 0.15, double radius = 20}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha:opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha:0.25), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha:0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Navbar glass
  static BoxDecoration navBarDecoration = BoxDecoration(
    color: Colors.white.withValues(alpha:0.12),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha:0.2), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha:0.1),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static const Color gold = Color(0xFFFFE9AD);
  static const Color accent = Color(0xFF00b89c);

  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: Colors.white,
    fontSize: 25,
  );

  static const TextStyle subtleStyle = TextStyle(
    color: Colors.white60,
    fontSize: 23,
  );

  static InputDecoration inputDecoration(
    String label, {
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.white54, size: 18)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha:0.1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha:0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha:0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white60),
      ),
    );
  }

  static ButtonStyle primaryButton({Color? color}) {
    return ElevatedButton.styleFrom(
      backgroundColor: color ?? AppTheme.gold,
      foregroundColor: Colors.black,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }

  static ButtonStyle ghostButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha:0.4)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }
}
