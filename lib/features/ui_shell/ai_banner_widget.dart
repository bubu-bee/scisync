import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // We need this for the Timer!

class AiBannerWidget extends StatefulWidget {
  const AiBannerWidget({super.key});

  @override
  State<AiBannerWidget> createState() => _AiBannerWidgetState();
}

class _AiBannerWidgetState extends State<AiBannerWidget> {
  String? _dismissedDocId;
  String? _currentlyShownDocId;
  Timer? _autoDismissTimer;

  // Cleanup the timer if the widget is destroyed so it doesn't cause memory leaks
  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;
        var docId = doc.id;

        // 1. Check if it's already been dismissed manually or by the timer
        if (_dismissedDocId == docId) {
          return const SizedBox.shrink();
        }

        // 2. The Auto-Vanish Logic!
        // If this is a brand new notice we haven't set a timer for yet...
        if (_currentlyShownDocId != docId) {
          _currentlyShownDocId = docId;

          // Cancel any old timer just in case
          _autoDismissTimer?.cancel();

          // Start the 5-second countdown!
          _autoDismissTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) {
              setState(() {
                // When the timer goes off, we mark it as "dismissed" so it vanishes
                _dismissedDocId = docId;
              });
            }
          });
        }

        String summary =
            data['summary'] ?? data['description'] ?? 'New update available.';

        // We wrap it in an AnimatedSize so it shrinks smoothly instead of instantly vanishing!
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.teal, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🤖 AI Summary",
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // The Manual Dismiss 'X' Button
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.black54,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    // If they click 'X', we cancel the timer early and hide it
                    _autoDismissTimer?.cancel();
                    setState(() {
                      _dismissedDocId = docId;
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
