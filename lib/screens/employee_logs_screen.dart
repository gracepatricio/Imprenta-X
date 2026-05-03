import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'sales_widgets.dart';

class EmployeeLogsScreen extends StatefulWidget {
  const EmployeeLogsScreen({super.key});

  @override
  State<EmployeeLogsScreen> createState() => _EmployeeLogsScreenState();
}

class _EmployeeLogsScreenState extends State<EmployeeLogsScreen> {
  int _topTab = 0; // 0 = Job Queue, 1 = Sales Record

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PillTabBar(
            tabs: const ['Job Queue', 'Sales Record'],
            active: _topTab,
            onTap: (i) => setState(() => _topTab = i),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _topTab == 0
                ? const _JobQueuePlaceholder()
                : const _SalesSection(),
          ),
        ],
      ),
    );
  }
}

class _SalesSection extends StatefulWidget {
  const _SalesSection();

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  int _subTab = 0; // 0 = Sales Record, 1 = Sales Report

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard(opacity: 0.13, radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _UnderlineTabBar(
              tabs: const ['Sales Record', 'Sales Report'],
              active: _subTab,
              onTap: (i) => setState(() => _subTab = i),
            ),
          ),
          Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
              thickness: 1),
          Expanded(
            child: _subTab == 0
                ? const SalesRecordTable()  // ← from sales_widgets.dart
                : const SalesReportView(),  // ← from sales_widgets.dart
          ),
        ],
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;
  const _PillTabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return Padding(
          padding: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.gold
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  color: isActive ? Colors.black : Colors.white70,
                  fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _UnderlineTabBar extends StatelessWidget {
  final List<String> tabs;
  final int active;
  final ValueChanged<int> onTap;
  const _UnderlineTabBar(
      {required this.tabs, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final isActive = i == active;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            margin: EdgeInsets.only(right: i < tabs.length - 1 ? 24 : 0),
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? AppTheme.gold : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              tabs[i],
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _JobQueuePlaceholder extends StatelessWidget {
  const _JobQueuePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_outline, size: 52, color: Colors.white24),
          SizedBox(height: 14),
          Text('Job Queue',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Coming soon',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}