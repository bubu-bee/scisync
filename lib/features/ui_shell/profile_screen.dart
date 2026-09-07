import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firestore_data/user_service.dart';
import '../firestore_data/cloudinary_service.dart';
import 'admin_notice_form.dart';
import 'admin_schedule_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _linkedInController = TextEditingController();
  bool _isUploadingAvatar = false;
  bool _isLoggingOut = false;

  @override
  void dispose() {
    _nameController.dispose();
    _linkedInController.dispose();
    super.dispose();
  }

  // --- UPLOAD & UPDATE PROFILE PICTURE VIA CLOUDINARY ---
  Future<void> _updateProfilePicture() async {
    setState(() => _isUploadingAvatar = true);
    try {
      String? imageUrl = await CloudinaryService.uploadImage();
      if (imageUrl == null) {
        setState(() => _isUploadingAvatar = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profileImageUrl': imageUrl});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating profile picture: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  // --- FIXED LOGOUT HANDLER (POPS NAVIGATION FIRST, THEN SIGNS OUT) ---
  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    try {
      // 1. Pop the profile screen FIRST so the StreamBuilder unmounts cleanly
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

      // 2. THEN sign out from Firebase safely in the background
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Error logging out: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
        setState(() => _isLoggingOut = false);
      }
    }
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

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String realName = userData['name'] ?? '';
          String realBatch = userData['badgeNumber'] ?? 'Unknown';
          String realLinkedIn = userData['linkedinUrl'] ?? '';
          String profileImageUrl = userData['profileImageUrl'] ?? '';
          bool isAdmin = userData['isAdmin'] ?? false;

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
                // --- 1. PROFILE PICTURE WITH CLOUDINARY UPLOAD ---
                GestureDetector(
                  onTap: _isUploadingAvatar ? null : _updateProfilePicture,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.teal,
                        backgroundImage: profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: _isUploadingAvatar
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : (profileImageUrl.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                  : null),
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
                        realBatch,
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

                if (isAdmin)
                  Column(
                    children: [
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
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminScheduleManager(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.edit_calendar,
                          color: Colors.teal,
                        ),
                        label: const Text(
                          'Schedule Operations Manager',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.teal,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // --- WORKING LOGOUT BUTTON ---
                ElevatedButton.icon(
                  onPressed: _isLoggingOut ? null : _handleLogout,
                  icon: _isLoggingOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.logout),
                  label: Text(
                    _isLoggingOut ? 'Logging Out...' : 'Log Out',
                    style: const TextStyle(fontSize: 16),
                  ),
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
