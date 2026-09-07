import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- CACHE STATE VARIABLES ---
  Map<String, List<Map<String, dynamic>>>? _cachedMonthData;
  DateTime? _lastCacheDate;

  /// Aggregates upcoming exams, CAs from batch overrides, and automatic event notices
  /// day-by-day starting from the provided startDate forward.
  Future<Map<String, List<Map<String, dynamic>>>> getMonthEvents(
    DateTime startDate,
  ) async {
    // Normalize today's date to midnight for cache comparison
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    // Return cached data instantly if it's still the same day
    if (_cachedMonthData != null && _lastCacheDate == today) {
      debugPrint("Serving calendar agenda from memory cache 🚀");
      return _cachedMonthData!;
    }

    debugPrint("Fetching fresh calendar agenda from Firestore...");
    Map<String, List<Map<String, dynamic>>> monthData = {};
    final userId = _auth.currentUser?.uid;

    // 1. Fetch user profile to get their batchId (e.g., '23com')
    String batchId = '23com';
    if (userId != null) {
      try {
        var userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data() != null) {
          batchId =
              (userDoc.data() as Map<String, dynamic>)['batchId'] ?? '23com';
        }
      } catch (e) {
        debugPrint("Error fetching user batch for agenda: $e");
      }
    }

    // Pre-fetch all event notices to avoid querying Firestore 60 times
    List<QueryDocumentSnapshot> eventNotices = [];
    try {
      var noticeSnap = await _firestore
          .collection('notices')
          .where('tag', isEqualTo: 'EVENT')
          .get();
      eventNotices = noticeSnap.docs;
    } catch (e) {
      debugPrint("Error fetching event notices: $e");
    }

    // 2. Loop through the next 60 days starting from today onwards
    for (int i = 0; i < 60; i++) {
      DateTime date = startDate.add(Duration(days: i));
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      List<Map<String, dynamic>> dayItems = [];

      // 3. Check schedule overrides (Exams / CAs / Holidays) for this specific date
      try {
        var overrideDoc = await _firestore
            .collection('schedule_overrides')
            .doc('${batchId}_$dateStr')
            .get();

        if (overrideDoc.exists && overrideDoc.data() != null) {
          var data = overrideDoc.data() as Map<String, dynamic>;

          // Add Exams (Red)
          if (data['exams'] != null) {
            for (var exam in data['exams']) {
              dayItems.add({
                'title': exam['subject'] ?? 'Exam',
                'code': exam['courseCode'] ?? 'EXAM',
                'type': 'EXAM',
                'time': exam['startTime'] ?? '',
              });
            }
          }

          // Add CAs or modified classes if flagged
          if (data['classes'] != null) {
            for (var c in data['classes']) {
              if ((c['caBadge'] ?? '').toString().isNotEmpty) {
                dayItems.add({
                  'title': c['subject'] ?? 'Continuous Assessment',
                  'code': c['courseCode'] ?? c['caBadge'],
                  'type': 'CA',
                  'time': c['startTime'] ?? '',
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching overrides for $dateStr: $e");
      }

      // 4. Match automatic event notices from the pre-fetched list for this date and batch
      for (var doc in eventNotices) {
        var nData = doc.data() as Map<String, dynamic>;
        String affectedDate = nData['affectedDate'] ?? '';

        if (affectedDate == dateStr) {
          String noticeBatch =
              (nData['batch'] ??
                      nData['batchId'] ??
                      nData['targetBatch'] ??
                      'all')
                  .toString()
                  .toLowerCase();
          String userBatchLower = batchId.toLowerCase();

          bool matchesBatch =
              noticeBatch == 'all' ||
              noticeBatch == 'all students' ||
              noticeBatch == userBatchLower ||
              userBatchLower.contains(noticeBatch);

          if (matchesBatch) {
            dayItems.add({
              'title': nData['title'] ?? 'Event',
              'code': 'EVENT',
              'type': 'EVENT',
              'time': '',
            });
          }
        }
      }

      // 5. Store day items if any exist for this date
      if (dayItems.isNotEmpty) {
        monthData[dateStr] = dayItems;
      }
    }

    // Save data to cache and record today's date
    _cachedMonthData = monthData;
    _lastCacheDate = today;

    return monthData;
  }
}
