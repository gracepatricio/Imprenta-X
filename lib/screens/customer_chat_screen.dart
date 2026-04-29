import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_theme.dart';

class CustomerChatScreen extends StatelessWidget {
  const CustomerChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Messages",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Chat with our team about your orders",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: uid == null
                ? const Center(
                    child: Text(
                      "Not logged in",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Conversations')
                        .where('customer_id', isEqualTo: uid)
                        .orderBy('last_message_time', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha:0.07),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 34,
                                    color: Colors.white24,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  "No messages yet",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "Messages about your orders\nwill appear here",
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, i) {
                          final doc = snapshot.data!.docs[i];
                          return _ConversationTile(
                            conversationId: doc.id,
                            data: doc.data() as Map<String, dynamic>,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ConversationTile extends StatelessWidget {
  final String conversationId;
  final Map<String, dynamic> data;

  const _ConversationTile({
    required this.conversationId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = data['unread_by_customer'] == true;
    final orderId = data['order_id']?.toString();
    final lastMessage = data['last_message']?.toString();

    return GestureDetector(
      onTap: () {
        // TODO: navigate to chat thread
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(opacity: 0.15, radius: 16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha:0.1),
                border: Border.all(color: Colors.white.withValues(alpha:0.18)),
              ),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white60,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          orderId ?? 'Support Chat',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.gold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastMessage ?? 'No messages yet',
                    style: TextStyle(
                      color: hasUnread ? Colors.white60 : Colors.white38,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 20),
          ],
        ),
      ),
    );
  }
}
