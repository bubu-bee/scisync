import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeService {
  // Singleton pattern so we don't recreate the instance
  static final NoticeService _instance = NoticeService._internal();
  factory NoticeService() => _instance;
  NoticeService._internal();

  final CollectionReference _collection = FirebaseFirestore.instance.collection(
    'notices',
  );

  /// Streams notices, ordered by newest first, limited to 50.
  /// Optionally filters by targetBatch (e.g., '23com' or 'All Students').
  Stream<QuerySnapshot> streamNotices({String? batchFilter}) {
    Query query = _collection.orderBy('timestamp', descending: true).limit(50);

    // If a specific batch is requested, show notices for that batch AND general notices[cite: 1].
    if (batchFilter != null && batchFilter != 'All Students') {
      query = query.where(
        'targetBatch',
        whereIn: [batchFilter, 'All Students'],
      );
    }

    return query.snapshots();
  }

  /// Writes a new notice to Firestore with a server-side timestamp[cite: 1].
  Future<void> postNotice(Map<String, dynamic> noticeData) async {
    await _collection.add({
      ...noticeData,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Adds +1 to a specific reaction counter (e.g., 'likes' or 'hearts')
  Future<void> addReaction(String noticeId, String reactionType) async {
    await _collection.doc(noticeId).update({
      // This tells Firebase: "Whatever the number is right now, add 1 to it!"
      reactionType: FieldValue.increment(1),
    });
  }
}
