import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HeroCountdownWidget extends StatefulWidget {
  final VoidCallback? onTap; // <--- Clean callback for navigation

  const HeroCountdownWidget({super.key, this.onTap});

  @override
  State<HeroCountdownWidget> createState() => _HeroCountdownWidgetState();
}

class _HeroCountdownWidgetState extends State<HeroCountdownWidget> {
  Timer? _timer;
  late final Stream<Map<String, dynamic>> _countdownStream;

  @override
  void initState() {
    super.initState();
    _countdownStream = _getHeroCountdownStream();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimeRemaining(DateTime target) {
    final now = DateTime.now();
    final difference = target.difference(now);

    if (difference.isNegative) return "STARTED";

    int days = difference.inDays;
    int hours = difference.inHours % 24;
    int minutes = difference.inMinutes % 60;

    if (days > 0) {
      return "$days d ${hours}h";
    } else {
      return "${hours.toString().padLeft(2, '0')} : ${minutes.toString().padLeft(2, '0')}";
    }
  }

  String _getTimeLabel(DateTime target) {
    final difference = target.difference(DateTime.now());
    if (difference.inDays > 0) return "Days Left";
    return "Hours : Mins";
  }

  Stream<Map<String, dynamic>> _getHeroCountdownStream() async* {
    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;

    final userId = auth.currentUser?.uid;
    if (userId == null) {
      yield {'mode': 'sleeping', 'message': 'Please log in'};
      return;
    }

    await for (var userSnapshot
        in firestore.collection('users').doc(userId).snapshots()) {
      String batchId = '23com';
      if (userSnapshot.exists && userSnapshot.data() != null) {
        batchId =
            (userSnapshot.data() as Map<String, dynamic>)['batchId'] ?? '23com';
      }

      DateTime now = DateTime.now();
      String dateStr = DateFormat('yyyy-MM-dd').format(now);
      String dayName = _getDayNameFromInt(now.weekday);

      DateTime tomorrow = now.add(const Duration(days: 1));
      String tomorrowDateStr = DateFormat('yyyy-MM-dd').format(tomorrow);

      await for (var overrideSnapshot
          in firestore
              .collection('schedule_overrides')
              .doc('${batchId}_$dateStr')
              .snapshots()) {
        bool isHoliday = false;
        String holidayMessage = 'Holiday / Break';
        List<dynamic> classes = [];
        List<dynamic> exams = [];

        if (overrideSnapshot.exists && overrideSnapshot.data() != null) {
          var data = overrideSnapshot.data() as Map<String, dynamic>;
          isHoliday = data['isHoliday'] ?? false;
          holidayMessage = data['holidayMessage'] ?? 'Holiday / Break';
          classes = data['classes'] ?? [];
          exams = data['exams'] ?? [];
        } else {
          if (now.weekday == DateTime.saturday ||
              now.weekday == DateTime.sunday) {
            isHoliday = true;
            holidayMessage = "It's the weekend! Enjoy your time off.";
          } else {
            var baseDoc = await firestore
                .collection('base_schedules')
                .doc(batchId)
                .get();
            if (baseDoc.exists && baseDoc.data() != null) {
              var baseData = baseDoc.data() as Map<String, dynamic>;
              classes = baseData[dayName] ?? [];
            }
          }
        }

        // Fetch tomorrow's exams as well to check for the 24-hour override window
        List<dynamic> tomorrowExams = [];
        try {
          var tomorrowDoc = await firestore
              .collection('schedule_overrides')
              .doc('${batchId}_$tomorrowDateStr')
              .get();
          if (tomorrowDoc.exists && tomorrowDoc.data() != null) {
            tomorrowExams =
                (tomorrowDoc.data() as Map<String, dynamic>)['exams'] ?? [];
          }
        } catch (_) {}

        // --- PRIORITY 1: URGENT EXAM OVERRIDE (<= 24 Hours) ---
        Map<String, dynamic>? urgentExam;
        DateTime? urgentExamTime;

        // Check today's exams
        for (var e in exams) {
          String startTime = e['startTime'] ?? '09:00';
          DateTime examDT = _parseTimeStringToDateTime(now, startTime);
          Duration diff = examDT.difference(now);
          if (!diff.isNegative && diff.inHours <= 24) {
            urgentExam = Map<String, dynamic>.from(e);
            urgentExamTime = examDT;
            break;
          }
        }

        // If no urgent exam today, check tomorrow's exams within 24h window
        if (urgentExam == null) {
          for (var e in tomorrowExams) {
            String startTime = e['startTime'] ?? '09:00';
            DateTime examDT = _parseTimeStringToDateTime(tomorrow, startTime);
            Duration diff = examDT.difference(now);
            if (!diff.isNegative && diff.inHours <= 24) {
              urgentExam = Map<String, dynamic>.from(e);
              urgentExamTime = examDT;
              break;
            }
          }
        }

        if (urgentExam != null && urgentExamTime != null) {
          yield {
            'mode': 'exam',
            'title': urgentExam['subject'] ?? 'Exam',
            'courseCode': urgentExam['courseCode'] ?? 'EXAM',
            'venue': urgentExam['venue'] ?? '',
            'targetTime': urgentExamTime,
          };
          continue;
        }

        // --- PRIORITY 2: HOLIDAY MODE ---
        if (isHoliday) {
          yield {'mode': 'holiday', 'message': holidayMessage};
          continue;
        }

        // --- PRIORITY 3: IMMINENT LECTURE MODE (<= 3 Hours) ---
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

          // Strictly within 3 hours ("nobody cares" if further out)
          if (hoursUntil <= 3.0 && !diff.isNegative) {
            yield {
              'mode': 'imminent_lecture',
              'title': nextClass['subject'] ?? 'Lecture',
              'courseCode': nextClass['courseCode'] ?? '',
              'targetTime': classTime,
            };
            continue;
          }
        }

        // --- PRIORITY 4: SLEEP / REST MODE (Default) ---
        yield {'mode': 'sleeping', 'message': 'All caught up for today'};
      }
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _countdownStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.teal,
                ),
              ),
            ),
          );
        }

        var countdownData = snapshot.data ?? {'mode': 'sleeping'};
        String mode = countdownData['mode'] ?? 'sleeping';

        // --- STATE 1: HOLIDAY MODE ---
        if (mode == 'holiday') {
          String message = countdownData['message'] ?? "Campus Holiday & Break";
          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade800, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.beach_access_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "CAMPUS BREAK",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Enjoy your time off & recharge!",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // --- STATE 2: EXAM MODE ---
        if (mode == 'exam') {
          String title = countdownData['title'] ?? 'Exam';
          String courseCode = countdownData['courseCode'] ?? 'EXAM';
          String venue = countdownData['venue'] ?? '';
          DateTime targetTime = countdownData['targetTime'] ?? DateTime.now();

          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink.shade800, Colors.deepPurple.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "CRUNCH TIME: EXAM SOON",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$courseCode ${venue.isNotEmpty ? '• $venue' : ''}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimeRemaining(targetTime),
                          style: TextStyle(
                            color: Colors.pink.shade900,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getTimeLabel(targetTime),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // --- STATE 3: IMMINENT LECTURE MODE ---
        if (mode == 'imminent_lecture') {
          String title = countdownData['title'] ?? 'Lecture';
          String courseCode = countdownData['courseCode'] ?? '';
          DateTime targetTime = countdownData['targetTime'] ?? DateTime.now();

          return GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade800, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "NEXT LECTURE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.circle,
                              color: Colors.tealAccent,
                              size: 8,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              "Imminent",
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          courseCode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimeRemaining(targetTime),
                          style: TextStyle(
                            color: Colors.teal.shade900,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          "Hours : Mins",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // --- STATE 4: SLEEP / REST MODE ---
        String statusMessage =
            countdownData['message'] ?? 'All caught up for today';
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueGrey.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: Colors.amberAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "STATUS: RESTING",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "No urgent lectures or exams right now 💤",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
