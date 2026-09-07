import 'package:flutter/material.dart';
import '../firestore_data/schedule_service.dart';
import 'calendar_screen.dart'; // <--- Imports your custom day-view agenda calendar screen

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime? _selectedDate;

  bool _isClassActiveOrUpcoming(String endTimeString, bool isFuture) {
    if (isFuture) {
      return true;
    }
    if (endTimeString.isEmpty) return true;

    try {
      List<String> parts = endTimeString.split(':');
      int endHour = int.parse(parts[0]);
      int endMinute = int.parse(parts[1]);

      if (endHour >= 1 && endHour <= 6) {
        endHour += 12;
      }

      DateTime now = DateTime.now();
      DateTime classEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        endHour,
        endMinute,
      );

      return now.isBefore(classEndTime);
    } catch (e) {
      return true;
    }
  }

  bool _isItemOngoing(
    String startTimeString,
    String endTimeString,
    bool isFuture,
  ) {
    if (isFuture) return false;

    // If a specific past/future date is selected via calendar instead of today, it's not ongoing
    if (_selectedDate != null) {
      final now = DateTime.now();
      if (_selectedDate!.year != now.year ||
          _selectedDate!.month != now.month ||
          _selectedDate!.day != now.day) {
        return false;
      }
    }

    if (startTimeString.isEmpty || endTimeString.isEmpty) return false;

    try {
      List<String> startParts = startTimeString.split(':');
      int startHour = int.parse(startParts[0]);
      int startMinute = int.parse(startParts[1]);

      List<String> endParts = endTimeString.split(':');
      int endHour = int.parse(endParts[0]);
      int endMinute = int.parse(endParts[1]);

      if (startHour >= 1 && startHour <= 6) {
        startHour += 12;
      }
      if (endHour >= 1 && endHour <= 6) {
        endHour += 12;
      }

      DateTime now = DateTime.now();
      DateTime startTime = DateTime(
        now.year,
        now.month,
        now.day,
        startHour,
        startMinute,
      );
      DateTime endTime = DateTime(
        now.year,
        now.month,
        now.day,
        endHour,
        endMinute,
      );

      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: ScheduleService().getSmartSchedule(selectedDate: _selectedDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              title: const Text('Loading Schedule...'),
              backgroundColor: Colors.teal,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        }

        Map<String, dynamic> data = snapshot.data ?? {};
        String pageTitle = data['title'] ?? 'Schedule';
        List<dynamic> allClasses = data['classes'] ?? [];
        List<dynamic> personalEvents = data['events'] ?? [];
        bool isFuture = data['isFuture'] ?? false;
        bool isHoliday = data['isHoliday'] ?? false;
        String holidayMessage =
            data['holidayMessage'] ?? 'Holiday / No Lectures';

        // Check if today is an Exam Day based on contents or flags
        bool isExamDay = allClasses.any(
          (c) =>
              (c['isExam'] ?? false) == true ||
              (c['courseCode'] ?? '').toString().toUpperCase() == 'EXAM',
        );

        // --- DYNAMIC ACCENT SCHEMING ---
        Color primaryThemeColor;
        Color secondaryThemeColor;
        Color backgroundColor;

        if (isHoliday) {
          primaryThemeColor = Colors.blue.shade700;
          secondaryThemeColor = Colors.blue.shade50;
          backgroundColor = Colors.blue.shade50.withValues(alpha: 0.3);
        } else if (isExamDay) {
          primaryThemeColor = Colors.pink.shade700;
          secondaryThemeColor = Colors.pink.shade50;
          backgroundColor = Colors.pink.shade50.withValues(alpha: 0.2);
        } else {
          primaryThemeColor = Colors.teal.shade700;
          secondaryThemeColor = Colors.teal.shade50;
          backgroundColor = Colors.grey.shade100;
        }

        // Filter active classes if it's today
        List<dynamic> activeClasses = allClasses.where((lecture) {
          String endTime = lecture['endTime'] ?? '00:00';
          return _isClassActiveOrUpcoming(endTime, isFuture);
        }).toList();

        bool hasNoContent = activeClasses.isEmpty && personalEvents.isEmpty;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: Text(
              pageTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: primaryThemeColor,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              // Calendar Button -> Opens the Day View Agenda CalendarScreen
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded),
                tooltip: "Open Agenda Calendar",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  );
                },
              ),
            ],
          ),
          body: isHoliday
              ? _buildHolidayState(holidayMessage, primaryThemeColor)
              : hasNoContent
              ? _buildEmptyState(isFuture, primaryThemeColor)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- SECTION 1: LECTURES & EXAMS (Top Zone) ---
                      if (activeClasses.isNotEmpty) ...[
                        const Text(
                          "Lectures & Exams",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: activeClasses.length,
                          itemBuilder: (context, index) {
                            var lecture =
                                activeClasses[index] as Map<String, dynamic>;
                            String subject =
                                lecture['subject'] ?? 'Unknown Subject';
                            String courseCode =
                                lecture['courseCode'] ?? 'CO0000';
                            String startTime = lecture['startTime'] ?? '00:00';
                            String endTime = lecture['endTime'] ?? '00:00';
                            bool isCancelled = lecture['isCancelled'] ?? false;
                            String caBadge = lecture['caBadge'] ?? '';
                            bool isExamCard = lecture['isExam'] ?? false;
                            String venue = lecture['venue'] ?? '';

                            bool hasCa = caBadge.isNotEmpty;
                            bool isOngoing = _isItemOngoing(
                              startTime,
                              endTime,
                              isFuture,
                            );

                            // --- BORDER & GLOW CONFIGURATION ---
                            BoxBorder? cardBorder;
                            List<BoxShadow> cardShadows;

                            if (isOngoing && !isCancelled) {
                              Color glowColor = isExamCard
                                  ? Colors.pink.shade600
                                  : primaryThemeColor;
                              cardBorder = Border.all(
                                color: glowColor,
                                width: 2.2,
                              );
                              cardShadows = [
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  spreadRadius: 3,
                                  offset: const Offset(0, 4),
                                ),
                              ];
                            } else if (hasCa) {
                              cardBorder = Border.all(
                                color: primaryThemeColor.withValues(alpha: 0.6),
                                width: 1.5,
                              );
                              cardShadows = [
                                BoxShadow(
                                  color: primaryThemeColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ];
                            } else if (isExamCard) {
                              cardBorder = Border.all(
                                color: Colors.pink.shade300,
                                width: 1,
                              );
                              cardShadows = [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ];
                            } else {
                              cardBorder = null;
                              cardShadows = [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ];
                            }

                            return Opacity(
                              opacity: isCancelled ? 0.45 : 1.0,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: cardBorder,
                                  boxShadow: cardShadows,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: 6,
                                        child: Container(
                                          color: isCancelled
                                              ? Colors.red
                                              : isOngoing
                                              ? (isExamCard
                                                    ? Colors.pink.shade700
                                                    : Colors.amber.shade600)
                                              : isExamCard
                                              ? Colors.pink.shade600
                                              : primaryThemeColor,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          20,
                                          16,
                                          16,
                                          16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    subject,
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                      decoration: isCancelled
                                                          ? TextDecoration
                                                                .lineThrough
                                                          : null,
                                                    ),
                                                  ),
                                                ),
                                                if (isCancelled)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.red.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      "CANCELLED",
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  )
                                                else if (isOngoing)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isExamCard
                                                          ? Colors.pink.shade100
                                                          : Colors
                                                                .amber
                                                                .shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: isExamCard
                                                            ? Colors
                                                                  .pink
                                                                  .shade400
                                                            : Colors
                                                                  .amber
                                                                  .shade400,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      isExamCard
                                                          ? "ONGOING EXAM"
                                                          : "ONGOING",
                                                      style: TextStyle(
                                                        color: isExamCard
                                                            ? Colors
                                                                  .pink
                                                                  .shade900
                                                            : Colors
                                                                  .amber
                                                                  .shade900,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  )
                                                else if (hasCa)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          secondaryThemeColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color: primaryThemeColor
                                                            .withValues(
                                                              alpha: 0.3,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      caBadge.toUpperCase(),
                                                      style: TextStyle(
                                                        color:
                                                            primaryThemeColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Text(
                                                  courseCode,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: isExamCard
                                                        ? Colors.pink.shade700
                                                        : primaryThemeColor,
                                                  ),
                                                ),
                                                if (venue.isNotEmpty) ...[
                                                  const Text(
                                                    " • ",
                                                    style: TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  Icon(
                                                    Icons.location_on_outlined,
                                                    size: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    venue,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time_rounded,
                                                  size: 16,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "$startTime - $endTime",
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      // --- SECTION 2: PERSONAL & FEED EVENTS BOX (Purple Accent) ---
                      if (personalEvents.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.bookmark_added_rounded,
                              size: 20,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Personal & Feed Events",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.purple.shade200,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: personalEvents
                                .map((event) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.event_rounded,
                                            color: Colors.purple.shade700,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                event['title'] ?? 'Event',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: Colors.purple.shade900,
                                                ),
                                              ),
                                              if ((event['description'] ?? '')
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  event['description'],
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList()
                                .cast<Widget>(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHolidayState(String message, Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.beach_access_rounded,
                size: 70,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enjoy your break, recharge, and stay safe!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isFuture, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFuture ? Icons.event_available : Icons.celebration_rounded,
            size: 70,
            color: accentColor.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            isFuture
                ? "No lectures scheduled!"
                : "Today's lectures are over, yay!",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Time to relax or catch up on coursework.",
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
