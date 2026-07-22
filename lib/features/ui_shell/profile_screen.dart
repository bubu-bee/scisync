import 'package:flutter/material.dart';
import '../firestore_data/auth_service.dart';
import 'admin_notice_form.dart'; // Import the admin form so we can open it from here

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Icon(Icons.person, size: 90, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              "Student Account",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Connected to Firebase Database",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const Spacer(),

            // HACKATHON HELPER: Secret Admin Menu Button
            // This lets you test notice uploads without cluttering the main navigation bar!
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUploadScreen()),
                );
              },
              icon: const Icon(
                Icons.admin_panel_settings,
                color: Colors.redAccent,
              ),
              label: const Text(
                'Open Admin Notice Upload',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // THE LOGOUT BUTTON
            ElevatedButton.icon(
              onPressed: () async {
                // Signs out from Firebase -> AuthWrapper instantly kicks user back to LoginScreen
                await AuthService().signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Log Out', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
