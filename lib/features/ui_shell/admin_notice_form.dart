import 'package:flutter/material.dart';
import '../firestore_data/notice_service.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  // 🧠 The "Brain" of the form: Controllers grab the exact text the admin types!
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Default value for the target batch dropdown
  String _selectedBatch = 'All Students';
  final List<String> _batches = [
    'All Students',
    '2022 Batch',
    '2023 Batch',
    '2024 Batch',
  ];

  @override
  void dispose() {
    // 🧹 Golden Rule: Always dispose controllers when leaving the screen to save RAM!
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Post New Notice',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // SingleChildScrollView prevents the screen from crashing when the keyboard pops up!
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. TITLE INPUT ---
            const Text(
              "Notice Title",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: "e.g., Data Structures Mid-Term",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- 2. DESCRIPTION INPUT ---
            const Text(
              "Description",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4, // Makes it a big, tall text box!
              decoration: InputDecoration(
                hintText: "Type the full event details here...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- 3. TARGET BATCH DROPDOWN ---
            const Text(
              "Target Batch",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedBatch,
                  isExpanded: true,
                  items: _batches.map((String batch) {
                    return DropdownMenuItem<String>(
                      value: batch,
                      child: Text(batch),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBatch =
                          newValue!; // Updates the UI instantly when changed
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- 4. IMAGE UPLOAD PLACEHOLDER ---
            const Text(
              "Attach Image (Optional)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                debugPrint(
                  "Open Image Gallery!",
                ); // Supun will add the camera code here!
              },
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  // Creates a dashed-looking or solid highlighted border
                  border: Border.all(color: Colors.teal.shade200, width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      color: Colors.teal,
                      size: 40,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Tap to upload photo",
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- 5. SUBMIT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                // We add 'async' because talking to the cloud takes a second
                onPressed: () async {
                  // 1. Basic Validation (Don't let them post empty notices!)
                  if (_titleController.text.isEmpty ||
                      _descriptionController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields!'),
                      ),
                    );
                    return;
                  }

                  try {
                    // 2. The Firebase Write Command
                    // Tell the Chef to save the data! The Chef handles the timestamp automatically.
                    await NoticeService().postNotice({
                      'title': _titleController.text,
                      'description': _descriptionController.text,
                      'targetBatch': _selectedBatch,
                      'tag': 'UPDATE',
                      'imageUrl': '',
                      'likes': 0, // NEW: Start likes at 0
                      'hearts': 0, // NEW: Start hearts at 0
                    });

                    // 4. Clear the text boxes so it's fresh for the next one
                    _titleController.clear();
                    _descriptionController.clear();

                    // 5. Show a success message and close the secret admin screen!
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notice Posted Successfully!'),
                        ),
                      );
                      Navigator.pop(
                        context,
                      ); // Takes you back to the Profile tab
                    }
                  } catch (e) {
                    debugPrint("Error saving to database: $e");
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
                  "Post Notice",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
