import 'package:flutter/material.dart';
import 'schedule_screen.dart'; // <-- 1. Import new Schedule screen
import 'home_feed_screen.dart';
import 'network_screen.dart'; // <-- 2. Import new Network screen

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  // SET TO 1: We want the app to open on the Home Tab (the middle button)
  int _currentIndex = 1;

  // The new 3-Tab Contextual Layout
  final List<Widget> _screens = [
    const ScheduleScreen(), // Index 0: Left
    const HomeFeedScreen(), // Index 1: Middle (Default)
    const NetworkScreen(), // Index 2: Right
  ];

  @override
  Widget build(BuildContext context) {
    // Notice: There is NO AppBar here! The inner screens handle their own AppBars.
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor:
            Colors.teal[800], // Modern teal accent matching your theme
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: 'Network',
          ),
        ],
      ),
    );
  }
}
