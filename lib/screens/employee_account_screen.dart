import 'dart:async';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';
import 'chat_screen.dart';
import '../services/auth_service.dart';
import '../services/auth_service.dart';

class EmployeeAccountScreen extends StatefulWidget {
  // tab: 0 = Job Queue Pending, 1 = Job Queue Active, 2 = Ready for Pickup
  final void Function(int tab)? onNavigateToLogs;
  const EmployeeAccountScreen({super.key, this.onNavigateToLogs});

  @override
  State<EmployeeAccountScreen> createState() => _EmployeeAccountScreenState();
}

class _EmployeeAccountScreenState extends State<EmployeeAccountScreen> {
  String selectedMenu = "dashboard";
  String fullName = "";
  String email = "";

  static const _menus = [
    ('dashboard', 'Dashboard',      Icons.dashboard_outlined),
    ('messages',  'Messages',       Icons.chat_bubble_outline),
    ('manage',    'Manage Account', Icons.manage_accounts_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User')
        .doc(user.uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        fullName = doc.data()?['full_name'] ?? user.displayName ?? 'Employee';
        email    = doc.data()?['email']     ?? user.email ?? '';
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 680;
        return isWide ? _wideLayout() : _narrowLayout();
      },
    );
  }

  // ── Wide layout ─────────────────────────────────────────────────────────────

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: AppTheme.glassCard(opacity: 0.18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(68, 36),
                const SizedBox(height: 10),
                Text(
                  fullName.isNotEmpty ? fullName : 'Employee',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 20),
                ..._menus.map((m) => _SidebarBtn(
                  label:    m.$2,
                  icon:     m.$3,
                  isActive: selectedMenu == m.$1,
                  onTap:    () => setState(() => selectedMenu = m.$1),
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: const Icon(Icons.logout, size: 15),
                    label: const Text('Logout',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassCard(opacity: 0.15),
              child: _contentWidget(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow layout ───────────────────────────────────────────────────────────

  Widget _narrowLayout() {
    return Column(
      children: [
        Container(
          color: Colors.white.withValues(alpha: 0.04),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildAvatar(38, 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isNotEmpty ? fullName : 'Employee',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (email.isNotEmpty)
                          Text(email,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _logout,
                    child: const Text('Logout',
                        style: TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _menus.map((m) {
                    final active = selectedMenu == m.$1;
                    return GestureDetector(
                      onTap: () => setState(() => selectedMenu = m.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? AppTheme.gold.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active
                                ? AppTheme.gold.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(m.$3,
                                size: 14,
                                color: active
                                    ? AppTheme.gold
                                    : Colors.white60),
                            const SizedBox(width: 6),
                            Text(
                              m.$2,
                              style: TextStyle(
                                color: active
                                    ? AppTheme.gold
                                    : Colors.white70,
                                fontSize: 12,
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.glassCard(opacity: 0.15),
              child: selectedMenu == 'messages'
                  ? _contentWidget()
                  : SingleChildScrollView(child: _contentWidget()),
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  Widget _buildAvatar(double size, double iconSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Icon(Icons.person, size: iconSize, color: Colors.white70),
    );
  }

  Widget _contentWidget() {
    switch (selectedMenu) {
      case 'messages':
        return const _EmployeeMessagesContent();
      case 'manage':
        return _ManageAccountContent(
          onNameUpdated: (n) => setState(() => fullName = n),
        );
      default:
        return _buildDashboard();
    }
  }

  // ── Dashboard ───────────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dashboard',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ── Real-time order stats ──────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Orders')
                .snapshots(),
            builder: (context, snap) {
              int pending = 0, active = 0, ready = 0;
              for (final d in snap.data?.docs ?? []) {
                final s = (d.data() as Map)['status']?.toString() ?? '';
                if (s == 'pending')       pending++;
                if (s == 'in_production') active++;
                if (s == 'ready')         ready++;
              }
              return LayoutBuilder(builder: (ctx, constraints) {
                final compact = constraints.maxWidth < 380;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _statCard('Pending\nOrders', pending, Icons.sync,
                          Colors.red, compact: compact,
                          onTap: () => widget.onNavigateToLogs?.call(0))),
                      SizedBox(width: compact ? 4 : 8),
                      Expanded(child: _statCard('Active\nOrders', active, Icons.inventory_2_outlined,
                          Colors.orange, compact: compact,
                          onTap: () => widget.onNavigateToLogs?.call(1))),
                      SizedBox(width: compact ? 4 : 8),
                      Expanded(child: _statCard('Ready for\nPickup', ready, Icons.check_circle,
                          Colors.green, compact: compact,
                          onTap: () => widget.onNavigateToLogs?.call(2))),
                    ],
                  ),
                );
              });
            },
          ),

          const SizedBox(height: 24),

          // ── Unread messages ────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Messages')
                .snapshots(),
            builder: (context, snap) {
              final allDocs = snap.data?.docs ?? [];
              final unreadDocs = allDocs.where((d) {
                final u = ((d.data() as Map)['unread_employee'] as num?) ?? 0;
                return u > 0;
              }).toList();
              final totalUnread = unreadDocs.fold<int>(
                  0,
                      (sum, d) =>
                  sum +
                      (((d.data() as Map)['unread_employee'] as num?) ?? 0)
                          .toInt());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: unreadDocs.isNotEmpty
                        ? () => setState(() => selectedMenu = 'messages')
                        : null,
                    child: Row(
                      children: [
                        const Text('Unread Messages',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        if (totalUnread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('$totalUnread',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              color: Colors.white54, size: 16),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (unreadDocs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassCard(opacity: 0.1),
                      child: const Center(
                        child: Text('No unread messages',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ),
                    )
                  else
                    ...unreadDocs.take(3).map((doc) {
                      final d           = doc.data() as Map<String, dynamic>;
                      final customerUid  = d['customer_uid']?.toString() ?? '';
                      final customerName = d['customer_name']?.toString() ?? 'Customer';
                      final lastMsg      = d['last_message']?.toString() ?? '';
                      final unread =
                      ((d['unread_employee'] as num?) ?? 0).toInt();
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              customerUid:  customerUid,
                              customerName: customerName,
                              isEmployee:   true,
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration:
                          AppTheme.glassCard(opacity: 0.12, radius: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                  AppTheme.gold.withValues(alpha: 0.15),
                                ),
                                child: const Icon(Icons.person_outline,
                                    color: AppTheme.gold, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(customerName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    if (lastMsg.isNotEmpty)
                                      Text(lastMsg,
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.redAccent),
                                child: Center(
                                  child: Text('$unread',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color,
      {bool compact = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 16),
        decoration: AppTheme.glassCard(opacity: 0.12, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: compact ? 20 : 28),
            SizedBox(height: compact ? 6 : 10),
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: compact ? 20 : 26,
                    fontWeight: FontWeight.bold)),
            SizedBox(height: compact ? 2 : 4),
            Text(label,
                style: TextStyle(color: Colors.white60, fontSize: compact ? 10 : 12)),
            if (onTap != null) ...[
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 10, color: Colors.white.withValues(alpha: 0.3)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Sidebar Button ──────────────────────────────────────────────────────────

class _SidebarBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarBtn({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: isActive
                ? AppTheme.gold.withValues(alpha: 0.15)
                : Colors.transparent,
            foregroundColor: isActive ? AppTheme.gold : Colors.white70,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Employee Messages ────────────────────────────────────────────────────────

class _EmployeeMessagesContent extends StatefulWidget {
  const _EmployeeMessagesContent();

  @override
  State<_EmployeeMessagesContent> createState() =>
      _EmployeeMessagesContentState();
}

class _EmployeeMessagesContentState extends State<_EmployeeMessagesContent> {
  String? _selectedUid;
  String _selectedName = '';

  Widget _buildList(BuildContext context, {required bool splitMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 4),
          child: Text('Messages',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        const Text('Customer conversations',
            style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 14),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Messages')
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white38));
              }
              final docs = List.from(snap.data?.docs ?? [])
                ..sort((a, b) {
                  final at = (a.data() as Map)['last_updated'];
                  final bt = (b.data() as Map)['last_updated'];
                  if (at == null || bt == null) return 0;
                  return (bt as dynamic).compareTo(at);
                });
              if (docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('No customer messages yet',
                          style:
                          TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final lastMsg     = d['last_message']?.toString() ?? '';
                  final unread      = ((d['unread_employee'] as num?) ?? 0).toInt();
                  final customerName = d['customer_name']?.toString() ?? 'Customer';
                  final customerUid  = d['customer_uid']?.toString() ?? '';
                  final isSelected  = splitMode && _selectedUid == customerUid;

                  return GestureDetector(
                    onTap: () {
                      if (splitMode) {
                        setState(() {
                          _selectedUid  = customerUid;
                          _selectedName = customerName;
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              customerUid:  customerUid,
                              customerName: customerName,
                              isEmployee:   true,
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: AppTheme.glassCard(
                          opacity: isSelected ? 0.22 : 0.12, radius: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.gold.withValues(alpha: 0.15),
                              border: isSelected
                                  ? Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.6),
                                  width: 1.5)
                                  : null,
                            ),
                            child: const Icon(Icons.person_outline,
                                color: AppTheme.gold, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(customerName,
                                    style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.gold
                                            : Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (lastMsg.isNotEmpty)
                                  Text(lastMsg,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (unread > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent),
                              child: Center(
                                child: Text('$unread',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ] else
                            const Icon(Icons.chevron_right,
                                color: Colors.white24, size: 16),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Split panel when there is enough horizontal space
      if (constraints.maxWidth >= 500) {
        return Row(
          children: [
            // ── Left: customer list ────────────────────────────────────
            SizedBox(
              width: 230,
              child: _buildList(context, splitMode: true),
            ),
            VerticalDivider(
                color: Colors.white.withValues(alpha: 0.1), width: 1),
            // ── Right: chat panel ──────────────────────────────────────
            Expanded(
              child: _selectedUid == null
                  ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 40, color: Colors.white24),
                    SizedBox(height: 10),
                    Text('Select a conversation',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  ],
                ),
              )
                  : ChatScreen(
                key: ValueKey(_selectedUid),
                customerUid:  _selectedUid!,
                customerName: _selectedName,
                isEmployee:   true,
                embedded:     true,
                onClose: () =>
                    setState(() => _selectedUid = null),
              ),
            ),
          ],
        );
      }

      // Narrow: list only, open chat as full-screen route
      return _buildList(context, splitMode: false);
    });
  }
}

// ── Manage Account ───────────────────────────────────────────────────────────

class _ManageAccountContent extends StatefulWidget {
  final void Function(String) onNameUpdated;
  const _ManageAccountContent({required this.onNameUpdated});

  @override
  State<_ManageAccountContent> createState() => _ManageAccountContentState();
}

class _ManageAccountContentState extends State<_ManageAccountContent> {
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _curPwCtrl  = TextEditingController();
  final _newPwCtrl  = TextEditingController();
  final _confPwCtrl = TextEditingController();

  bool _showCur = false, _showNew = false, _showConf = false;
  bool _savingInfo = false, _savingPw = false;
  bool _loading = true;
  String? _infoMsg, _infoErr, _pwMsg, _pwErr;

  // ── Email change ──────────────────────────────────────────────────────────
  final AuthService _authService = AuthService();
  final _newEmailCtrl      = TextEditingController();
  final _emailPasswordCtrl = TextEditingController();
  bool _changingEmail      = false;
  bool _emailSending       = false;
  bool _emailSent          = false;
  bool _showEmailPw        = false;
  bool _usedMigrationPath  = false; // true = secondary-app migration, false = verifyBeforeUpdateEmail
  String? _emailErr;
  Timer? _emailPollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _newEmailCtrl.dispose();
    _emailPasswordCtrl.dispose();
    _curPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confPwCtrl.dispose();
    _emailPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('User').doc(user.uid).get();
    if (mounted) {
      setState(() {
        _nameCtrl.text  = doc.data()?['full_name'] ?? user.displayName ?? '';
        _emailCtrl.text = doc.data()?['email']     ?? user.email ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _saveName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() { _infoErr = 'Name cannot be empty.'; _infoMsg = null; });
      return;
    }
    setState(() { _savingInfo = true; _infoErr = null; _infoMsg = null; });
    try {
      await FirebaseFirestore.instance
          .collection('User').doc(user.uid).update({'full_name': name});
      await user.updateDisplayName(name);
      widget.onNameUpdated(name);
      if (mounted) setState(() { _infoMsg = 'Name updated.'; _savingInfo = false; });
    } catch (e) {
      if (mounted) setState(() { _infoErr = 'Failed: $e'; _savingInfo = false; });
    }
  }

  Future<void> _changePw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final cur  = _curPwCtrl.text.trim();
    final nw   = _newPwCtrl.text.trim();
    final conf = _confPwCtrl.text.trim();
    if (cur.isEmpty || nw.isEmpty || conf.isEmpty) {
      setState(() { _pwErr = 'Fill in all password fields.'; _pwMsg = null; });
      return;
    }
    if (nw.length < 6) {
      setState(() { _pwErr = 'New password must be at least 6 characters.'; _pwMsg = null; });
      return;
    }
    if (nw != conf) {
      setState(() { _pwErr = 'Passwords do not match.'; _pwMsg = null; });
      return;
    }
    setState(() { _savingPw = true; _pwErr = null; _pwMsg = null; });
    try {
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: cur);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(nw);
      if (mounted) {
        setState(() {
          _pwMsg = 'Password changed successfully.';
          _savingPw = false;
          _curPwCtrl.clear();
          _newPwCtrl.clear();
          _confPwCtrl.clear();
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
        _pwErr = e.code == 'wrong-password'
            ? 'Current password is incorrect.'
            : (e.message ?? 'Failed.');
        _savingPw = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white38));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Manage Account',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _section('Personal Information'),
          const SizedBox(height: 12),
          _field(label: 'Full Name', ctrl: _nameCtrl),
          const SizedBox(height: 10),

          // ── Email (changeable) ──────────────────────────────────────────
          if (!_changingEmail) ...[
            Row(
              children: [
                Expanded(child: _field(label: 'Email', ctrl: _emailCtrl, readOnly: true)),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _changingEmail = true;
                    _emailSent = false;
                    _emailErr = null;
                    _newEmailCtrl.clear();
                  }),
                  icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.gold),
                  label: const Text('Change', style: TextStyle(color: AppTheme.gold, fontSize: 12)),
                ),
              ],
            ),
          ] else if (!_emailSent) ...[
            TextField(
              controller: _newEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: AppTheme.inputDecoration('New email address', icon: Icons.email_outlined),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailPasswordCtrl,
              obscureText: !_showEmailPw,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: AppTheme.inputDecoration(
                'Current password',
                icon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(_showEmailPw ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white54, size: 18),
                  onPressed: () => setState(() => _showEmailPw = !_showEmailPw),
                ),
              ),
            ),
            if (_emailErr != null) ...[
              const SizedBox(height: 6),
              _banner(_emailErr!, true),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _changingEmail = false;
                    _emailErr = null;
                    _newEmailCtrl.clear();
                    _emailPasswordCtrl.clear();
                  }),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _emailSending ? null : _sendEmailVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: _emailSending
                      ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                      : const Text('Send Verification', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ] else ...[
            _banner('Verification email sent to ${_newEmailCtrl.text.trim()}.\nClick the link in your inbox to confirm — this screen will update automatically.', false),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold)),
                const SizedBox(width: 10),
                const Text('Waiting for verification…', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
          // ── End email section ───────────────────────────────────────────
          if (_infoMsg != null) ...[const SizedBox(height: 8), _banner(_infoMsg!, false)],
          if (_infoErr != null) ...[const SizedBox(height: 8), _banner(_infoErr!, true)],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingInfo ? null : _saveName,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
              ),
              child: _savingInfo
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black54))
                  : const Text('Save Name',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 24),
          _section('Change Password'),
          const SizedBox(height: 12),
          _pwField(
              label: 'Current Password',
              ctrl: _curPwCtrl,
              show: _showCur,
              toggle: () => setState(() => _showCur = !_showCur)),
          const SizedBox(height: 10),
          _pwField(
              label: 'New Password',
              ctrl: _newPwCtrl,
              show: _showNew,
              toggle: () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 10),
          _pwField(
              label: 'Confirm New Password',
              ctrl: _confPwCtrl,
              show: _showConf,
              toggle: () => setState(() => _showConf = !_showConf)),
          if (_pwMsg != null) ...[const SizedBox(height: 8), _banner(_pwMsg!, false)],
          if (_pwErr != null) ...[const SizedBox(height: 8), _banner(_pwErr!, true)],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingPw ? null : _changePw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
              ),
              child: _savingPw
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black54))
                  : const Text('Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Email change methods ──────────────────────────────────────────────────

  Future<void> _sendEmailVerification() async {
    final newEmail  = _newEmailCtrl.text.trim();
    final password  = _emailPasswordCtrl.text;
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      setState(() => _emailErr = 'Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _emailErr = 'Enter your current password to confirm.');
      return;
    }
    setState(() { _emailSending = true; _emailErr = null; });

    final result = await _authService.addEmail(
      newEmail,
      currentPassword: password,
    );

    if (!mounted) return;
    if (result == 'migration_sent' || result == 'verification_sent') {
      setState(() {
        _emailSending       = false;
        _emailSent          = true;
        _usedMigrationPath  = result == 'migration_sent';
      });
      _startEmailPolling(newEmail);
    } else {
      setState(() { _emailSending = false; _emailErr = result ?? 'Failed to send verification.'; });
    }
  }

  void _startEmailPolling(String newEmail) {
    _emailPollTimer?.cancel();
    _emailPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) { _emailPollTimer?.cancel(); return; }
      try {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null) return;

        if (_usedMigrationPath) {
          // Secondary-app migration path: poll PendingEmailVerification.
          final migratedEmail =
          await _authService.checkAndFinalizeMigration(currentUid);
          if (migratedEmail != null) {
            _emailPollTimer?.cancel();
            if (mounted) setState(() {
              _changingEmail       = false;
              _emailSent           = false;
              _emailCtrl.text      = migratedEmail;
              _newEmailCtrl.clear();
              _emailPasswordCtrl.clear();
            });
          }
        } else {
          // verifyBeforeUpdateEmail path: Firebase Auth updates user.email
          // once the link is clicked.
          await FirebaseAuth.instance.currentUser?.reload();
          final user = FirebaseAuth.instance.currentUser;
          if (user?.email == newEmail) {
            _emailPollTimer?.cancel();
            await _authService.finalizeEmailUpdate(newEmail);
            if (mounted) setState(() {
              _changingEmail       = false;
              _emailSent           = false;
              _emailCtrl.text      = newEmail;
              _newEmailCtrl.clear();
              _emailPasswordCtrl.clear();
            });
          }
        }
      } catch (_) {}
    });
  }

  Widget _section(String title) => Row(children: [
    Text(title,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Expanded(
        child:
        Divider(color: Colors.white.withValues(alpha: 0.2))),
  ]);

  Widget _field(
      {required String label,
        required TextEditingController ctrl,
        bool readOnly = false}) =>
      TextField(
        controller: ctrl,
        readOnly: readOnly,
        style: TextStyle(
            color: readOnly ? Colors.white54 : Colors.white,
            fontSize: 14),
        decoration: AppTheme.inputDecoration(label),
      );

  Widget _pwField(
      {required String label,
        required TextEditingController ctrl,
        required bool show,
        required VoidCallback toggle}) =>
      TextField(
        controller: ctrl,
        obscureText: !show,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: AppTheme.inputDecoration(label,
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(show ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white54, size: 18),
              onPressed: toggle,
            )),
      );

  Widget _banner(String msg, bool isError) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: (isError ? Colors.red : Colors.green)
              .withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      Icon(
          isError
              ? Icons.error_outline
              : Icons.check_circle_outline,
          color:
          isError ? Colors.redAccent : Colors.greenAccent,
          size: 15),
      const SizedBox(width: 8),
      Expanded(
          child: Text(msg,
              style: TextStyle(
                  color: isError
                      ? Colors.redAccent
                      : Colors.greenAccent,
                  fontSize: 12))),
    ]),
  );
}

// ── Placeholder ─────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Placeholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Coming soon',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}