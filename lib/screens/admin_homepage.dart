import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'app_navbar.dart';
import 'admin_account_dashboard.dart';
import 'admin_inventory_screen.dart';
import 'admin_product_management_screen.dart';
import 'admin_logs_screen.dart';

// =============================================================================
class AdminHomepage extends StatefulWidget {
  const AdminHomepage({super.key, this.initialTab = 'Home'});
  final String initialTab;

  @override
  State<AdminHomepage> createState() => _AdminHomepageState();
}

class _AdminHomepageState extends State<AdminHomepage> {
  static const _items = [
    'Home',
    'Inventory',
    'Products',
    'Logs & History',
    'Account',
  ];

  late String _active;
  String? _initialJobStatus;
  StreamSubscription<DocumentSnapshot>? _deletionSub;
  String _adminName = '';

  @override
  void initState() {
    super.initState();
    _active = widget.initialTab;
    _loadAdminName();
    _listenForDeletion();
  }

  Future<void> _loadAdminName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _adminName = doc.data()?['full_name'] ?? user.displayName ?? '';
      });
    }
  }

  void _listenForDeletion() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _deletionSub = FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .snapshots()
        .listen((snap) async {
          final deleted =
              !snap.exists || (snap.data() as Map?)?['is_deleted'] == true;
          if (deleted && mounted) {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
            }
          }
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _deletionSub?.cancel();
    super.dispose();
  }

  Widget get _screen {
    switch (_active) {
      case 'Inventory':
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AdminInventoryScreen(),
        );
      case 'Products':
        return const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AdminProductManagementScreen(),
        );
      case 'Logs & History':
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: AdminLogsScreen(initialJobStatus: _initialJobStatus),
        );
      default:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: _AdminHomeContent(adminName: _adminName),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: Column(
          children: [
            AppNavBar(
              items: _items,
              activeItem: _active,
              onTap: (item) {
                if (item == 'Account') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminAccountDashboard(
                        onNavigateToTab: (tab, [status]) => setState(() {
                          _active = tab;
                          _initialJobStatus = status;
                        }),
                      ),
                    ),
                  );
                } else {
                  setState(() {
                    _active = item;
                    _initialJobStatus = null;
                  });
                }
              },
            ),
            Expanded(child: _screen),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Home content — logo + greeting only, fills vertical space
// =============================================================================
// =============================================================================
// Home content — mirrors EmployeeHomeScreen design, badge says 'Admin'
// =============================================================================
class _AdminHomeContent extends StatefulWidget {
  final String adminName;
  const _AdminHomeContent({this.adminName = ''});

  @override
  State<_AdminHomeContent> createState() => _AdminHomeContentState();
}

class _AdminHomeContentState extends State<_AdminHomeContent> {
  late DateTime _now;
  Timer? _timer;

  static const List<String> _quotes = [
    'Quality is not an act, it is a habit.',
    'Great work begins with great attention to detail.',
    'Every print tells a story. Make yours count.',
    'Precision today, excellence always.',
    'Craftsmanship is pride made visible.',
    'Small details make big impressions.',
    'Do it right the first time.',
    'Your work is a reflection of your standards.',
    'Consistency builds reputation.',
    'Behind every great product is a dedicated team.',
    'Excellence is the gradual result of always striving to do better.',
    'Take pride in how far you\'ve come.',
    'Good enough is the enemy of great.',
    'A strong team makes light work of heavy tasks.',
    'Today\'s effort is tomorrow\'s result.',
  ];

  String get _dailyQuote {
    final dayOfYear = _now.difference(DateTime(_now.year, 1, 1)).inDays;
    return _quotes[dayOfYear % _quotes.length];
  }

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
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
    final displayName = widget.adminName.isNotEmpty
        ? widget.adminName
        : 'Admin';

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
        '${_now.hour.toString().padLeft(2, '0')}:'
        '${_now.minute.toString().padLeft(2, '0')}:'
        '${_now.second.toString().padLeft(2, '0')}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenW = constraints.maxWidth;
        final isNarrow = screenW < 480;

        final cardMaxW = isNarrow ? screenW - 32.0 : 520.0;
        final padH = isNarrow ? 20.0 : 24.0;
        final padV = isNarrow ? 20.0 : 24.0;

        final greetingLabelSize = isNarrow ? 12.0 : 14.0;
        final nameFontSize = isNarrow ? 30.0 : 38.0;
        final brandFontSize = isNarrow ? 15.0 : 17.0;
        final taglineFontSize = isNarrow ? 11.5 : 12.5;
        final quoteFontSize = isNarrow ? 13.0 : 15.0;
        final metaFontSize = isNarrow ? 12.0 : 13.0;
        final badgeFontSize = isNarrow ? 12.0 : 13.0;
        final logoSize = isNarrow ? 50.0 : 58.0;

        return Center(
          child: SizedBox(
            width: cardMaxW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting — outside, above card ──────────────────
                Padding(
                  padding: EdgeInsets.only(
                    left: 4,
                    bottom: isNarrow ? 20.0 : 24.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: greetingLabelSize,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.45),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -1.0,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Unified frosted card ─────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C0724).withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 40,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── 1. Brand section ──────────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              padH,
                              padV,
                              padH,
                              padV,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Logo tile
                                Container(
                                  width: logoSize,
                                  height: logoSize,
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.gold.withValues(
                                        alpha: 0.38,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15.5),
                                    child: Image.asset(
                                      'assets/images/imprentalogo.jpg',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.local_print_shop_rounded,
                                        color: AppTheme.gold,
                                        size: isNarrow ? 24.0 : 28.0,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Brand name + tagline
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            const LinearGradient(
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
                                            fontSize: brandFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: isNarrow ? 2.8 : 3.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        'Specializes in manufacturing of customized product printing.',
                                        style: TextStyle(
                                          fontSize: taglineFontSize,
                                          color: Colors.white.withValues(
                                            alpha: 0.45,
                                          ),
                                          height: 1.45,
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Est. pill
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isNarrow ? 11.0 : 14.0,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.09,
                                    ),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: AppTheme.gold.withValues(
                                        alpha: 0.30,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'Est. 2018',
                                    style: TextStyle(
                                      fontSize: isNarrow ? 11.0 : 12.0,
                                      color: AppTheme.gold.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: padH),
                            child: Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),

                          // ── 2. Daily quote ────────────────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              padH,
                              padV,
                              padH,
                              padV,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\u201C',
                                  style: TextStyle(
                                    fontSize: isNarrow ? 28.0 : 34.0,
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.60,
                                    ),
                                    height: 0.80,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _dailyQuote,
                                    style: TextStyle(
                                      fontSize: quoteFontSize,
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontStyle: FontStyle.italic,
                                      height: 1.55,
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: padH),
                            child: Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.white.withValues(alpha: 0.10),
                            ),
                          ),

                          // ── 3. Date, time, admin badge ────────────
                          Padding(
                            padding: EdgeInsets.fromLTRB(padH, 16, padH, padV),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Date
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.38,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      dateStr,
                                      style: TextStyle(
                                        fontSize: metaFontSize,
                                        color: Colors.white.withValues(
                                          alpha: 0.52,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Clock
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time_outlined,
                                      size: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.38,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      clockStr,
                                      style: TextStyle(
                                        fontSize: metaFontSize,
                                        color: Colors.white.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.3,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // Admin badge — light purple to match the dark/violet system palette
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isNarrow ? 12.0 : 15.0,
                                    vertical: isNarrow ? 7.0 : 8.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2D1B69,
                                    ).withValues(alpha: 0.70),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF9B7FD4,
                                      ).withValues(alpha: 0.45),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.admin_panel_settings_outlined,
                                        color: const Color(0xFFBFA8E8),
                                        size: isNarrow ? 14.0 : 15.0,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Admin',
                                        style: TextStyle(
                                          color: const Color(0xFFBFA8E8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: badgeFontSize,
                                        ),
                                      ),
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
      },
    );
  }
}
