import 'package:flutter/material.dart';

// 1. We use a StatefulWidget because the screen needs to "remember" which tab is clicked.
class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  // 2. This variable keeps track of which tab we are currently on (starts at 0 - Home).
  int _currentIndex = 0;

  // 3. This is a list of our "Screens". Right now, they are just empty placeholders.
  final List<Widget> _screens = [
    const Center(
      child: Text("Home Feed Goes Here", style: TextStyle(fontSize: 24)),
    ),
    const Center(
      child: Text("Calendar Goes Here", style: TextStyle(fontSize: 24)),
    ),
    const Center(
      child: Text("Live Schedule Goes Here", style: TextStyle(fontSize: 24)),
    ),
    const Center(
      child: Text("SciBot Chat Goes Here", style: TextStyle(fontSize: 24)),
    ),
    const Center(
      child: Text("Profile Goes Here", style: TextStyle(fontSize: 24)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 4. Scaffold is the master blank canvas for any Flutter screen.
    return Scaffold(
      backgroundColor: Colors.grey[100], // A nice soft modern background color
      // 5. The body displays whichever screen matches our _currentIndex
      body: _screens[_currentIndex],

      // 6. The actual Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color.fromARGB(
          255,
          131,
          31,
          31,
        ), // Modern accent color
        unselectedItemColor: Colors.grey,
        type:
            BottomNavigationBarType.fixed, // Keeps icons from shifting weirdly
        onTap: (index) {
          // 7. setState tells Flutter: "Hey, the index changed! Redraw the screen!"
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
