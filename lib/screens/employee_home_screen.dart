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

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  late DateTime _now;
  Timer? _timer;
  String _employeeName = '';

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadEmployeeName();
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
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final dateStr =
        '${weekdays[_now.weekday - 1]}, ${months[_now.month - 1]} ${_now.day}, ${_now.year}';
    final clockStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}:${_now.second.toString().padLeft(2, '0')}';

    return Center(
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Logo ──────────────────────────────────────────────────
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/imprentalogo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.06),
                    child: Icon(
                      Icons.local_print_shop_rounded,
                      color: Colors.white.withValues(alpha: 0.50),
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Brand name ────────────────────────────────────────────
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFE8C96A),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.5, 1.0],
              ).createShader(bounds),
              child: const Text(
                'IMPRENTA INC.',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Tagline ───────────────────────────────────────────────
            Text(
              'Specializes in manufacturing of customized product printing.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.35),
                height: 1.6,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // ── Greeting card ─────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row — greeting + badge
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 26, 24, 20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    greeting,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.38,
                                      ),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    color: Colors.white.withValues(alpha: 0.70),
                                    size: 13,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Employee',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.70,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Divider
                      Container(
                        height: 0.5,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),

                      // Bottom row — date + live clock
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 24, 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.access_time_outlined,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              clockStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 0.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
