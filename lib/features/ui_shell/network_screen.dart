import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- 1. Import url_launcher

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  // Controller to read what the user is typing in the search box
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  // Helper method to safely launch URLs
  Future<void> _openLinkedIn(String urlString) async {
    try {
      // Ensure the URL has a proper scheme (e.g., https://)
      String formattedUrl = urlString.trim();
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
        formattedUrl = 'https://$formattedUrl';
      }

      final Uri url = Uri.parse(formattedUrl);

      // Launch external application (Browser or LinkedIn App)
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open LinkedIn link.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening link: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        // Dynamic Title: Turns into a TextField when searching!
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.teal, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'Search by name or batch...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
                },
              )
            : const Text(
                'Student Network',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 1,
        actions: [
          // Toggle Search Button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 28),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  // Closing search: Clear text and reset query
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  // Opening search
                  _isSearching = true;
                }
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      // Fetching Users from Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading network."));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_alt_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No students registered yet.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          // CLIENT-SIDE FILTERING: Filter users based on search query
          final filteredUsers = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final badge = (data['badgeNumber'] ?? '').toString().toLowerCase();

            // Check if name or badge matches what the user typed
            return name.contains(_searchQuery) || badge.contains(_searchQuery);
          }).toList();

          if (filteredUsers.isEmpty) {
            return const Center(
              child: Text(
                "No matching students found.",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              var userData =
                  filteredUsers[index].data() as Map<String, dynamic>;
              return _buildStudentCard(userData);
            },
          );
        },
      ),
    );
  }

  // The Student Card UI Widget
  Widget _buildStudentCard(Map<String, dynamic> data) {
    String name = data['name'] ?? 'Classmate';
    String badge = data['badgeNumber'] ?? 'Unknown Badge';
    String linkedin = data['linkedinUrl'] ?? '';
    String profileImageUrl =
        data['profileImageUrl'] ?? ''; // <--- Extracted profile image URL
    bool hasLinkedIn = linkedin.isNotEmpty;

    String initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- DYNAMIC AVATAR RENDERER ---
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.teal[50],
            backgroundImage: profileImageUrl.isNotEmpty
                ? NetworkImage(
                    profileImageUrl,
                  ) // Loads Cloudinary avatar if present
                : null,
            child: profileImageUrl.isEmpty
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge.toUpperCase(),
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (hasLinkedIn) {
                        _openLinkedIn(linkedin); // <--- Triggers URL launcher
                      }
                    },
                    icon: Icon(
                      Icons.work,
                      size: 16,
                      color: hasLinkedIn ? Colors.blue[700] : Colors.grey,
                    ),
                    label: Text(
                      hasLinkedIn ? "Connect" : "No Link",
                      style: TextStyle(
                        color: hasLinkedIn ? Colors.blue[700] : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: hasLinkedIn
                            ? Colors.blue[700]!
                            : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
