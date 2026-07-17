import 'package:flutter/material.dart';

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[100], // Soft background so the white cards pop!

      appBar: AppBar(
        title: const Text(
          'SciSync Feed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ListView lets the screen scroll naturally
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildNoticeCard(), // We call your custom card here!
        ],
      ),
    );
  }

  // --- YOUR CUSTOM UI COMPONENT ---
  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Soft curved edges
        boxShadow: [
          // This creates the 3D floating Neumorphic effect
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. The AI Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "EXAM",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12), // Whitespace
          // 2. The Main Title
          const Text(
            "Data Structures Mid-Term",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 3. The Notice Body
          Text(
            "Attention 23com! The mid-term exam is scheduled for next week at 09:00 AM in the Main Hall.",
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),

          // 4. The Action Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                debugPrint("Add to Calendar clicked!");
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text("Add to Calendar"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
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
