import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>> getSmartSchedule({
    DateTime? selectedDate,
  }) async {
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
      DateTime targetDateTime;
      String targetDayName = '';
      String displayTitle = '';
      bool isFuture = false;

      if (selectedDate != null) {
        // --- CUSTOM DATE SELECTED VIA CALENDAR PICKER ---
        targetDateTime = selectedDate;
        targetDayName = _getDayNameFromInt(selectedDate.weekday);
        displayTitle = DateFormat('EEEE, MMM d, yyyy').format(selectedDate);

        // Check if selected date is in the future compared to today
        DateTime todayMidnight = DateTime(now.year, now.month, now.day);
        DateTime selectedMidnight = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        );
        isFuture = selectedMidnight.isAfter(todayMidnight);
      } else {
        // --- AUTOMATED INTELLIGENT ROLLOVER LOGIC ---
        targetDateTime = now;
        if (now.weekday == DateTime.saturday ||
            now.weekday == DateTime.sunday) {
          targetDayName = _getDayNameFromInt(now.weekday);
          displayTitle = "Weekend Schedule";
          isFuture = false;
        } else if (now.hour >= 18) {
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
          targetDayName = _getDayNameFromInt(now.weekday);
          displayTitle = "Today's Schedule";
          isFuture = false;
        }
      }

      // Format target date for Firestore lookup (e.g., "2026-09-05")
      String targetDateString = DateFormat('yyyy-MM-dd').format(targetDateTime);

      // ==========================================
      // DETERMINISTIC OVERRIDE CHECK (Lectures/Exams)
      // ==========================================
      DocumentSnapshot overrideDoc = await _firestore
          .collection('schedule_overrides')
          .doc('${batchId}_$targetDateString')
          .get();

      List<dynamic> finalTimeline = [];
      bool isHoliday = false;
      String holidayMessage = '';

      if (overrideDoc.exists && overrideDoc.data() != null) {
        var overrideData = overrideDoc.data() as Map<String, dynamic>;

        isHoliday = overrideData['isHoliday'] ?? false;
        holidayMessage =
            overrideData['holidayMessage'] ?? 'Holiday / No Lectures';
        bool isExamDay = overrideData['isExamDay'] ?? false;

        if (isHoliday) {
          finalTimeline = []; // Empty timeline for holidays
        } else if (isExamDay) {
          List<dynamic> rawExams = overrideData['exams'] ?? [];
          finalTimeline = rawExams
              .map(
                (exam) => {
                  'subject': exam['subject'] ?? 'Scheduled Exam',
                  'courseCode': exam['courseCode'] ?? 'EXAM',
                  'startTime': exam['startTime'] ?? '09:00',
                  'endTime': exam['endTime'] ?? '12:00',
                  'venue': exam['venue'] ?? '',
                  'isExam': true,
                },
              )
              .toList();
        } else {
          // Daily Edits (Cancellations, CAs, Added Slots)
          List<dynamic> rawClasses = overrideData['classes'] ?? [];
          finalTimeline = rawClasses
              .map((c) => Map<String, dynamic>.from(c))
              .toList();
        }
      } else {
        // AUTOMATIC WEEKEND HOLIDAY CHECK
        if (targetDateTime.weekday == DateTime.saturday ||
            targetDateTime.weekday == DateTime.sunday) {
          isHoliday = true;
          holidayMessage = "It's the weekend! Enjoy your time off.";
          finalTimeline = [];
        } else {
          // --- FALLBACK: BASE SCHEDULE TEMPLATE ---
          DocumentSnapshot scheduleDoc = await _firestore
              .collection('base_schedules')
              .doc(batchId)
              .get();

          if (scheduleDoc.exists) {
            var scheduleData = scheduleDoc.data() as Map<String, dynamic>;
            finalTimeline = List.from(scheduleData[targetDayName] ?? []);
          }
        }
      }

      // Sort official lectures/exams strictly by Start Time
      finalTimeline.sort(
        (a, b) => _convertTimeToSortableInt(
          a['startTime'],
        ).compareTo(_convertTimeToSortableInt(b['startTime'])),
      );

      // ==========================================
      // FETCH AUTOMATIC EVENT NOTICES (For Purple Box)
      // ==========================================
      List<Map<String, dynamic>> personalEventsList = [];
      try {
        QuerySnapshot noticeSnap = await _firestore
            .collection('notices')
            .where('tag', isEqualTo: 'EVENT')
            .get();

        for (var doc in noticeSnap.docs) {
          var nData = doc.data() as Map<String, dynamic>;
          String affectedDate = nData['affectedDate'] ?? '';

          if (affectedDate == targetDateString) {
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
              personalEventsList.add({
                'id': doc.id,
                'title': nData['title'] ?? 'Event',
                'description': nData['description'] ?? '',
                'date': targetDateString,
                'type': 'EVENT',
              });
            }
          }
        }
      } catch (e) {
        print("Error fetching event notices for schedule: $e");
      }

      return {
        'title': displayTitle,
        'classes': finalTimeline,
        'events':
            personalEventsList, // <--- Automatic event notices separated for the bottom box!
        'isFuture': isFuture,
        'isHoliday': isHoliday,
        'holidayMessage': holidayMessage,
      };
    } catch (e) {
      print("Error fetching smart schedule: $e");
      return _emptyResult();
    }
  }

  // ==========================================
  // HERO COUNTDOWN DATA ENGINE
  // ==========================================
  Future<Map<String, dynamic>> getHeroCountdownData() async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return {'mode': 'sleeping'};

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      String batchId = userDoc.exists
          ? (userDoc.data() as Map<String, dynamic>)['batchId'] ?? '23com'
          : '23com';

      DateTime now = DateTime.now();
      String dateStr = DateFormat('yyyy-MM-dd').format(now);
      String dayName = _getDayNameFromInt(now.weekday);

      DocumentSnapshot overrideDoc = await _firestore
          .collection('schedule_overrides')
          .doc('${batchId}_$dateStr')
          .get();

      bool isHoliday = false;
      String holidayMessage = 'Holiday / Break';
      bool isExamDay = false;
      List<dynamic> classes = [];
      List<dynamic> exams = [];

      if (overrideDoc.exists && overrideDoc.data() != null) {
        var data = overrideDoc.data() as Map<String, dynamic>;
        isHoliday = data['isHoliday'] ?? false;
        holidayMessage = data['holidayMessage'] ?? 'Holiday / Break';
        isExamDay = data['isExamDay'] ?? false;
        classes = data['classes'] ?? [];
        exams = data['exams'] ?? [];
      } else {
        if (now.weekday == DateTime.saturday ||
            now.weekday == DateTime.sunday) {
          isHoliday = true;
          holidayMessage = "It's the weekend! Enjoy your time off.";
        } else {
          DocumentSnapshot baseDoc = await _firestore
              .collection('base_schedules')
              .doc(batchId)
              .get();
          if (baseDoc.exists && baseDoc.data() != null) {
            var baseData = baseDoc.data() as Map<String, dynamic>;
            classes = baseData[dayName] ?? [];
          }
        }
      }

      if (isHoliday) {
        return {'mode': 'holiday', 'message': holidayMessage};
      }

      if (isExamDay && exams.isNotEmpty) {
        var nextExam = exams.first;
        String startTime = nextExam['startTime'] ?? '09:00';
        DateTime examDateTime = _parseTimeStringToDateTime(now, startTime);

        if (examDateTime.isAfter(now)) {
          return {
            'mode': 'exam',
            'title': nextExam['subject'] ?? 'Exam',
            'courseCode': nextExam['courseCode'] ?? 'EXAM',
            'venue': nextExam['venue'] ?? '',
            'targetTime': examDateTime,
          };
        }
      }

      List<Map<String, dynamic>> upcomingClasses = [];
      for (var c in classes) {
        if (c['isCancelled'] == true) continue;
        String startTime = c['startTime'] ?? '00:00';
        DateTime classDateTime = _parseTimeStringToDateTime(now, startTime);
        if (classDateTime.isAfter(now)) {
          upcomingClasses.add({
            ...Map<String, dynamic>.from(c),
            'dateTime': classDateTime,
          });
        }
      }

      upcomingClasses.sort(
        (a, b) =>
            (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
      );

      if (upcomingClasses.isNotEmpty) {
        var nextClass = upcomingClasses.first;
        DateTime classTime = nextClass['dateTime'] as DateTime;
        Duration diff = classTime.difference(now);
        double hoursUntil = diff.inMinutes / 60.0;

        if (hoursUntil <= 3.0) {
          return {
            'mode': 'imminent_lecture',
            'title': nextClass['subject'] ?? 'Lecture',
            'courseCode': nextClass['courseCode'] ?? '',
            'targetTime': classTime,
          };
        } else if (hoursUntil <= 12.0) {
          return {
            'mode': 'resting',
            'message': 'No lectures soon',
            'targetTime': classTime,
          };
        }
      }

      return {'mode': 'sleeping', 'message': 'All caught up for today'};
    } catch (e) {
      print("Error fetching hero countdown data: $e");
      return {'mode': 'sleeping'};
    }
  }

  DateTime _parseTimeStringToDateTime(DateTime baseDate, String timeStr) {
    try {
      List<String> parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      if (hour >= 1 && hour <= 6) {
        hour += 12;
      }
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
    } catch (e) {
      return baseDate.add(const Duration(hours: 99));
    }
  }

  Map<String, dynamic> _emptyResult() {
    return {
      'title': 'Schedule',
      'classes': [],
      'events': [],
      'isFuture': false,
      'isHoliday': false,
    };
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

  int _convertTimeToSortableInt(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) {
      return 9999;
    }
    try {
      List<String> parts = timeStr.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      if (hour >= 1 && hour <= 6) {
        hour += 12;
      }
      return (hour * 60) + minute;
    } catch (e) {
      return 9999;
    }
  }
}
