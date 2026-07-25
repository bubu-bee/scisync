import 'package:flutter/material.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Network'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 1,
        actions: [
          // The Smart Search Button!
          IconButton(
            icon: const Icon(Icons.search, size: 28),
            onPressed: () {
              // We will add search logic here later
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search opening...')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: const Center(child: Text("Student Directory List Goes Here")),
    );
  }
}
