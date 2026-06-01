import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_theme.dart';

class CustomerAboutScreen extends StatefulWidget {
  const CustomerAboutScreen({super.key});

  @override
  State<CustomerAboutScreen> createState() => _CustomerAboutScreenState();
}

class _CustomerAboutScreenState extends State<CustomerAboutScreen> {
  final _pageCtrl = PageController();
  final _scrollCtrl = ScrollController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      title: 'Print Floor',
      caption:
          'State-of-the-art large-format printers ready for your projects.',
      accentColor: Color(0xFF1E6AE8),
      icon: Icons.print_outlined,
      imagePath: null,
    ),
    _Slide(
      title: 'Design Studio',
      caption: 'Our in-house design team helps bring your concepts to life.',
      accentColor: Color(0xFF7C3AED),
      icon: Icons.draw_outlined,
      imagePath: null,
    ),
    _Slide(
      title: 'Finishing Area',
      caption:
          'Precision cutting, laminating, and mounting for a polished result.',
      accentColor: Color(0xFF059669),
      icon: Icons.content_cut_outlined,
      imagePath: null,
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return Scrollbar(
          controller: _scrollCtrl,
          thumbVisibility: true,
          trackVisibility: true,
          thickness: 6,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCarousel(isWide),
                _buildBody(isWide),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Carousel ──────────────────────────────────────────────────────────────

  Widget _buildCarousel(bool isWide) {
    final height = isWide ? 420.0 : 280.0;
    final h = isWide ? 24.0 : 16.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(h, 20, h, 0),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) =>
                      _SlideWidget(slide: _slides[i], showBadge: false),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: _SlideBadge(slide: _slides[_currentPage]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? AppTheme.gold
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: _currentPage == i
                      ? [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ]
                      : [],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe to explore',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Body — Our Story + Contact ────────────────────────────────────────────

  Widget _buildBody(bool isWide) {
    final h = isWide ? 24.0 : 16.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(h, 24, h, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'Our Story'),
          const SizedBox(height: 20),
          _buildTimeline(),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Visit Us'),
          const SizedBox(height: 16),
          _buildContactCard(),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final entries = [
      _TimelineEntry(
        label: 'Founded',
        accentColor: const Color(0xFF4C6EF5),
        text:
            'Imprenta Inc. was established with a single mission: to deliver high-quality '
            'printing services to local businesses and individuals who value precision and creativity.',
      ),
      _TimelineEntry(
        label: 'Growth',
        accentColor: const Color(0xFF9B51E0),
        text:
            'We expanded our fleet of large-format printers and hired skilled designers, '
            'allowing us to take on projects ranging from street banners to corporate stationery.',
      ),
      _TimelineEntry(
        label: 'Today',
        accentColor: AppTheme.gold,
        text:
            'With hundreds of satisfied clients, Imprenta Inc. continues to push the boundaries '
            'of print craftsmanship — combining the latest technology with old-school attention to detail.',
      ),
    ];

    // ── Frosted glass applied to Our Story container ──────────────────────
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 12, 9, 31).withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: entries.asMap().entries.map((e) {
              final isLast = e.key == entries.length - 1;
              return _TimelineRow(entry: e.value, isLast: isLast);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    final items = [
      _ContactItem(
        icon: Icons.location_on_outlined,
        label: 'Address',
        value:
            'Rongavilla Bldg., Ground Floor, Unit 4,\n5th Street, Pacita Ave., San Pedro, Laguna',
      ),
      _ContactItem(
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: '+63 917 585 6200',
      ),
      _ContactItem(
        icon: Icons.email_outlined,
        label: 'Email',
        value: 'fabrication@imprentainc.net',
      ),
      _ContactItem(
        icon: Icons.access_time_outlined,
        label: 'Hours',
        value: 'Monday – Saturday\n8:00 AM – 6:00 PM',
      ),
    ];

    // ── Frosted glass applied to Visit Us container ───────────────────────
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 12, 9, 31).withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  _ContactDetailRow(item: e.value),
                  if (!isLast)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 24,
                      thickness: 1,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ── Shared section header ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.gold, AppTheme.gold.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Slide ─────────────────────────────────────────────────────────────────────

class _Slide {
  final String title;
  final String caption;
  final Color accentColor;
  final IconData icon;
  final String? imagePath;
  const _Slide({
    required this.title,
    required this.caption,
    required this.accentColor,
    required this.icon,
    this.imagePath,
  });
}

class _SlideBadge extends StatelessWidget {
  final _Slide slide;
  const _SlideBadge({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(slide.icon, color: slide.accentColor, size: 14),
          const SizedBox(width: 6),
          Text(
            slide.title.split(' ').first.toUpperCase(),
            style: TextStyle(
              color: slide.accentColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideWidget extends StatelessWidget {
  final _Slide slide;
  final bool showBadge;
  const _SlideWidget({required this.slide, this.showBadge = true});

  bool get _isNetwork =>
      slide.imagePath != null &&
      (slide.imagePath!.startsWith('http://') ||
          slide.imagePath!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (slide.imagePath != null)
          _isNetwork
              ? Image.network(
                  slide.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderBg(slide: slide),
                )
              : Image.asset(
                  slide.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderBg(slide: slide),
                )
        else
          _PlaceholderBg(slide: slide),

        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.45, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        if (showBadge)
          Positioned(top: 16, right: 16, child: _SlideBadge(slide: slide)),

        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.caption,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 13,
                    height: 1.5,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderBg extends StatelessWidget {
  final _Slide slide;
  const _PlaceholderBg({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F0B1C),
            slide.accentColor.withValues(alpha: 0.55),
            const Color(0xFF0D1E52),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          slide.icon,
          size: 90,
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _TimelineEntry {
  final String label;
  final Color accentColor;
  final String text;
  const _TimelineEntry({
    required this.label,
    required this.accentColor,
    required this.text,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEntry entry;
  final bool isLast;
  const _TimelineRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.accentColor,
                    boxShadow: [
                      BoxShadow(
                        color: entry.accentColor.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            entry.accentColor.withValues(alpha: 0.5),
                            entry.accentColor.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 0),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: entry.accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: entry.accentColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      entry.label.toUpperCase(),
                      style: TextStyle(
                        color: entry.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.text,
                    style: const TextStyle(
                      color: Color(0xFFBBB8CC),
                      fontSize: 13,
                      height: 1.65,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact ───────────────────────────────────────────────────────────────────

class _ContactItem {
  final IconData icon;
  final String label;
  final String value;
  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _ContactDetailRow extends StatelessWidget {
  final _ContactItem item;
  const _ContactDetailRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
          ),
          child: Icon(item.icon, color: AppTheme.gold, size: 17),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
