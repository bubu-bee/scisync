import 'package:flutter/material.dart';
import '../firestore_data/user_service.dart'; // NEW: Import the backend we just made
import 'admin_notice_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _linkedInController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _linkedInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // 🧠 NEW: The StreamBuilder constantly listens to the database!
      body: StreamBuilder<DocumentSnapshot>(
        stream: UserService().getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("Profile data not found. Please log in again."),
            );
          }

          // Extract real data from Firestore
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String realName = userData['name'] ?? '';
          String realBatch = userData['badgeNumber'] ?? 'Unknown';
          String realLinkedIn = userData['linkedinUrl'] ?? '';
          String profileImageUrl = userData['profileImageUrl'] ?? '';
          bool isAdmin = userData['isAdmin'] ?? false;

          // Only populate the controllers if the user hasn't started typing yet
          if (_nameController.text.isEmpty && realName.isNotEmpty) {
            _nameController.text = realName;
          }
          if (_linkedInController.text.isEmpty && realLinkedIn.isNotEmpty) {
            _linkedInController.text = realLinkedIn;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- 1. PROFILE PICTURE ---
                GestureDetector(
                  onTap: () async {
                    // Triggers the camera roll and uploads instantly!
                    await UserService().uploadProfilePicture();
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.teal,
                        backgroundImage: profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl.isEmpty
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.teal,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- 2. EDITABLE NAME ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Full Name",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Enter your name",
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Colors.teal,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 3. PERMANENT BATCH BADGE ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Academic Batch (Read-Only)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school, color: Colors.black54),
                      const SizedBox(width: 12),
                      Text(
                        realBatch, // <--- INJECTED DIRECTLY FROM FIRESTORE
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- 4. LINKEDIN URL ---
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "LinkedIn Profile",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkedInController,
                  decoration: InputDecoration(
                    hintText: "Paste LinkedIn URL here",
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.link, color: Colors.teal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // --- 5. SAVE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Triggers the backend save function!
                      await UserService().updateProfileDetails(
                        _nameController.text.trim(),
                        _linkedInController.text.trim(),
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Profile details updated successfully!",
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save Profile Changes",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // --- 6. ADMIN & LOGOUT SECTION ---
                const Divider(),
                const SizedBox(height: 16),

                // Conditional Admin Button (Only shows if Firestore says they are an admin!)
                if (isAdmin)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUploadScreen(),
                        ),
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
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                ElevatedButton.icon(
                  onPressed: () async {
                    // Keep this commented out until the Auth flow is fully built
                    // await AuthService().signOut();
                    debugPrint("Log Out Clicked");
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
