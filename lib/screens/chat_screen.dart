import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'app_theme.dart';

/// Unified chat screen used by both customers and employees.
///
/// [customerUid]   — the UID of the customer side of the conversation.
/// [customerName]  — customer's display name (used in employee header).
/// [isEmployee]    — true when opened by an employee.
/// [orderContext]  — optional order data shown as an info banner.
class ChatScreen extends StatefulWidget {
  final String customerUid;
  final String customerName;
  final bool isEmployee;
  final Map<String, dynamic>? orderContext;
  /// When true: no Scaffold/back-button — used inside the employee split panel.
  final bool embedded;
  final VoidCallback? onClose;

  const ChatScreen({
    super.key,
    required this.customerUid,
    required this.customerName,
    required this.isEmployee,
    this.orderContext,
    this.embedded = false,
    this.onClose,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl  = TextEditingController();
  final _scroll   = ScrollController();
  bool _sending   = false;
  String _senderName = '';

  late final String _myUid;
  late final String _unreadField;
  late final DocumentReference _threadRef;
  late final CollectionReference _chatRef;
  StreamSubscription? _unreadSub;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _myUid       = FirebaseAuth.instance.currentUser?.uid ?? '';
    _unreadField = widget.isEmployee ? 'unread_employee' : 'unread_customer';
    _threadRef   = FirebaseFirestore.instance
        .collection('Messages')
        .doc('chat_${widget.customerUid}');
    _chatRef     = _threadRef.collection('chat');
    _ensureThread();
    _markRead();
    // Load sender's display name for message attribution
    FirebaseFirestore.instance.collection('User').doc(_myUid).get().then((doc) {
      if (mounted) setState(() => _senderName = doc.data()?['full_name'] ?? '');
    });
    // While the chat is open, reset our unread count the moment it goes > 0.
    _unreadSub = _threadRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final count = ((snap.data() as Map?)?[_unreadField] as num?)?.toInt() ?? 0;
      if (count > 0) _markRead();
    });
    if (widget.orderContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOrderRef());
    }
  }

  Future<void> _sendOrderRef() async {
    final order    = widget.orderContext!;
    final orderId  = order['order_id']?.toString() ?? '';
    final products = List<Map>.from(order['products'] ?? []);
    final total    = order['total_price'];

    final lines = [
      '📋 Order Reference: $orderId',
      ...products.map((p) {
        final name = p['name']?.toString() ?? '';
        final qty  = p['qty'] ?? p['quantity'] ?? 0;
        final size = p['size_label']?.toString() ?? '';
        return '• $name × $qty${size.isNotEmpty ? ' ($size)' : ''}';
      }),
      if (total != null) 'Total: ₱$total',
    ];

    await _addMessage({'text': lines.join('\n'), 'file_url': null});
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ensureThread() async {
    final snap = await _threadRef.get();
    if (snap.exists) return;
    await _threadRef.set({
      'customer_uid':    widget.customerUid,
      'customer_name':   widget.customerName,
      'last_message':    '',
      'last_updated':    FieldValue.serverTimestamp(),
      'unread_customer': 0,
      'unread_employee': 0,
    });
  }

  Future<void> _markRead() async {
    try {
      await _threadRef.update({_unreadField: 0});
    } catch (_) {}
  }

  // ── Send text ────────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    await _addMessage({'text': text, 'file_url': null});
    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  // ── Send file ────────────────────────────────────────────────────────────────

  Future<void> _sendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'psd', 'ai'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      if (f.bytes == null) return;

      setState(() => _sending = true);
      final ext      = f.name.split('.').last.toLowerCase();
      final bytes    = _compressIfImage(f.bytes!, ext);
      final ts       = DateTime.now().millisecondsSinceEpoch;
      final path     = 'chat_files/${widget.customerUid}/${ts}_${f.name}';
      final ref      = FirebaseStorage.instance.ref(path);
      final task     = await ref.putData(
          bytes, SettableMetadata(contentType: _mime(ext)));
      final url      = await task.ref.getDownloadURL();
      final fileType = {'jpg', 'jpeg', 'png'}.contains(ext) ? 'image' : 'file';

      await _addMessage({
        'text':      '',
        'file_url':  url,
        'file_name': f.name,
        'file_type': fileType,
      });
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'),
              backgroundColor: Colors.red.shade700));
      }
    }
  }

  Future<void> _addMessage(Map<String, dynamic> extra) async {
    final role = widget.isEmployee ? 'employee' : 'customer';
    await _chatRef.add({
      'sender_uid':  _myUid,
      'sender_name': _senderName,
      'sender_role': role,
      'timestamp':   FieldValue.serverTimestamp(),
      'deleted':     false,
      ...extra,
    });
    final unreadField =
        widget.isEmployee ? 'unread_customer' : 'unread_employee';
    final preview = extra['text']?.toString().isNotEmpty == true
        ? extra['text']
        : '📎 ${extra['file_name'] ?? 'File'}';
    await _threadRef.update({
      'last_message':   preview,
      'last_updated':   FieldValue.serverTimestamp(),
      unreadField:      FieldValue.increment(1),
    });
  }

  // ── Delete message ───────────────────────────────────────────────────────────

  void _confirmDelete(String msgId, String senderUid) {
    if (senderUid != _myUid) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: const Text('Delete Message',
            style: TextStyle(color: Colors.white, fontSize: 15)),
        content: const Text('This message will be removed for everyone.',
            style: TextStyle(color: Colors.white54, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatRef.doc(msgId).update({'deleted': true, 'text': '', 'file_url': null});
                // Refresh thread's last_message to the newest non-deleted message
                final recent = await _chatRef
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .get();
                String newPreview = '';
                for (final doc in recent.docs) {
                  if (doc.id == msgId) continue;
                  final d = doc.data() as Map<String, dynamic>;
                  if (d['deleted'] == true) continue;
                  final t = d['text']?.toString() ?? '';
                  final fn = d['file_name']?.toString();
                  newPreview = t.isNotEmpty ? t : '📎 ${fn ?? 'File'}';
                  break;
                }
                await _threadRef.update({'last_message': newPreview});
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Could not delete: $e'),
                    backgroundColor: Colors.red.shade700,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  Uint8List _compressIfImage(Uint8List bytes, String ext) {
    if (!{'jpg', 'jpeg', 'png'}.contains(ext)) return bytes;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      img.Image out = decoded;
      const maxDim = 1920;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        out = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDim)
            : img.copyResize(decoded, height: maxDim);
      }
      return Uint8List.fromList(
          ext == 'png' ? img.encodePng(out) : img.encodeJpg(out, quality: 80));
    } catch (_) {
      return bytes;
    }
  }

  String _mime(String ext) => switch (ext) {
    'pdf'           => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'psd'           => 'image/vnd.adobe.photoshop',
    'ai'            => 'application/postscript',
    _               => 'application/octet-stream',
  };

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  // ── Build ─────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final headerName = widget.isEmployee ? widget.customerName : 'Imprenta Inc.';
    return Container(
      padding: EdgeInsets.fromLTRB(widget.embedded ? 12 : 4, 8, 16, 8),
      color: Colors.black.withValues(alpha: 0.25),
      child: Row(
        children: [
          if (!widget.embedded)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          else if (widget.onClose != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: widget.onClose,
            ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.gold.withValues(alpha: 0.2),
            ),
            child: Icon(
              widget.isEmployee ? Icons.person_outline : Icons.local_print_shop,
              color: AppTheme.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text(
                    widget.isEmployee ? 'Customer' : 'Printing Services',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatColumn = Column(
      children: [
        // ── Header ───────────────────────────────────────────────────
        _buildHeader(context),


              // ── Messages ─────────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatRef
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
                              widget.isEmployee
                                  ? 'No messages from ${widget.customerName} yet'
                                  : 'Send a message to our team',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: docs.length,
                      itemBuilder: (_, i) {
                        final d        = docs[i].data() as Map<String, dynamic>;
                        final msgId    = docs[i].id;
                        final sender   = d['sender_uid']?.toString() ?? '';
                        final role     = d['sender_role']?.toString() ?? '';
                        final isMe     = sender == _myUid;
                        // Right side: employee view → all employee messages right;
                        //             customer view → only own messages right.
                        final isRight  = widget.isEmployee
                            ? role == 'employee'
                            : isMe;
                        final deleted  = d['deleted'] == true;
                        final ts       = d['timestamp'] as Timestamp?;
                        final time     = ts != null ? _fmt(ts.toDate()) : '';
                        final text     = d['text']?.toString() ?? '';
                        final fileUrl  = d['file_url']?.toString();
                        final fileName = d['file_name']?.toString();
                        final fileType = d['file_type']?.toString();

                        // Label shown above left-side (non-right) messages.
                        // Employee view: customer msgs → customer name; other employee → their name.
                        // Customer view: employee msgs → "Imprenta Inc."
                        final String? senderLabel;
                        if (isRight) {
                          // Right-side bubbles: show name only when it's another employee
                          senderLabel = (widget.isEmployee && !isMe)
                              ? (d['sender_name']?.toString().isNotEmpty == true
                                  ? d['sender_name'].toString()
                                  : 'Employee')
                              : null;
                        } else {
                          senderLabel = widget.isEmployee
                              ? widget.customerName
                              : 'Imprenta Inc.';
                        }

                        return _Bubble(
                          isRight:     isRight,
                          isMe:        isMe,
                          deleted:     deleted,
                          text:        text,
                          fileUrl:     fileUrl,
                          fileName:    fileName,
                          fileType:    fileType,
                          time:        time,
                          senderLabel: senderLabel,
                          onDelete: isMe && !deleted
                              ? () => _confirmDelete(msgId, sender)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Input bar ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                color: Colors.black.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    // File attach button
                    IconButton(
                      icon: Icon(Icons.attach_file,
                          color: _sending
                              ? Colors.white24
                              : Colors.white54,
                          size: 20),
                      onPressed: _sending ? null : _sendFile,
                    ),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendText(),
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 14),
                          filled: true,
                          fillColor:
                              Colors.white.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color:
                                    Colors.white.withValues(alpha: 0.15)),
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
                    const SizedBox(width: 6),
                    // Send button
                    GestureDetector(
                      onTap: _sending ? null : _sendText,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _sending
                              ? Colors.white12
                              : AppTheme.gold,
                          shape: BoxShape.circle,
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black),
                              )
                            : const Icon(Icons.send,
                                color: Colors.black, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

    if (widget.embedded) return chatColumn;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: AppTheme.backgroundDecoration,
        child: SafeArea(child: chatColumn),
      ),
    );
  }
}

// ── Order context banner ──────────────────────────────────────────────────────

class _OrderBanner extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onDismiss;
  const _OrderBanner({required this.order, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final orderId  = order['order_id']?.toString() ?? '';
    final products = List<Map>.from(order['products'] ?? []);
    final total    = order['total_price'];
    final items    = products
        .map((p) => '${p['name'] ?? ''} × ${p['qty'] ?? 0}')
        .join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined,
              color: AppTheme.gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order Ref: $orderId',
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                if (items.isNotEmpty)
                  Text(items,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (total != null)
                  Text('Total: ₱$total',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close,
                color: Colors.white38, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  /// Controls LEFT/RIGHT alignment and bubble colour.
  final bool isRight;
  /// True only for the current user — controls delete icon visibility.
  final bool isMe;
  final bool deleted;
  final String text;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final String time;
  final String? senderLabel;
  final VoidCallback? onDelete;

  const _Bubble({
    required this.isRight,
    required this.isMe,
    required this.deleted,
    required this.text,
    required this.time,
    this.fileUrl,
    this.fileName,
    this.fileType,
    this.senderLabel,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment:
              isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (senderLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
                child: Text(senderLabel!,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ),
            Row(
              mainAxisAlignment:
                  isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isRight) ...[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: AppTheme.gold, size: 14),
                  ),
                  const SizedBox(width: 6),
                ],
                // Delete button — only on own messages
                if (isMe && onDelete != null) ...[
                  GestureDetector(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      child: Icon(Icons.delete_outline,
                          color: Colors.white.withValues(alpha: 0.25),
                          size: 15),
                    ),
                  ),
                ],
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.68,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: deleted
                            ? Colors.white.withValues(alpha: 0.05)
                            : isRight
                                ? AppTheme.gold.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isRight ? 16 : 4),
                          bottomRight: Radius.circular(isRight ? 4 : 16),
                        ),
                        border: Border.all(
                          color: deleted
                              ? Colors.white12
                              : isRight
                                  ? AppTheme.gold.withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: deleted
                          ? const Text('[message deleted]',
                              style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic))
                          : _bubbleContent(context),
                    ),
                  ),
                ),
                if (isRight) const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubbleContent(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // File content
        if (fileUrl != null && fileUrl!.isNotEmpty) ...[
          if (fileType == 'image')
            GestureDetector(
              onTap: () => _openUrl(fileUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  fileUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _openUrl(fileUrl!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file_outlined,
                      color: AppTheme.gold, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      fileName ?? 'File',
                      style: const TextStyle(
                          color: AppTheme.gold,
                          fontSize: 13,
                          decoration: TextDecoration.underline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          if (text.isNotEmpty) const SizedBox(height: 4),
        ],
        // Text content
        if (text.isNotEmpty)
          Text(text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.4)),
        const SizedBox(height: 3),
        Text(time,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10)),
      ],
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
