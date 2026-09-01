import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Required for dynamic user batch fetching
import '../firestore_data/notice_service.dart';
import 'ai_banner_widget.dart';
import 'profile_screen.dart';
import '../schedule_bot/scibot_screen.dart';
import '../schedule_bot/hero_countdown_widget.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  bool _isBannerVisible = false;
  String? _dismissedNoticeId;
  Stream<QuerySnapshot>? _feedStream;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeFeedStream();
  }

  // Dynamically load the user's batch to filter the feed correctly
  Future<void> _initializeFeedStream() async {
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
        _feedStream = NoticeService().streamNotices(batchFilter: userBatch);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading feed stream: $e");
      setState(() {
        _feedStream = NoticeService().streamNotices(batchFilter: 'all');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text(
              'SciSync Feed',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            floating: true,
            snap: true,
            pinned: false,
            actions: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                child: const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.teal),
                  ),
                ),
              ),
            ],
          ),

          // The wired-up Hero Countdown!
          SliverToBoxAdapter(
            child: HeroCountdownWidget(
              onTap: () {
                DefaultTabController.of(context).animateTo(0);
              },
            ),
          ),

          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyBannerDelegate(
              isVisible: _isBannerVisible,
              child: Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: AiBannerWidget(
                  dismissedNoticeId: _dismissedNoticeId,
                  onVisibilityChanged: (visible, docId) {
                    setState(() {
                      _isBannerVisible = visible;
                      if (!visible && docId != null) {
                        _dismissedNoticeId = docId;
                      }
                    });
                  },
                ),
              ),
            ),
          ),

          // StreamBuilder with safe loading handling
          _isLoading || _feedStream == null
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _feedStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.teal),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return const SliverFillRemaining(
                        child: Center(child: Text('Error loading notices.')),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(child: Text('No notices found!')),
                      );
                    }

                    final notices = snapshot.data!.docs;

                    return SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          var docId = notices[index].id;
                          var data =
                              notices[index].data() as Map<String, dynamic>;
                          int likesCount = data['likes'] ?? 0;
                          int heartsCount = data['hearts'] ?? 0;

                          return _buildNoticeCard(
                            context: context,
                            docId: docId,
                            title: data['title'] ?? 'No Title',
                            body: data['description'] ?? 'No Description',
                            tag: data['tag'] ?? 'NOTICE',
                            likes: likesCount,
                            hearts: heartsCount,
                          );
                        }, childCount: notices.length),
                      ),
                    );
                  },
                ),
        ],
      ),

      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.tealAccent.withValues(alpha: 0.6),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SciBotScreen()),
          ),
          backgroundColor: Colors.teal[900],
          foregroundColor: Colors.white,
          elevation: 0,
          child: const Icon(Icons.smart_toy, size: 28),
        ),
      ),
    );
  }

  Widget _buildNoticeCard({
    required BuildContext context,
    required String docId,
    required String title,
    required String body,
    required String tag,
    required int likes,
    required int hearts,
  }) {
    String safeTag = tag.toUpperCase();

    // Dynamic badge coloring based on notice type
    Color badgeBg = Colors.red[100]!;
    Color badgeFg = Colors.red;
    if (safeTag == 'CANCELLED') {
      badgeBg = Colors.red.shade900;
      badgeFg = Colors.white;
    } else if (safeTag == 'CA') {
      badgeBg = const Color.fromARGB(255, 177, 240, 169)!;
      badgeFg = const Color.fromARGB(255, 46, 151, 5);
    } else if (safeTag == 'EXAM') {
      badgeBg = Colors.orange[100]!;
      badgeFg = Colors.orange.shade800;
    } else if (safeTag == 'EVENT') {
      badgeBg = Colors.purple[100]!;
      badgeFg = Colors.purple.shade800;
    }

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
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              safeTag,
              style: TextStyle(
                color: badgeFg,
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
          const SizedBox(height: 8),
          const Divider(height: 20, thickness: 1, color: Colors.black12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
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
              Builder(
                builder: (context) {
                  if (safeTag == 'EXAM' || safeTag == 'CA') {
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
                    return ElevatedButton.icon(
                      onPressed: () {},
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

class _StickyBannerDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final bool isVisible;

  _StickyBannerDelegate({required this.child, required this.isVisible});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    if (!isVisible) {
      return Offstage(
        offstage: true,
        child: OverflowBox(
          minHeight: 0,
          maxHeight: double.infinity,
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    }
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => isVisible ? 130.0 : 0.0;

  @override
  double get minExtent => isVisible ? 130.0 : 0.0;

  @override
  bool shouldRebuild(covariant _StickyBannerDelegate oldDelegate) {
    return child != oldDelegate.child || isVisible != oldDelegate.isVisible;
  }
}
