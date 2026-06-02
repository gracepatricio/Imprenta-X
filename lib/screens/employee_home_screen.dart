import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _now;
  Timer? _timer;
  String _employeeName = '';

  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadEmployeeName();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _glowAnim = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _loadEmployeeName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _employeeName = doc.data()?['full_name'] ?? user.displayName ?? '';
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final displayName = _employeeName.isNotEmpty ? _employeeName : 'Employee';

    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${weekdays[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}, ${_now.year}';
    final clockStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;

        // ── Responsive scale factor ──────────────────────────────────
        final isNarrow = screenW < 480;
        final cardMaxW = isNarrow ? screenW - 32.0 : 420.0;

        final logoSize     = isNarrow ? (screenW * 0.22).clamp(72.0, 96.0) : 90.0;
        final logoRing     = logoSize + 6;
        final logoGlow     = logoSize + 18;
        final brandSize    = isNarrow ? (screenW * 0.052).clamp(16.0, 22.0) : 22.0;
        final taglineSize  = isNarrow ? 11.5 : 13.0;
        final nameFontSize = isNarrow ? 20.0 : 24.0;
        final cardPadH     = isNarrow ? 20.0 : 24.0;
        final cardPadV     = isNarrow ? 20.0 : 24.0;

        return Center(
          child: SizedBox(
            width: cardMaxW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ── Logo — soft gold glow ──────────────────────────────
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) {
                    // ── TUNED: softer opacity, smaller blur & spread ──
                    final logoGlowOpacity =
                        lerpDouble(0.10, 0.30, _glowAnim.value)!;
                    final logoGlowBlur =
                        lerpDouble(12.0, 28.0, _glowAnim.value)!;
                    final logoGlowSpread =
                        lerpDouble(0.0, 4.0, _glowAnim.value)!;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated outer glow halo — no dark drop shadow
                        Container(
                          width: logoGlow,
                          height: logoGlow,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE8C96A)
                                    .withValues(alpha: logoGlowOpacity),
                                blurRadius: logoGlowBlur,
                                spreadRadius: logoGlowSpread,
                              ),
                              // ── REMOVED: dark black blob shadow ──────
                            ],
                          ),
                        ),
                        // Thin gold border ring
                        Container(
                          width: logoRing,
                          height: logoRing,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE8C96A)
                                  .withValues(alpha: 0.50),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Logo image
                        ClipOval(
                          child: SizedBox(
                            width: logoSize,
                            height: logoSize,
                            child: Image.asset(
                              'assets/images/imprentalogo.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.white.withValues(alpha: 0.08),
                                child: Icon(
                                  Icons.local_print_shop_rounded,
                                  color: Colors.white.withValues(alpha: 0.50),
                                  size: logoSize * 0.44,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                SizedBox(height: isNarrow ? 18.0 : 24.0),

                // ── Brand name — gold glow ─────────────────────────────
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFE8C96A),
                      Color(0xFFFFFFFF),
                      Color(0xFFE8C96A),
                    ],
                    stops: [0.0, 0.50, 1.0],
                  ).createShader(bounds),
                  child: Text(
                    'IMPRENTA INC.',
                    style: TextStyle(
                      fontSize: brandSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: isNarrow ? 6.0 : 9.0,
                      shadows: const [
                        Shadow(
                          color: Color(0xFFE8C96A),
                          blurRadius: 12,
                          offset: Offset(0, 0),
                        ),
                        Shadow(
                          color: Color(0xFFE8C96A),
                          blurRadius: 28,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isNarrow ? 8.0 : 12.0),

                // ── Tagline ────────────────────────────────────────────
                Text(
                  'Specializes in manufacturing of customized product printing.',
                  style: TextStyle(
                    fontSize: taglineSize,
                    color: Colors.white.withValues(alpha: 0.70),
                    height: 1.65,
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isNarrow ? 28.0 : 40.0),

                // ── Greeting card — frosted glass + subtle breathing glow
                AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) {
                    // ── TUNED: much softer card glow ──────────────────
                    final glowOpacity =
                        lerpDouble(0.08, 0.25, _glowAnim.value)!;
                    final spreadRadius =
                        lerpDouble(-6.0, 0.0, _glowAnim.value)!;
                    final blurRadius =
                        lerpDouble(16.0, 36.0, _glowAnim.value)!;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFF8E7)
                                .withValues(alpha: glowOpacity),
                            blurRadius: blurRadius,
                            spreadRadius: spreadRadius,
                            offset: Offset.zero,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: -6,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.80),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ── Top: greeting + badge ─────────────────
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                  cardPadH, cardPadV, cardPadH - 4, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          greeting.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: isNarrow ? 9.0 : 10.0,
                                            color: const Color(0xFF0D1B2A)
                                                .withValues(alpha: 0.45),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 2.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayName,
                                          style: TextStyle(
                                            fontSize: nameFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0D1B2A),
                                            letterSpacing: -0.5,
                                            height: 1.15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // ── Employee badge — green ──────────
                                Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0xFF3A8D68), // solid green
    borderRadius: BorderRadius.circular(24),
  ),
  child: Row(
    children: [
      const Icon(
        Icons.badge_outlined,
        color: Colors.white,
      ),
      const SizedBox(width: 6),
      const Text(
        'Employee',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
)
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Divider ───────────────────────────────
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: cardPadH),
                              child: Divider(
                                height: 1,
                                thickness: 0.7,
                                color: const Color(0xFF0D1B2A)
                                    .withValues(alpha: 0.08),
                              ),
                            ),

                            // ── Date (left) + Clock (right) ───────────
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                  cardPadH, 14, cardPadH, cardPadV - 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Date — left side
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 12,
                                        color: const Color(0xFF0C0724)
                                            .withValues(alpha: 0.50),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: isNarrow ? 11.0 : 12.0,
                                          color: const Color(0xFF0C0724)
                                              .withValues(alpha: 0.55),
                                          letterSpacing: 0.1,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Clock — right side
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_outlined,
                                        size: 12,
                                        color: const Color(0xFF0C0724)
                                            .withValues(alpha: 0.50),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        clockStr,
                                        style: TextStyle(
                                          fontSize: isNarrow ? 11.0 : 12.0,
                                          color: const Color(0xFF0C0724)
                                              .withValues(alpha: 0.70),
                                          letterSpacing: 1.0,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}