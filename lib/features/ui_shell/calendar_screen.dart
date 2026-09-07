import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../firestore_data/calendar_service.dart'; // Adjust path if necessary to match your project structure

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late Future<Map<String, List<Map<String, dynamic>>>> _agendaDataFuture;

  @override
  void initState() {
    super.initState();
    // Fetch agenda items starting from today moving forward into future months
    _agendaDataFuture = CalendarService().getMonthEvents(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Academic Agenda & Timeline',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _agendaDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading agenda: ${snapshot.error}'),
            );
          }

          final data = snapshot.data ?? {};

          if (data.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "No upcoming exams, CAs, or events found.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
            );
          }

          final sortedDates = data.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              String dateStr = sortedDates[index];
              List<Map<String, dynamic>> items = data[dateStr]!;

              DateTime parsedDate = DateTime.parse(dateStr);
              String formattedDateHeader = DateFormat(
                'EEEE, MMM d, yyyy',
              ).format(parsedDate);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Header
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formattedDateHeader,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 1),

                    // Inline items for this date
                    ...items.map((item) {
                      String type = item['type'] ?? '';
                      Color badgeColor;
                      Color textColor;

                      // Strict Color Coding
                      if (type == 'EXAM') {
                        badgeColor = Colors.red.shade50;
                        textColor = Colors.red.shade700;
                      } else if (type == 'CA') {
                        badgeColor = Colors.teal.shade50;
                        textColor = Colors.teal.shade700;
                      } else {
                        // EVENT (Purple)
                        badgeColor = Colors.purple.shade50;
                        textColor = Colors.purple.shade700;
                      }

                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${item['code']} ${item['time'].isNotEmpty ? '• ${item['time']}' : ''}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: textColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                type,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
