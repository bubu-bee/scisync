import 'package:flutter/material.dart';
import 'calendar_screen.dart'; // Import the calendar so we can push to it

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Schedule'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 1, // Gives a slight shadow
        actions: [
          // The Smart Calendar Button!
          IconButton(
            icon: const Icon(Icons.calendar_month, size: 28),
            onPressed: () {
              // Pushes the calendar over the whole app, hiding the bottom bar!
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const Center(child: Text("Dynamic Timeline Cards Go Here")),
    );
  }
}
