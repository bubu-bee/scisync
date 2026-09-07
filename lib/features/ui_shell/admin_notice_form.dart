import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import '../firestore_data/notice_service.dart';
import '../firestore_data/cloudinary_service.dart';
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

  // --- IMAGE UPLOAD STATE VARIABLES ---
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  // Mapped batch options updated to match NoticeService's expected values exactly
  final Map<String, String> _batchOptions = {
    'All Students': 'All Students',
    '2022 COM Batch (22com)': '22com',
    '2023 COM Batch (23com)': '23com',
    '2024 COM Batch (24com)': '24com',
  };

  // Default fallback, will be overwritten by admin's profile batch on load
  String _selectedBatchKey = '23com';
  bool _isSubmitting = false;
  bool _isLoadingBatch = true;

  @override
  void initState() {
    super.initState();
    _fetchAdminDefaultBatch();
  }

  // Fetch the logged-in admin's batch from Firestore and set as default
  Future<void> _fetchAdminDefaultBatch() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          String adminBatch =
              (userDoc.data() as Map<String, dynamic>)['batchId'] ?? '23com';

          // Match the fetched batch string (e.g. '23com') with our options map value
          String matchingKey = _batchOptions.entries
              .firstWhere(
                (entry) => entry.value == adminBatch,
                orElse: () => const MapEntry('2023 COM Batch (23com)', '23com'),
              )
              .value;

          setState(() {
            _selectedBatchKey = matchingKey;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching admin batch profile: $e");
    } finally {
      setState(() {
        _isLoadingBatch = false;
      });
    }
  }

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

  // --- CLOUDINARY IMAGE PICK & UPLOAD HANDLER ---
  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploadingImage = true);
    try {
      String? url = await CloudinaryService.uploadImage();
      if (url != null) {
        setState(() {
          _uploadedImageUrl = url;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Poster image uploaded successfully!'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // --- AI OCR POSTER SCANNER HANDLER ---
  Future<void> _scanPosterWithAI() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.teal),
              SizedBox(width: 20),
              Text("Gemini is scanning your poster..."),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Read bytes for Gemini Vision OCR analysis
      Uint8List imageBytes = await image.readAsBytes();
      Map<String, dynamic> parsedData = await NoticeParser().analyzePoster(
        imageBytes,
      );

      // 2. Upload image to Cloudinary so it attaches to the notice
      final cloudinary = CloudinaryPublic(
        CloudinaryService.cloudName,
        CloudinaryService.uploadPreset,
        cache: false,
      );

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder: 'scisync_uploads',
        ),
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // 3. Auto-populate form controllers with AI-extracted data
        setState(() {
          if (parsedData['title'] != null &&
              (parsedData['title'] as String).isNotEmpty) {
            _titleController.text = parsedData['title'];
          }
          if (parsedData['description'] != null &&
              (parsedData['description'] as String).isNotEmpty) {
            _descriptionController.text = parsedData['description'];
          }
          if (parsedData['affectedDate'] != null &&
              (parsedData['affectedDate'] as String).isNotEmpty) {
            _dateController.text = parsedData['affectedDate'];
          }
          if (parsedData['affectedStartTime'] != null &&
              (parsedData['affectedStartTime'] as String).isNotEmpty) {
            _timeController.text = parsedData['affectedStartTime'];
          }
          if (response.secureUrl.isNotEmpty) {
            _uploadedImageUrl = response.secureUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poster successfully scanned & form auto-filled!'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error scanning poster: $e");
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to scan poster: $e')));
      }
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

      // 4. Save to Firebase Firestore with proper batch key, uploaded image URL, and server timestamp
      await NoticeService().postNotice({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'targetBatch': _selectedBatchKey, // Defaults to admin's batch
        'tag': aiResult['tag'] ?? 'GENERAL',
        'summary': aiResult['summary'] ?? '',
        'affectedDate': finalDate,
        'affectedStartTime': finalTime,
        'imageUrl': _uploadedImageUrl ?? '',
        'likes': 0,
        'hearts': 0,
        'timestamp': FieldValue.serverTimestamp(),
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
      body: _isLoadingBatch
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- GEMINI AI SCANNER BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _scanPosterWithAI,
                      icon: const Icon(Icons.auto_awesome, color: Colors.white),
                      label: const Text(
                        "Scan Poster with Gemini AI",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

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

                  // --- ATTACH IMAGE / POSTER SECTION ---
                  const Text(
                    "Attach Poster / Image (Optional)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isUploadingImage ? null : _pickAndUploadImage,
                    child: Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: _isUploadingImage
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.teal,
                              ),
                            )
                          : _uploadedImageUrl != null &&
                                _uploadedImageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    _uploadedImageUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.black54,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        onPressed: () => setState(
                                          () => _uploadedImageUrl = null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 48,
                                  color: Colors.teal,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Tap to upload poster or image",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
                            value: entry.value,
                            child: Text(entry.key),
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
