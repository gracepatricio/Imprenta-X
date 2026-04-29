import 'package:flutter/material.dart';
import 'app_theme.dart';

class CustomerAboutScreen extends StatefulWidget {
  const CustomerAboutScreen({super.key});

  @override
  State<CustomerAboutScreen> createState() => _CustomerAboutScreenState();
}

class _CustomerAboutScreenState extends State<CustomerAboutScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  // Replace these with actual on-site image asset paths or network URLs.
  static const _slides = [
    _Slide('Our Print Floor', 'State-of-the-art large-format printers ready for your projects.', Color(0xFF004fa3)),
    _Slide('Design Studio', 'Our in-house design team helps bring your concepts to life.', Color(0xFF3a0060)),
    _Slide('Finishing Area', 'Precision cutting, laminating, and mounting for a polished result.', Color(0xFF006644)),
    _Slide('Customer Service', 'We handle every order with care from submission to pick-up.', Color(0xFF7a3000)),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCarousel(isWide),
              _buildHistory(isWide),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarousel(bool isWide) {
    final height = isWide ? 400.0 : 260.0;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pageCtrl,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _slides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width:  _currentPage == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == i
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Swipe hint
        Text(
          'Swipe to see more',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(bool isWide) {
    final pad = isWide ? 40.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Our Story',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Timeline entries
          _HistoryEntry(
            year: 'Founded',
            text: 'Imprenta Inc. was established with a single mission: to deliver high-quality '
                'printing services to local businesses and individuals who value precision and creativity.',
          ),
          _HistoryEntry(
            year: 'Growth',
            text: 'We expanded our fleet of large-format printers and hired skilled designers, '
                'allowing us to take on projects ranging from street banners to corporate stationery.',
          ),
          _HistoryEntry(
            year: 'Today',
            text: 'With hundreds of satisfied clients, Imprenta Inc. continues to push the boundaries '
                'of print craftsmanship — combining the latest technology with old-school attention to detail.',
          ),
          const SizedBox(height: 24),
          // Contact / Address card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.glassCard(opacity: 0.15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visit Us',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _ContactRow(Icons.location_on_outlined,
                    'Your address here, City, Province'),
                const SizedBox(height: 8),
                _ContactRow(Icons.phone_outlined, '+63 XXX XXX XXXX'),
                const SizedBox(height: 8),
                _ContactRow(Icons.email_outlined, 'imprenta@example.com'),
                const SizedBox(height: 8),
                _ContactRow(Icons.access_time_outlined,
                    'Mon – Sat: 8:00 AM – 6:00 PM'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Slide widget ──────────────────────────────────────────────────────────────

class _Slide {
  final String title;
  final String caption;
  final Color color;
  const _Slide(this.title, this.caption, this.color);
}

class _SlideWidget extends StatelessWidget {
  final _Slide slide;
  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    // Replace the Container below with Image.asset / Image.network
    // when you have actual on-site photos.
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            slide.color.withValues(alpha: 0.9),
            slide.color.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Background pattern hint
          Center(
            child: Icon(
              Icons.local_print_shop_outlined,
              size: 120,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          // Caption overlay
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slide.caption,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
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

// ── History helpers ───────────────────────────────────────────────────────────

class _HistoryEntry extends StatelessWidget {
  final String year;
  final String text;
  const _HistoryEntry({required this.year, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.gold,
                ),
              ),
              Container(
                width: 2,
                height: 60,
                color: AppTheme.gold.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  year,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.gold, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
