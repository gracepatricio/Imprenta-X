import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class EmployeeOrderChatScreen extends StatefulWidget {
  final String threadId;
  final String orderId;
  final String orderDisplay;

  const EmployeeOrderChatScreen({
    super.key,
    required this.threadId,
    required this.orderId,
    required this.orderDisplay,
  });

  @override
  State<EmployeeOrderChatScreen> createState() =>
      _EmployeeOrderChatScreenState();
}

class _EmployeeOrderChatScreenState extends State<EmployeeOrderChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll  = ScrollController();
  bool _sending  = false;

  late final String _uid;
  late final DocumentReference _threadRef;

  @override
  void initState() {
    super.initState();
    _uid       = FirebaseAuth.instance.currentUser?.uid ?? '';
    _threadRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc(widget.threadId);
    _markRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _threadRef.update({'unread_employee': 0});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();

    await _threadRef.collection('chat').add({
      'sender_uid':  _uid,
      'sender_role': 'employee',
      'text':        text,
      'timestamp':   FieldValue.serverTimestamp(),
    });

    await _threadRef.update({
      'last_message':    text,
      'last_updated':    FieldValue.serverTimestamp(),
      'unread_customer': FieldValue.increment(1),
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
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                color: Colors.black.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.gold.withValues(alpha: 0.15),
                      ),
                      child: const Icon(Icons.person_outline,
                          color: AppTheme.gold, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Customer Message',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          Text(widget.orderDisplay,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Messages
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _threadRef
                      .collection('chat')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline,
                                color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No messages yet.\n${widget.orderDisplay}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d    = docs[i].data() as Map<String, dynamic>;
                        final text = d['text']?.toString() ?? '';
                        final role = d['sender_role']?.toString() ?? '';
                        final ts   = d['timestamp'] as Timestamp?;
                        final time = ts != null ? _fmt(ts.toDate()) : '';
                        if (role == 'system') {
                          return _SystemBubble(text: text, time: time);
                        }
                        return _Bubble(text: text, isMe: role == 'employee', time: time);
                      },
                    );
                  },
                ),
              ),

              // Input
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                color: Colors.black.withValues(alpha: 0.25),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Reply to customer…',
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color:
                              _sending ? Colors.white12 : AppTheme.gold,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.send,
                                color: Colors.black, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── System notification bubble ────────────────────────────────────────────────

class _SystemBubble extends StatelessWidget {
  final String text, time;
  const _SystemBubble({required this.text, required this.time});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.gold, size: 13),
                const SizedBox(width: 5),
                const Text('System', style: TextStyle(color: AppTheme.gold, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(color: Colors.white30, fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final String text, time;
  final bool isMe;
  const _Bubble({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.person_outline,
                  color: Colors.white60, size: 15),
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.gold.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe
                      ? AppTheme.gold.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4)),
                  const SizedBox(height: 4),
                  Text(time,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 10)),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
