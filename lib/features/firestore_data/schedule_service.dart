import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // NEW: For formatting dates!

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getSmartSchedule() async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return _emptyResult();

      // 1. Get User Profile & Batch
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      String batchId = userDoc.exists
          ? (userDoc.data() as Map<String, dynamic>)['batchId'] ?? '23com'
          : '23com';

      // 2. Figure out what day we are targeting
      DateTime now = DateTime.now();
      DateTime targetDateTime = now;
      String targetDayName = '';
      String displayTitle = '';
      bool isFuture = false;

      // Time Rollover Logic
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        // Skip to Monday
        int daysToAdd = (DateTime.monday - now.weekday + 7) % 7;
        if (daysToAdd == 0) daysToAdd = 7;
        targetDateTime = now.add(Duration(days: daysToAdd));
        targetDayName = 'monday';
        displayTitle = "Monday's Schedule";
        isFuture = true;
      } else if (now.hour >= 18) {
        // Past 6 PM? Go to tomorrow (or Monday if it's Friday)
        if (now.weekday == DateTime.friday) {
          targetDateTime = now.add(const Duration(days: 3));
          targetDayName = 'monday';
          displayTitle = "Monday's Schedule";
        } else {
          targetDateTime = now.add(const Duration(days: 1));
          targetDayName = _getDayNameFromInt(targetDateTime.weekday);
          displayTitle = "Tomorrow's Schedule";
        }
        isFuture = true;
      } else {
        // Normal Today
        targetDayName = _getDayNameFromInt(now.weekday);
        displayTitle = "Today's Schedule";
        isFuture = false;
      }

      // Format the target date (e.g., "2026-09-02") to search Firebase
      String targetDateString = DateFormat('yyyy-MM-dd').format(targetDateTime);

      // --- FETCH STREAM 1: BASE SCHEDULE ---
      DocumentSnapshot scheduleDoc = await _firestore
          .collection('base_schedules')
          .doc(batchId)
          .get();
      List<dynamic> baseClasses = [];
      if (scheduleDoc.exists) {
        var scheduleData = scheduleDoc.data() as Map<String, dynamic>;
        baseClasses = List.from(scheduleData[targetDayName] ?? []);
      }

      // --- FETCH STREAM 2: NOTICES (Cancellations & Exams) ---
      QuerySnapshot noticeSnap = await _firestore
          .collection('notices')
          .where('targetBatch', whereIn: ['all', batchId])
          .where('affectedDate', isEqualTo: targetDateString)
          .get();

      // --- FETCH STREAM 3: PERSONAL STUDENT EVENTS ---
      QuerySnapshot eventSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('student_events')
          .where('eventDate', isEqualTo: targetDateString)
          .where('addedToSchedule', isEqualTo: true)
          .get();

      // ==========================================
      // THE MERGE ALGORITHM (Where the magic happens)
      // ==========================================

      List<dynamic> finalTimeline = List.from(baseClasses);

      // 1. Apply Cancellations & Exams
      for (var doc in noticeSnap.docs) {
        var notice = doc.data() as Map<String, dynamic>;

        // FIXED: Read 'tag' (or 'aiTag' as fallback) and make it uppercase for robust matching
        String tag = (notice['tag'] ?? notice['aiTag'] ?? '')
            .toString()
            .toUpperCase();
        String timeStr = notice['affectedStartTime'] ?? '';

        print(
          "🔍 [ScheduleService] Notice Found -> Tag: $tag, Time: $timeStr, Date: ${notice['affectedDate']}",
        );

        // FIXED: Match uppercase 'CANCELLED' or 'CANCELLATION'
        if (tag == 'CANCELLED' || tag == 'CANCELLATION') {
          // Remove the lecture that matches this start time!
          finalTimeline.removeWhere(
            (lecture) => lecture['startTime'] == timeStr,
          );
          print(
            "🗑️ [ScheduleService] Successfully removed lecture at $timeStr",
          );
        } else if (tag == 'EXAM' || tag == 'CA') {
          // Automatically inject Exams into the schedule
          finalTimeline.add({
            'subject': notice['title'] ?? 'Scheduled Exam',
            'courseCode': tag,
            'startTime': timeStr,
            'endTime': notice['affectedEndTime'] ?? 'TBA',
          });
        }
      }

      // 2. Apply Personal Opt-in Events
      for (var doc in eventSnap.docs) {
        var event = doc.data() as Map<String, dynamic>;
        String eventStart = event['startTime'] ?? '';

        // Conflict Check: Only add it if there isn't already a lecture starting at this exact time
        bool hasConflict = finalTimeline.any(
          (lecture) => lecture['startTime'] == eventStart,
        );

        if (!hasConflict) {
          finalTimeline.add({
            'subject': event['title'] ?? 'Personal Event',
            'courseCode': 'EVENT',
            'startTime': eventStart,
            'endTime': event['endTime'] ?? 'TBA',
          });
        }
      }

      // 3. Sort the timeline strictly by Start Time so the UI looks perfect!
      finalTimeline.sort(
        (a, b) => _convertTimeToSortableInt(
          a['startTime'],
        ).compareTo(_convertTimeToSortableInt(b['startTime'])),
      );

      return {
        'title': displayTitle,
        'classes': finalTimeline,
        'isFuture': isFuture,
      };
    } catch (e) {
      print("Error fetching dynamic schedule: $e");
      return _emptyResult();
    }
  }

  // --- Helpers ---
  Map<String, dynamic> _emptyResult() {
    return {'title': 'Schedule', 'classes': [], 'isFuture': false};
  }

  String _getDayNameFromInt(int day) {
    switch (day) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  // Safe time converter for sorting (handles 01:30 PM vs 13:30)
  int _convertTimeToSortableInt(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return 9999; // Push invalid times to the bottom
    }
    try {
      List<String> parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      if (hour >= 1 && hour <= 6) {
        hour += 12; // Convert 1:30 to 13:30 for sorting
      }
      return (hour * 60) + minute; // Total minutes past midnight
    } catch (e) {
      return 9999;
    }
  }
}
