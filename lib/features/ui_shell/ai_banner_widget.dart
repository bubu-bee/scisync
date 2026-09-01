import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// 🧠 NEW: Global Memory! This string survives even when Flutter destroys the tab.
String? _permanentlyDismissedDocId;

class AiBannerWidget extends StatefulWidget {
  final String? dismissedNoticeId;
  final Function(bool isVisible, String? docId) onVisibilityChanged;

  const AiBannerWidget({
    super.key,
    required this.dismissedNoticeId,
    required this.onVisibilityChanged,
  });

  @override
  State<AiBannerWidget> createState() => _AiBannerWidgetState();
}

class _AiBannerWidgetState extends State<AiBannerWidget> {
  String? _currentlyShownDocId;
  Timer? _autoDismissTimer;
  bool _isCurrentlyVisible = false;
  late Stream<QuerySnapshot> _bannerStream;

  @override
  void initState() {
    super.initState();
    _bannerStream = FirebaseFirestore.instance
        .collection('notices')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _notifyParent(bool isVisible, String? docId) {
    if (_isCurrentlyVisible != isVisible) {
      _isCurrentlyVisible = isVisible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onVisibilityChanged(isVisible, docId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _bannerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          _notifyParent(false, null);
          return const SizedBox.shrink();
        }

        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;
        var docId = doc.id;

        // 1. Check BOTH the Parent's memory AND our new Global Memory!
        if (widget.dismissedNoticeId == docId ||
            _permanentlyDismissedDocId == docId) {
          _notifyParent(false, docId);
          return const SizedBox.shrink();
        }

        // 2. We have clearance to show it!
        _notifyParent(true, docId);

        // 3. Start Timer if it's a completely new notice
        if (_currentlyShownDocId != docId) {
          _currentlyShownDocId = docId;
          _autoDismissTimer?.cancel();

          _autoDismissTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) {
              // Timer finishes: Save this ID to global memory forever!
              _permanentlyDismissedDocId = docId;
              _notifyParent(false, docId);
            }
          });
        }

        String summary =
            data['summary'] ?? data['description'] ?? 'New update available.';

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
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.black54,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _autoDismissTimer?.cancel();
                    // Manual click: Save this ID to global memory forever!
                    _permanentlyDismissedDocId = docId;
                    _notifyParent(false, docId);
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
