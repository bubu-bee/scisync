import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 1. CRITICAL FOR TIMESTAMP!
import '../firestore_data/notice_service.dart';
import '../ai_notice/notice_parser.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Controllers for precise schedule modifications
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  // 2. Mapped batch options to match system keys ('all', '23com', etc.)
  final Map<String, String> _batchOptions = {
    'All Students': 'all',
    '2022 COM Batch (22com)': '22com',
    '2023 COM Batch (23com)': '23com',
    '2024 COM Batch (24com)': '24com',
  };
  String _selectedBatchKey = 'all';

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // --- NATIVE CALENDAR PICKER ---
  Future<void> _selectDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _dateController.text =
            "${pickedDate.year.toString().padLeft(4, '0')}-"
            "${pickedDate.month.toString().padLeft(2, '0')}-"
            "${pickedDate.day.toString().padLeft(2, '0')}";
      });
    }
  }

  // --- NATIVE TIME PICKER ---
  Future<void> _selectTime(BuildContext context) async {
    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.teal),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      final hours = pickedTime.hour.toString().padLeft(2, '0');
      final minutes = pickedTime.minute.toString().padLeft(2, '0');
      setState(() {
        _timeController.text = "$hours:$minutes";
      });
    }
  }

  // --- SUBMIT & AI PROCESSING LOGIC ---
  Future<void> _submitNotice() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in the title and description!'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Grab manual picker selections
      String manualDate = _dateController.text.trim();
      String manualTime = _timeController.text.trim();

      // 2. Feed description AND picker context directly into Gemini
      final aiResult = await NoticeParser().analyzeNotice(
        title: _titleController.text,
        description:
            "${_descriptionController.text} (Context - Affected Date: $manualDate, Time: $manualTime)",
      );

      // 3. Prioritize manual picker values, fallback to AI extraction if blank
      String finalDate = manualDate.isNotEmpty
          ? manualDate
          : (aiResult['affectedDate'] ?? '');

      String finalTime = manualTime.isNotEmpty
          ? manualTime
          : (aiResult['affectedStartTime'] ?? '');

      // 4. Save to Firebase Firestore with proper batch key and server timestamp
      await NoticeService().postNotice({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'targetBatch':
            _selectedBatchKey, // Saves '23com', 'all', etc. accurately!
        'tag': aiResult['tag'] ?? 'GENERAL',
        'summary': aiResult['summary'] ?? '',
        'affectedDate': finalDate,
        'affectedStartTime': finalTime,
        'imageUrl': '',
        'likes': 0,
        'hearts': 0,
        'timestamp':
            FieldValue.serverTimestamp(), // Fixes feed sorting instantly!
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice Posted & Processed Successfully!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error saving notice: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Notice Title",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: "e.g., Data Structures Lecture Cancelled",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Description",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Type full details...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- CLICKABLE DATE & TIME PICKER FIELDS ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Affected Date",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: () => _selectDate(context),
                        decoration: InputDecoration(
                          hintText: "Select Date",
                          suffixIcon: const Icon(
                            Icons.calendar_today,
                            color: Colors.teal,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Start Time",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _timeController,
                        readOnly: true,
                        onTap: () => _selectTime(context),
                        decoration: InputDecoration(
                          hintText: "Select Time",
                          suffixIcon: const Icon(
                            Icons.access_time,
                            color: Colors.teal,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

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
                  value: _selectedBatchKey,
                  isExpanded: true,
                  items: _batchOptions.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.value, // Saves '23com', 'all', etc.
                      child: Text(
                        entry.key,
                      ), // Displays readable text like '2023 COM Batch (23com)'
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBatchKey = newValue!;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text(
                        "Post Notice & Update Schedules",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
