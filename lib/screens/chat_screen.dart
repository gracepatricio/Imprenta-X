import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/design_file_picker.dart';
import 'package:image/image.dart' as img;
import '../services/file_utils.dart' as file_utils;
import 'app_theme.dart';

// =============================================================================
// Design Tokens
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
// ChatScreen  (unified customer + employee general chat)
// =============================================================================

/// Unified chat screen used by both customers and employees.
class ChatScreen extends StatefulWidget {
  final String customerUid;
  final String customerName;
  final bool isEmployee;
  final Map<String, dynamic>? orderContext;
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
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String _senderName = '';

  // Pending file (picked but not yet sent)
  bool _uploadingFile = false;
  String? _pendingFileUrl;
  String? _pendingFileName;
  String? _pendingFileType;

  late final String _myUid;
  late final String _unreadField;
  late final DocumentReference _threadRef;
  late final CollectionReference _chatRef;
  StreamSubscription? _unreadSub;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _unreadField = widget.isEmployee ? 'unread_employee' : 'unread_customer';
    _threadRef = FirebaseFirestore.instance
        .collection('Messages')
        .doc('chat_${widget.customerUid}');
    _chatRef = _threadRef.collection('chat');
    _ensureThread();
    _markRead();
    FirebaseFirestore.instance.collection('User').doc(_myUid).get().then((doc) {
      if (mounted) setState(() => _senderName = doc.data()?['full_name'] ?? '');
    });
    _unreadSub = _threadRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final count =
          ((snap.data() as Map?)?[_unreadField] as num?)?.toInt() ?? 0;
      if (count > 0) _markRead();
    });
    if (widget.orderContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOrderRef());
    }
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Thread setup ─────────────────────────────────────────────────────────────

  Future<void> _ensureThread() async {
    final snap = await _threadRef.get();
    if (snap.exists) return;
    await _threadRef.set({
      'customer_uid': widget.customerUid,
      'customer_name': widget.customerName,
      'last_message': '',
      'last_updated': FieldValue.serverTimestamp(),
      'unread_customer': 0,
      'unread_employee': 0,
    });
  }

  Future<void> _markRead() async {
    try {
      await _threadRef.update({_unreadField: 0});
    } catch (_) {}
  }

  Future<void> _sendOrderRef() async {
    final order = widget.orderContext!;
    final orderId = order['order_id']?.toString() ?? '';
    final products = List<Map>.from(order['products'] ?? []);
    final total = order['total_price'];
    final lines = [
      '📋 Order Reference: $orderId',
      ...products.map((p) {
        final name = p['name']?.toString() ?? '';
        final qty = p['qty'] ?? p['quantity'] ?? 0;
        final size = p['size_label']?.toString() ?? '';
        return '• $name × $qty${size.isNotEmpty ? ' ($size)' : ''}';
      }),
      if (total != null) 'Total: ₱$total',
    ];
    await _addMessage({'text': lines.join('\n'), 'file_url': null});
  }

  // ── Send ─────────────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    final hasFile = _pendingFileUrl != null;
    if (text.isEmpty && !hasFile) return;
    if (_sending || _uploadingFile) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    if (hasFile) {
      await _addMessage({
        'text': text,
        'file_url': _pendingFileUrl,
        'file_name': _pendingFileName,
        'file_type': _pendingFileType,
      });
      setState(() {
        _pendingFileUrl = null;
        _pendingFileName = null;
        _pendingFileType = null;
      });
    } else {
      await _addMessage({'text': text, 'file_url': null});
    }

    if (mounted) setState(() => _sending = false);
    _scrollToBottom();
  }

  // Pick + upload a file but do NOT send yet — user must press Send button.
  Future<void> _pickFile() async {
    if (_uploadingFile || _sending) return;
    try {
      final picked = await pickDesignFiles(multiple: false);
      if (picked == null || picked.isEmpty) return;
      final (fileName, fileBytes) = picked.first;

      setState(() => _uploadingFile = true);

      final ext = fileName.split('.').last.toLowerCase();
      final bytes = _compressIfImage(fileBytes, ext);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = 'chat_files/${widget.customerUid}/${ts}_$fileName';
      final ref = FirebaseStorage.instance.ref(path);
      final task = await ref.putData(
        bytes,
        SettableMetadata(contentType: _mime(ext)),
      );
      final url = await task.ref.getDownloadURL();
      final fileType = {'jpg', 'jpeg', 'png'}.contains(ext) ? 'image' : 'file';

      if (mounted) {
        setState(() {
          _uploadingFile = false;
          _pendingFileUrl = url;
          _pendingFileName = fileName;
          _pendingFileType = fileType;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingFile = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: _G.accentRose,
          ),
        );
      }
    }
  }

  void _clearPendingFile() {
    setState(() {
      _pendingFileUrl = null;
      _pendingFileName = null;
      _pendingFileType = null;
    });
  }

  Future<void> _addMessage(Map<String, dynamic> extra) async {
    final role = widget.isEmployee ? 'employee' : 'customer';
    await _chatRef.add({
      'sender_uid': _myUid,
      'sender_name': _senderName,
      'sender_role': role,
      'timestamp': FieldValue.serverTimestamp(),
      'deleted': false,
      ...extra,
    });
    final otherUnread = widget.isEmployee
        ? 'unread_customer'
        : 'unread_employee';
    final preview = extra['text']?.toString().isNotEmpty == true
        ? extra['text']
        : '📎 ${extra['file_name'] ?? 'File'}';
    await _threadRef.update({
      'last_message': preview,
      'last_updated': FieldValue.serverTimestamp(),
      otherUnread: FieldValue.increment(1),
    });
  }

  // ── Delete ───────────────────────────────────────────────────────────────────

  void _confirmDelete(String msgId, String senderUid) {
    if (senderUid != _myUid) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C091F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        title: const Text(
          'Delete Message',
          style: TextStyle(
            color: _G.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'This message will be removed for everyone.',
          style: TextStyle(color: _G.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _G.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _chatRef.doc(msgId).update({
                  'deleted': true,
                  'text': '',
                  'file_url': null,
                });
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not delete: $e'),
                      backgroundColor: _G.accentRose,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _G.accentRose,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
      if (_scroll.hasClients && _scroll.position.pixels > 0) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Uint8List _compressIfImage(Uint8List bytes, String ext) {
    if (kIsWeb) return bytes;
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
        ext == 'png' ? img.encodePng(out) : img.encodeJpg(out, quality: 80),
      );
    } catch (_) {
      return bytes;
    }
  }

  String _mime(String ext) => switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'psd' => 'image/vnd.adobe.photoshop',
    'ai' => 'application/postscript',
    _ => 'application/octet-stream',
  };

  String _timeLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[date.weekday - 1];
    }
    const mo = [
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
    return '${mo[date.month - 1]} ${date.day}, ${date.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final headerName = widget.isEmployee
        ? widget.customerName
        : 'Imprenta Inc.';
    final headerSub = widget.isEmployee ? 'Customer' : 'Printing Services';

    return _GlassBox(
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
        padding: EdgeInsets.fromLTRB(widget.embedded ? 12 : 8, 12, 16, 12),
        child: Row(
          children: [
            // Back / close button
            if (!widget.embedded)
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
              )
            else if (widget.onClose != null)
              GestureDetector(
                onTap: widget.onClose,
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
                  child: Icon(
                    Icons.close_rounded,
                    color: _G.textMuted,
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
              child: Icon(
                widget.isEmployee
                    ? Icons.person_rounded
                    : Icons.local_print_shop_rounded,
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
                  Text(
                    headerName,
                    style: const TextStyle(
                      color: _G.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    headerSub,
                    style: const TextStyle(
                      color: _G.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Online indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }

  // Pending file preview chip shown above the text input
  Widget _buildPendingFileChip() {
    if (_uploadingFile) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _G.accentAmber,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Uploading…',
              style: TextStyle(color: _G.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (_pendingFileUrl == null) return const SizedBox.shrink();
    final isImage = _pendingFileType == 'image';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _G.accentAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _G.accentAmber.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            color: _G.accentAmber,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _pendingFileName ?? 'File',
              style: const TextStyle(color: _G.accentAmber, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _clearPendingFile,
            child: Icon(
              Icons.close_rounded,
              color: _G.accentAmber.withValues(alpha: 0.70),
              size: 16,
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
        _buildHeader(context),

        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _chatRef
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
                      Text(
                        widget.isEmployee
                            ? 'No messages from ${widget.customerName} yet'
                            : 'Send a message to our team',
                        style: const TextStyle(
                          color: _G.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Build a flat list that interleaves date separators
              final items = <dynamic>[];
              DateTime? prevDay;
              for (final doc in docs) {
                final d = doc.data() as Map<String, dynamic>;
                final ts = d['timestamp'] as Timestamp?;
                if (ts != null) {
                  final date = ts.toDate().toLocal();
                  final day = DateTime(date.year, date.month, date.day);
                  if (prevDay == null || day != prevDay) {
                    items.add(_dateLabel(date));
                    prevDay = day;
                  }
                }
                items.add(doc);
              }

              return ListView.builder(
                controller: _scroll,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[items.length - 1 - i];

                  if (item is String) {
                    return _DateSeparator(label: item);
                  }

                  final doc = item as QueryDocumentSnapshot;
                  final d = doc.data() as Map<String, dynamic>;
                  final msgId = doc.id;
                  final sender = d['sender_uid']?.toString() ?? '';
                  final role = d['sender_role']?.toString() ?? '';
                  final isMe = sender == _myUid;
                  final isRight = widget.isEmployee ? role == 'employee' : isMe;
                  final deleted = d['deleted'] == true;
                  final ts = d['timestamp'] as Timestamp?;
                  final time = ts != null
                      ? _timeLabel(ts.toDate().toLocal())
                      : '';
                  final text = d['text']?.toString() ?? '';
                  final fileUrl = d['file_url']?.toString();
                  final fileName = d['file_name']?.toString();
                  final fileType = d['file_type']?.toString();

                  final String? senderLabel;
                  if (isRight) {
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

                  if (role == 'system') {
                    return _SystemBubble(text: text, time: time);
                  }

                  return _Bubble(
                    isRight: isRight,
                    isMe: isMe,
                    deleted: deleted,
                    text: text,
                    fileUrl: fileUrl,
                    fileName: fileName,
                    fileType: fileType,
                    time: time,
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

        // Pending file preview
        _buildPendingFileChip(),

        // ── Input bar ──────────────────────────────────────────────────
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
              10,
              12,
              14,
              MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 18,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                GestureDetector(
                  onTap: (_uploadingFile || _sending) ? null : _pickFile,
                  child: Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: (_uploadingFile || _sending)
                            ? Colors.white.withValues(alpha: 0.08)
                            : (_pendingFileUrl != null
                                  ? _G.accentAmber.withValues(alpha: 0.60)
                                  : Colors.white.withValues(alpha: 0.20)),
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.attach_file_rounded,
                      size: 18,
                      color: (_uploadingFile || _sending)
                          ? _G.textMuted
                          : (_pendingFileUrl != null
                                ? _G.accentAmber
                                : _G.textSecondary),
                    ),
                  ),
                ),

                // Text field
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
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: _pendingFileUrl != null
                                ? 'Add a caption… (optional)'
                                : 'Type a message…',
                            hintStyle: const TextStyle(
                              color: _G.textMuted,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
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

                // Send button
                GestureDetector(
                  onTap: (_sending || _uploadingFile) ? null : _sendText,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (_sending || _uploadingFile)
                          ? Colors.white.withValues(alpha: 0.10)
                          : _G.activeBtn,
                      shape: BoxShape.circle,
                      boxShadow: (_sending || _uploadingFile)
                          ? []
                          : [
                              BoxShadow(
                                color: _G.activeBtn.withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: (_sending || _uploadingFile)
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
    );

    if (widget.embedded) return chatColumn;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: SafeArea(child: chatColumn),
      ),
    );
  }
}

// ── Date separator ────────────────────────────────────────────────────────────

class _DateSeparator extends StatelessWidget {
  final String label;
  const _DateSeparator({required this.label});

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
              label,
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
  final bool isRight;
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

  void _openUrl(String url) async {
    if (url.isEmpty) return;
    await file_utils.openFileInNewTab(url);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: isRight
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Sender label
            if (senderLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 42, right: 4),
                child: Text(
                  senderLabel!,
                  style: const TextStyle(
                    color: _G.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: isRight
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar — incoming only
                if (!isRight) ...[
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
                      Icons.person_rounded,
                      color: _G.accentAmber,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Delete hint icon (outgoing only)
                if (isMe && onDelete != null) ...[
                  GestureDetector(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 2),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white.withValues(alpha: 0.22),
                        size: 15,
                      ),
                    ),
                  ),
                ],

                // Bubble body
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    child: deleted
                        ? _DeletedBubble(isRight: isRight)
                        : (isRight
                              ? _MeBubble(
                                  text: text,
                                  time: time,
                                  fileUrl: fileUrl,
                                  fileName: fileName,
                                  fileType: fileType,
                                  onOpenUrl: _openUrl,
                                )
                              : _ThemBubble(
                                  text: text,
                                  time: time,
                                  fileUrl: fileUrl,
                                  fileName: fileName,
                                  fileType: fileType,
                                  onOpenUrl: _openUrl,
                                )),
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
}

// Deleted message placeholder
class _DeletedBubble extends StatelessWidget {
  final bool isRight;
  const _DeletedBubble({required this.isRight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isRight ? 20 : 4),
          bottomRight: Radius.circular(isRight ? 4 : 20),
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.0,
        ),
      ),
      child: const Text(
        '[message deleted]',
        style: TextStyle(
          color: _G.textMuted,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// "My" outgoing bubble — solid amber
class _MeBubble extends StatelessWidget {
  final String text, time;
  final String? fileUrl, fileName, fileType;
  final void Function(String) onOpenUrl;

  const _MeBubble({
    required this.text,
    required this.time,
    required this.onOpenUrl,
    this.fileUrl,
    this.fileName,
    this.fileType,
  });

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
          if (fileUrl != null && fileUrl!.isNotEmpty) ...[
            if (fileType == 'image')
              GestureDetector(
                onTap: () => onOpenUrl(fileUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    fileUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: _G.textMuted,
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () => onOpenUrl(fileUrl!),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      color: _G.activeBtnText,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        fileName ?? 'File',
                        style: const TextStyle(
                          color: _G.activeBtnText,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (text.isNotEmpty) const SizedBox(height: 6),
          ],
          if (text.isNotEmpty)
            Text(
              text,
              style: const TextStyle(
                color: _G.activeBtnText,
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 5),
          Text(
            time,
            style: TextStyle(
              color: _G.activeBtnText.withValues(alpha: 0.50),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Incoming bubble — frosted glass
class _ThemBubble extends StatelessWidget {
  final String text, time;
  final String? fileUrl, fileName, fileType;
  final void Function(String) onOpenUrl;

  const _ThemBubble({
    required this.text,
    required this.time,
    required this.onOpenUrl,
    this.fileUrl,
    this.fileName,
    this.fileType,
  });

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
              if (fileUrl != null && fileUrl!.isNotEmpty) ...[
                if (fileType == 'image')
                  GestureDetector(
                    onTap: () => onOpenUrl(fileUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        fileUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: _G.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => onOpenUrl(fileUrl!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          color: _G.accentAmber,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            fileName ?? 'File',
                            style: const TextStyle(
                              color: _G.accentAmber,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (text.isNotEmpty) const SizedBox(height: 6),
              ],
              if (text.isNotEmpty)
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
