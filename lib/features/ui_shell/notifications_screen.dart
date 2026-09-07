import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_data/notice_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Stream<QuerySnapshot>? _notificationsStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserBatchAndStream();
    _markNotificationsAsSeen(); // <--- Marks notifications as read when screen opens
  }

  // --- Mark notifications as seen in Firestore ---
  Future<void> _markNotificationsAsSeen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'lastSeenNotifications': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint("Error updating lastSeenNotifications: $e");
    }
  }

  Future<void> _loadUserBatchAndStream() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String userBatch = '23com'; // Default fallback

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          userBatch =
              (userDoc.data() as Map<String, dynamic>)['batchId'] ?? '23com';
        }
      }

      setState(() {
        _notificationsStream = NoticeService().streamNotices(
          batchFilter: userBatch,
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading notifications stream: $e");
      setState(() {
        _notificationsStream = NoticeService().streamNotices(
          batchFilter: 'all',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, size: 20, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text(
              'Gemini Briefings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : StreamBuilder<QuerySnapshot>(
              stream: _notificationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading briefings.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No briefings available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final notices = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: notices.length,
                  itemBuilder: (context, index) {
                    var data = notices[index].data() as Map<String, dynamic>;

                    // Pulling the AI summary field with fallbacks
                    String aiSummary =
                        data['aiSummary'] ??
                        data['summary'] ??
                        data['description'] ??
                        'No briefing summary available.';
                    String tag = (data['tag'] ?? 'NOTICE').toUpperCase();
                    String affectedDate = data['affectedDate'] ?? '';

                    // AI Theme Styling based on notice tag
                    Color tagColor = Colors.teal;
                    IconData tagIcon = Icons.auto_awesome;
                    if (tag == 'EXAM') {
                      tagColor = Colors.orange.shade800;
                      tagIcon = Icons.assignment_outlined;
                    } else if (tag == 'CA') {
                      tagColor = Colors.green.shade700;
                      tagIcon = Icons.quiz_outlined;
                    } else if (tag == 'CANCELLED') {
                      tagColor = Colors.red.shade700;
                      tagIcon = Icons.event_busy;
                    } else if (tag == 'EVENT') {
                      tagColor = Colors.purple.shade700;
                      tagIcon = Icons.event;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: tagColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row with Tag & Date badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tagColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(tagIcon, size: 14, color: tagColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          color: tagColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (affectedDate.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        affectedDate,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // AI Summary / Briefing Text
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  size: 16,
                                  color: tagColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    aiSummary,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
