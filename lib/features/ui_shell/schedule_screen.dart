import 'package:flutter/material.dart';
import '../firestore_data/schedule_service.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  // Time filter now accepts the 'isFuture' flag
  bool _isClassActiveOrUpcoming(String endTimeString, bool isFuture) {
    if (isFuture) {
      return true; // If we are looking at tomorrow's schedule, show everything!
    }
    if (endTimeString.isEmpty) return true;

    try {
      List<String> parts = endTimeString.split(':');
      int endHour = int.parse(parts[0]);
      int endMinute = int.parse(parts[1]);

      if (endHour >= 1 && endHour <= 6) {
        endHour += 12; // Convert 1:30 PM to 13:30
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

  @override
  Widget build(BuildContext context) {
    // We wrap the ENTIRE Scaffold in the FutureBuilder so the AppBar title can change dynamically!
    return FutureBuilder<Map<String, dynamic>>(
      future: ScheduleService().getSmartSchedule(),
      builder: (context, snapshot) {
        // Default loading view
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title: const Text('Loading Schedule...'),
              backgroundColor: Colors.teal,
            ),
            body: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        }

        // Extract the smart data from our backend
        Map<String, dynamic> data = snapshot.data ?? {};
        String pageTitle = data['title'] ?? 'Schedule';
        List<dynamic> allClasses = data['classes'] ?? [];
        bool isFuture = data['isFuture'] ?? false;

        // FILTER MAGIC: Hide old classes ONLY if we are looking at today's schedule
        List<dynamic> activeClasses = allClasses.where((lecture) {
          String endTime = lecture['endTime'] ?? '00:00';
          return _isClassActiveOrUpcoming(endTime, isFuture);
        }).toList();

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Text(
              pageTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: activeClasses.isEmpty
              ? _buildEmptyState(
                  isFuture,
                ) // Pass the flag to show the right message
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: activeClasses.length,
                  itemBuilder: (context, index) {
                    var lecture = activeClasses[index] as Map<String, dynamic>;
                    String subject = lecture['subject'] ?? 'Unknown Subject';
                    String courseCode = lecture['courseCode'] ?? 'CO0000';
                    String startTime = lecture['startTime'] ?? '00:00';
                    String endTime = lecture['endTime'] ?? '00:00';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              courseCode,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "$startTime - $endTime",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  // The fun, updated empty state!
  Widget _buildEmptyState(bool isFuture) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFuture ? Icons.event_available : Icons.celebration,
            size: 70,
            color: Colors.teal.shade200,
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
          Text(
            isFuture
                ? "Enjoy your day off."
                : "Time to relax or catch up on coursework.",
            style: const TextStyle(fontSize: 14, color: Colors.black45),
          ),
        ],
      ),
    );
  }
}
