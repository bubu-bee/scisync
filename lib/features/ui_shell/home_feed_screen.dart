import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- 1. New import for Firebase!

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

      // 2. The Magic Pipeline! We replace ListView with StreamBuilder
      body: StreamBuilder<QuerySnapshot>(
        // We tell it exactly which collection to listen to in real-time
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          // State A: Data is still traveling through the cloud
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            ); // A nice loading spinner
          }

          // State B: Something crashed
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading notices.'));
          }

          // State C: The database is empty
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notices found!'));
          }

          // State D: Success! We have data!
          final notices = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notices.length,
            itemBuilder: (context, index) {
              // We grab the specific document and turn it into a readable Map
              var data = notices[index].data() as Map<String, dynamic>;

              // We pass the live cloud data into your UI card
              return _buildNoticeCard(
                title: data['title'] ?? 'No Title',
                body: data['description'] ?? 'No Description',
                tag: data['tag'] ?? 'NOTICE',
              );
            },
          );
        },
      ),
    );
  }

  // 3. We update your UI component to accept real data variables instead of hardcoded text!
  Widget _buildNoticeCard({
    required String title,
    required String body,
    required String tag,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 16,
      ), // Adds spacing if there are multiple cards
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
              tag.toUpperCase(), // Uses the tag directly from Firebase
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            title, // Uses the title directly from Firebase
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Text(
            body, // Uses the description directly from Firebase
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                debugPrint("Add to Calendar clicked!");
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text("Add to Calendar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
