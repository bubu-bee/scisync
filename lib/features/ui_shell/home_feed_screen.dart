import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firestore_data/notice_service.dart';
import 'ai_banner_widget.dart'; // Import the AI Summary Banner

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'SciSync Feed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: NoticeService().streamNotices(batchFilter: '2024 Batch'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint("🔥 FIREBASE ERROR: ${snapshot.error}");
            return const Center(child: Text('Error loading notices.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notices found!'));
          }

          final notices = snapshot.data!.docs;

          return Column(
            children: [
              // 1. The AI Summary Banner sits permanently at the top!
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AiBannerWidget(),
              ),

              // 2. The Rest of the Feed ListView
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: notices.length,
                  itemBuilder: (context, index) {
                    var docId = notices[index].id;
                    var data = notices[index].data() as Map<String, dynamic>;

                    int likesCount = data['likes'] ?? 0;
                    int heartsCount = data['hearts'] ?? 0;

                    return _buildNoticeCard(
                      docId: docId,
                      title: data['title'] ?? 'No Title',
                      body: data['description'] ?? 'No Description',
                      tag: data['tag'] ?? 'NOTICE',
                      likes: likesCount,
                      hearts: heartsCount,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Notice Card Widget Layout
  Widget _buildNoticeCard({
    required String docId,
    required String title,
    required String body,
    required String tag,
    required int likes,
    required int hearts,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag.toUpperCase(),
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Text(body, style: TextStyle(color: Colors.grey[700])),

          // --- REACTION & ACTION BAR ---
          const SizedBox(height: 8),
          const Divider(height: 20, thickness: 1, color: Colors.black12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Left Side: The Reactions (Always visible)
              Row(
                children: [
                  // LIKE BUTTON
                  TextButton.icon(
                    onPressed: () =>
                        NoticeService().addReaction(docId, 'likes'),
                    icon: const Icon(
                      Icons.thumb_up_alt_outlined,
                      color: Colors.grey,
                      size: 20,
                    ),
                    label: Text(
                      '$likes',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // HEART BUTTON
                  TextButton.icon(
                    onPressed: () =>
                        NoticeService().addReaction(docId, 'hearts'),
                    icon: const Icon(
                      Icons.favorite_border,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    label: Text(
                      '$hearts',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),

              // 2. Right Side: THE SMART AI UI LOGIC
              Builder(
                builder: (context) {
                  String safeTag = tag.toUpperCase();

                  if (safeTag == 'EXAM' || safeTag == 'CA') {
                    // SCENARIO 1: Mandatory academic events! Show the automated text.
                    return Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Added",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  } else if (safeTag == 'EVENT') {
                    // SCENARIO 2: Optional events! Show the Add button.
                    return ElevatedButton.icon(
                      onPressed: () {
                        debugPrint("Add Event to Calendar clicked!");
                      },
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text("Add"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } else {
                    // SCENARIO 3: General Notices / Updates. Show absolutely nothing!
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
