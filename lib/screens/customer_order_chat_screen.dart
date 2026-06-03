import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

// =============================================================================
// Design Tokens  (shared with EmployeeOrderChatScreen & CustomerOrderChatScreen)
// =============================================================================
class _G {
  static const Color activeBtn = Color(0xFFF5F0C0);
  static const Color activeBtnText = Color(0xFF1A1200);
  static const Color textPrimary = Color(0xFFEFF0F6);
  static const Color textSecondary = Color(0xCCEFF0F6);
  static const Color textMuted = Color(0x88EFF0F6);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentRose = Color(0xFFEF4444);
  static const Color accentViolet = Color(0xFF8B5CF6);
  static const Color glassBorder = Color(0x4DFFFFFF);
}

// Blur + dark glass wrapper
class _GlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? bgColor;

  const _GlassBox({
    required this.child,
    this.borderRadius = 16,
    this.padding,
    this.borderColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor ?? const Color(0xFF0C091F).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.18),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// =============================================================================
// CustomerOrderChatScreen  (self-creating thread variant)
// =============================================================================

class CustomerOrderChatScreen extends StatefulWidget {
  final String orderId;
  final String orderDisplay;

  const CustomerOrderChatScreen({
    super.key,
    required this.orderId,
    required this.orderDisplay,
  });

  @override
  State<CustomerOrderChatScreen> createState() =>
      _CustomerOrderChatScreenState();
}

class _CustomerOrderChatScreenState extends State<CustomerOrderChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  late final String _uid;
  late final DocumentReference _threadRef;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _threadRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc('${widget.orderId}_$_uid');
    _ensureThread();
    _markRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // Create the thread document if it doesn't exist yet.
  Future<void> _ensureThread() async {
    final snap = await _threadRef.get();
    if (!snap.exists) {
      final userDoc = await FirebaseFirestore.instance
          .collection('User')
          .doc(_uid)
          .get();
      final name = userDoc.data()?['full_name'] ?? '';
      await _threadRef.set({
        'order_id': widget.orderId,
        'order_display': widget.orderDisplay,
        'customer_uid': _uid,
        'customer_name': name,
        'last_message': '',
        'last_updated': FieldValue.serverTimestamp(),
        'unread_customer': 0,
        'unread_employee': 0,
      });
    }
  }

  Future<void> _markRead() async {
    try {
      await _threadRef.update({'unread_customer': 0});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();

    await _threadRef.collection('chat').add({
      'sender_uid': _uid,
      'sender_role': 'customer',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _threadRef.update({
      'last_message': text,
      'last_updated': FieldValue.serverTimestamp(),
      'unread_employee': FieldValue.increment(1),
    });

    if (mounted) setState(() => _sending = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              _GlassBox(
                borderRadius: 0,
                borderColor: Colors.transparent,
                bgColor: const Color(0xFF0C091F).withValues(alpha: 0.72),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: _G.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Avatar
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _G.accentAmber.withValues(alpha: 0.15),
                          border: Border.all(
                            color: _G.accentAmber.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.local_print_shop_rounded,
                          color: _G.accentAmber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Imprenta Inc.',
                              style: TextStyle(
                                color: _G.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.orderDisplay,
                              style: const TextStyle(
                                color: _G.accentAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Online indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _G.accentEmerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: _G.accentEmerald.withValues(alpha: 0.40),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _G.accentEmerald,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Active',
                              style: TextStyle(
                                color: _G.accentEmerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Messages ────────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _threadRef
                      .collection('chat')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];

                    if (snap.connectionState == ConnectionState.waiting &&
                        docs.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: _G.accentAmber,
                          strokeWidth: 2,
                        ),
                      );
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: _G.textMuted,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(
                                color: _G.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Send a message to get started',
                              style: TextStyle(
                                color: _G.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final text = d['text']?.toString() ?? '';
                        final role = d['sender_role']?.toString() ?? '';
                        final ts = d['timestamp'] as Timestamp?;
                        final time = ts != null ? _fmt(ts.toDate()) : '';

                        final showDate =
                            i == 0 ||
                            _isDifferentDay(
                              (docs[i - 1].data() as Map)['timestamp'],
                              d['timestamp'],
                            );

                        final isFirst =
                            i == 0 ||
                            (docs[i - 1].data() as Map)['sender_role'] != role;

                        return Column(
                          children: [
                            if (showDate) _DateSeparator(ts: ts),
                            if (role == 'system')
                              _SystemBubble(text: text, time: time)
                            else
                              _Bubble(
                                text: text,
                                isMe: role == 'customer',
                                time: time,
                                isFirst: isFirst,
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Input bar ───────────────────────────────────────────────
              _GlassBox(
                borderRadius: 0,
                borderColor: Colors.transparent,
                bgColor: const Color(0xFF0C091F).withValues(alpha: 0.72),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    14,
                    12,
                    14,
                    MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 18,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 140),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  width: 1.1,
                                ),
                              ),
                              child: TextField(
                                controller: _msgCtrl,
                                style: const TextStyle(
                                  color: _G.textPrimary,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                maxLines: null,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: const InputDecoration(
                                  hintText: 'Type a message…',
                                  hintStyle: TextStyle(
                                    color: _G.textMuted,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      GestureDetector(
                        onTap: _sending ? null : _send,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _sending
                                ? Colors.white.withValues(alpha: 0.10)
                                : _G.activeBtn,
                            shape: BoxShape.circle,
                            boxShadow: _sending
                                ? []
                                : [
                                    BoxShadow(
                                      color: _G.activeBtn.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(13),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _G.activeBtnText,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: _G.activeBtnText,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isDifferentDay(dynamic tsA, dynamic tsB) {
    if (tsA == null || tsB == null) return false;
    try {
      final a = (tsA as Timestamp).toDate();
      final b = (tsB as Timestamp).toDate();
      return a.year != b.year || a.month != b.month || a.day != b.day;
    } catch (_) {
      return false;
    }
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Date separator ────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final Timestamp? ts;
  const _DateSeparator({this.ts});

  String _label() {
    if (ts == null) return '';
    final dt = ts!.toDate();
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) return 'Today';
    if (now.difference(dt).inDays == 1) return 'Yesterday';
    const months = [
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
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.9,
              ),
            ),
            child: Text(
              _label(),
              style: const TextStyle(
                color: _G.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ── System notification bubble ────────────────────────────────────────────────

class _SystemBubble extends StatelessWidget {
  final String text, time;
  const _SystemBubble({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.80,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: _G.accentAmber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _G.accentAmber.withValues(alpha: 0.40),
                  width: 1.1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        color: _G.accentAmber,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'System Notification',
                        style: TextStyle(
                          color: _G.accentAmber,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _G.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: const TextStyle(color: _G.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text, time;
  final bool isMe;
  final bool isFirst;

  const _Bubble({
    required this.text,
    required this.isMe,
    required this.time,
    this.isFirst = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isFirst ? 10 : 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (isFirst)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _G.accentAmber.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _G.accentAmber.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.local_print_shop_rounded,
                  color: _G.accentAmber,
                  size: 16,
                ),
              )
            else
              const SizedBox(width: 34),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              child: isMe
                  ? _MeBubble(text: text, time: time)
                  : _ThemBubble(text: text, time: time),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// Customer "me" bubble — solid amber
class _MeBubble extends StatelessWidget {
  final String text, time;
  const _MeBubble({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0C0).withValues(alpha: 0.92),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF5F0C0).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1A1200),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            time,
            style: TextStyle(
              color: const Color(0xFF1A1200).withValues(alpha: 0.50),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Shop "them" bubble — frosted glass
class _ThemBubble extends StatelessWidget {
  final String text, time;
  const _ThemBubble({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(4),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: _G.textPrimary,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                time,
                style: const TextStyle(color: _G.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
