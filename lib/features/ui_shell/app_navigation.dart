import 'package:flutter/material.dart';
import 'home_feed_screen.dart';
import 'profile_screen.dart'; // Import the real Profile screen

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _currentIndex = 0;

  // The 5 primary tabs of your app structure
  final List<Widget> _screens = [
    const HomeFeedScreen(), // Index 0: Home Feed
    const Center(
      child: Text("Calendar Goes Here", style: TextStyle(fontSize: 24)),
    ), // Index 1: Calendar
    const Center(
      child: Text("Live Schedule Goes Here", style: TextStyle(fontSize: 24)),
    ), // Index 2: Schedule
    const Center(
      child: Text("SciBot Chat Goes Here", style: TextStyle(fontSize: 24)),
    ), // Index 3: Chat
    const ProfileScreen(), // Index 4: Real User Profile
  ];

  @override
  Widget build(BuildContext context) {
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
