import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppTheme {
  static final _amtFmt = NumberFormat('#,##0.00');
  static String fmtAmt(double v) => _amtFmt.format(v);
  // Background image (legacy — kept for backward compat)
  static const DecorationImage backgroundImage = DecorationImage(
    image: AssetImage('assets/images/sysbackground.jpg'),
    fit: BoxFit.cover,
  );

  // Gradient fallback
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

  // ── Responsive background ──────────────────────────────────────────────────
  // Use this everywhere. Automatically picks the right asset per screen size.
  // < 600px wide  → sysbackground_mobile.jpg  (portrait)
  // ≥ 600px wide  → sysbackground.jpg         (landscape)
  static BoxDecoration backgroundDecoration(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return BoxDecoration(
      image: DecorationImage(
        image: AssetImage(
          isMobile
              ? 'assets/images/sysbackground_mobile.jpg'
              : 'assets/images/sysbackground.jpg',
        ),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      ),
    );
  }

  // ── Frosted glass card ─────────────────────────────────────────────────────
  static BoxDecoration glassCard({double opacity = 0.30, double radius = 20}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.32),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ── Navbar glass ───────────────────────────────────────────────────────────
  static BoxDecoration navBarDecoration = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.14),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Row / item glass (lighter inner card) ─────────────────────────────────
  static BoxDecoration glassRow({double radius = 10}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    );
  }

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFFFE9AD);
  static const Color accent = Color(0xFF00b89c);

  // ── Text styles ────────────────────────────────────────────────────────────
  static const TextStyle titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle bodyStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle subtleStyle = TextStyle(
    color: Color(0xCCFFFFFF),
    fontSize: 13,
  );

  static const TextStyle sectionHeading = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  // ── Input decoration ───────────────────────────────────────────────────────
  static InputDecoration inputDecoration(
    String label, {
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.white70, size: 18)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.4),
      ),
    );
  }

  // ── Primary button (gold, full pill) ──────────────────────────────────────
  static ButtonStyle primaryButton({Color? color}) {
    return ElevatedButton.styleFrom(
      backgroundColor: color ?? AppTheme.gold,
      foregroundColor: Colors.black,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }

  // ── Ghost / outline button ────────────────────────────────────────────────
  static ButtonStyle ghostButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    );
  }

  // ── Glass button (for sidebar / secondary actions) ────────────────────────
  static ButtonStyle glassButton({bool isActive = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isActive
          ? AppTheme.gold
          : Colors.white.withValues(alpha: 0.15),
      foregroundColor: isActive ? Colors.black : Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(
          color: isActive
              ? AppTheme.gold.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      textStyle: TextStyle(
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
    );
  }

  // ── Danger button (for logout / delete) ───────────────────────────────────
  static ButtonStyle dangerButton() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    );
  }
}