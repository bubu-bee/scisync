import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminScheduleManager extends StatefulWidget {
  const AdminScheduleManager({super.key});

  @override
  State<AdminScheduleManager> createState() => _AdminScheduleManagerState();
}

class _AdminScheduleManagerState extends State<AdminScheduleManager>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;

  // Global Context Variables
  String _selectedBatch = '23com'; // Default fallback
  bool _isLoadingBatch = true;

  final Map<String, String> _batchOptions = {
    '2023 COM Batch (23com)': '23com',
    '2022 COM Batch (22com)': '22com',
    '2024 COM Batch (24com)': '24com',
  };

  // --- MODE 1: DAILY EDITOR STATE ---
  DateTime _dailyTargetDate = DateTime.now();
  bool _isLoadingDay = false;
  List<Map<String, dynamic>> _dayClasses = [];

  // --- MODE 2: HOLIDAY STATE (Updated for Single Day & Range) ---
  bool _isHolidayRange = false;
  DateTime? _singleHolidayDate;
  DateTime? _holidayStart;
  DateTime? _holidayEnd;
  final TextEditingController _holidayMsgController = TextEditingController(
    text: "Happy Holidays & Study Leave!",
  );
  bool _isSavingHoliday = false;

  // --- MODE 3: EXAM SCHEDULER STATE ---
  DateTime? _examDate;
  final List<Map<String, TextEditingController>> _examRows = [];
  bool _isSavingExam = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAdminDefaultBatch();
  }

  // Fetch logged-in admin's batch from Firestore and set as default target batch
  Future<void> _fetchAdminDefaultBatch() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          String adminBatch =
              (userDoc.data() as Map<String, dynamic>)['batchId'] ?? '23com';
          if (_batchOptions.containsValue(adminBatch)) {
            setState(() {
              _selectedBatch = adminBatch;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching admin batch profile: $e");
    } finally {
      setState(() {
        _isLoadingBatch = false;
      });
      _loadDailySchedule();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _holidayMsgController.dispose();
    for (var row in _examRows) {
      row['subject']?.dispose();
      row['courseCode']?.dispose();
      row['startTime']?.dispose();
      row['endTime']?.dispose();
      row['venue']?.dispose();
    }
    super.dispose();
  }

  // ==========================================
  // MODE 1 LOGIC: PULL & EDIT DAILY TIMETABLE
  // ==========================================
  Future<void> _loadDailySchedule() async {
    setState(() => _isLoadingDay = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_dailyTargetDate);
      String dayName = _getDayNameFromInt(_dailyTargetDate.weekday);

      // Check if override already exists for this date and batch
      DocumentSnapshot overrideDoc = await _firestore
          .collection('schedule_overrides')
          .doc('${_selectedBatch}_$dateStr')
          .get();

      if (overrideDoc.exists && overrideDoc.data() != null) {
        var data = overrideDoc.data() as Map<String, dynamic>;
        setState(() {
          _dayClasses = List<Map<String, dynamic>>.from(data['classes'] ?? []);
        });
      } else {
        // Fall back to base_schedules template
        DocumentSnapshot baseDoc = await _firestore
            .collection('base_schedules')
            .doc(_selectedBatch)
            .get();

        if (baseDoc.exists && baseDoc.data() != null) {
          var baseData = baseDoc.data() as Map<String, dynamic>;
          List<dynamic> rawList = baseData[dayName] ?? [];
          setState(() {
            _dayClasses = rawList
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        } else {
          setState(() => _dayClasses = []);
        }
      }
    } catch (e) {
      debugPrint("Error loading schedule: $e");
    } finally {
      setState(() => _isLoadingDay = false);
    }
  }

  Future<void> _saveDailyOverrides() async {
    setState(() => _isLoadingDay = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_dailyTargetDate);

      await _firestore
          .collection('schedule_overrides')
          .doc('${_selectedBatch}_$dateStr')
          .set({
            'batchId': _selectedBatch,
            'date': dateStr,
            'isHoliday': false,
            'isExamDay': false,
            'classes': _dayClasses,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily Schedule Overrides Saved Successfully!'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving overrides: $e");
    } finally {
      setState(() => _isLoadingDay = false);
    }
  }

  Future<void> _resetDayToDefault() async {
    setState(() => _isLoadingDay = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_dailyTargetDate);
      await _firestore
          .collection('schedule_overrides')
          .doc('${_selectedBatch}_$dateStr')
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Date reset successfully to default base schedule!'),
          ),
        );
      }
      _loadDailySchedule();
    } catch (e) {
      debugPrint("Error resetting date: $e");
    } finally {
      setState(() => _isLoadingDay = false);
    }
  }

  // ==========================================
  // MODE 2 LOGIC: HOLIDAY (Single Day or Range)
  // ==========================================
  Future<void> _saveHoliday() async {
    if (!_isHolidayRange && _singleHolidayDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid holiday date!')),
      );
      return;
    }
    if (_isHolidayRange && (_holidayStart == null || _holidayEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid date range!')),
      );
      return;
    }

    setState(() => _isSavingHoliday = true);
    try {
      if (!_isHolidayRange && _singleHolidayDate != null) {
        String dateStr = DateFormat('yyyy-MM-dd').format(_singleHolidayDate!);
        await _firestore
            .collection('schedule_overrides')
            .doc('${_selectedBatch}_$dateStr')
            .set({
              'batchId': _selectedBatch,
              'date': dateStr,
              'isHoliday': true,
              'holidayMessage': _holidayMsgController.text.trim(),
              'isExamDay': false,
              'classes': [],
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } else if (_isHolidayRange &&
          _holidayStart != null &&
          _holidayEnd != null) {
        DateTime current = _holidayStart!;
        while (!current.isAfter(_holidayEnd!)) {
          String dateStr = DateFormat('yyyy-MM-dd').format(current);
          await _firestore
              .collection('schedule_overrides')
              .doc('${_selectedBatch}_$dateStr')
              .set({
                'batchId': _selectedBatch,
                'date': dateStr,
                'isHoliday': true,
                'holidayMessage': _holidayMsgController.text.trim(),
                'isExamDay': false,
                'classes': [],
                'updatedAt': FieldValue.serverTimestamp(),
              });
          current = current.add(const Duration(days: 1));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Holiday Successfully Applied!')),
        );
      }
    } catch (e) {
      debugPrint("Error saving holiday: $e");
    } finally {
      setState(() => _isSavingHoliday = false);
    }
  }

  // ==========================================
  // MODE 3 LOGIC: EXAM SCHEDULER
  // ==========================================
  void _addExamRow() {
    setState(() {
      _examRows.add({
        'subject': TextEditingController(),
        'courseCode': TextEditingController(),
        'startTime': TextEditingController(text: '09:00'),
        'endTime': TextEditingController(text: '12:00'),
        'venue': TextEditingController(),
      });
    });
  }

  Future<void> _saveExamSchedule() async {
    if (_examDate == null || _examRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an exam date and add at least one exam card!',
          ),
        ),
      );
      return;
    }

    setState(() => _isSavingExam = true);
    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(_examDate!);
      List<Map<String, dynamic>> examList = _examRows
          .map(
            (row) => {
              'subject': row['subject']!.text.trim(),
              'courseCode': row['courseCode']!.text.trim(),
              'startTime': row['startTime']!.text.trim(),
              'endTime': row['endTime']!.text.trim(),
              'venue': row['venue']!.text.trim(),
            },
          )
          .toList();

      await _firestore
          .collection('schedule_overrides')
          .doc('${_selectedBatch}_$dateStr')
          .set({
            'batchId': _selectedBatch,
            'date': dateStr,
            'isHoliday': false,
            'isExamDay': true,
            'exams': examList,
            'classes': [],
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam Schedule Published Successfully!'),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving exams: $e");
    } finally {
      setState(() => _isSavingExam = false);
    }
  }

  String _getDayNameFromInt(int day) {
    switch (day) {
      case 1:
        return 'monday';
      case 2:
        return 'tuesday';
      case 3:
        return 'wednesday';
      case 4:
        return 'thursday';
      case 5:
        return 'friday';
      case 6:
        return 'saturday';
      case 7:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  // ==========================================
  // UI BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Schedule Operations Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.edit_calendar), text: "Daily Edits"),
            Tab(icon: Icon(Icons.beach_access), text: "Holidays"),
            Tab(icon: Icon(Icons.assignment_turned_in), text: "Exams"),
          ],
        ),
      ),
      body: _isLoadingBatch
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                // Global Batch Selector Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.teal.shade50,
                  child: Row(
                    children: [
                      const Text(
                        "Target Batch: ",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBatch,
                              items: _batchOptions.entries.map((e) {
                                return DropdownMenuItem(
                                  value: e.value,
                                  child: Text(e.key),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedBatch = val!);
                                _loadDailySchedule();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDailyEditorTab(),
                      _buildHolidayTab(),
                      _buildExamTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- TAB 1: DAILY EDITOR UI ---
  Widget _buildDailyEditorTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _dailyTargetDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => _dailyTargetDate = picked);
                      _loadDailySchedule();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    "Date: ${DateFormat('yyyy-MM-dd').format(_dailyTargetDate)}",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _dayClasses.add({
                      'subject': 'New Lecture',
                      'courseCode': 'CO0000',
                      'startTime': '08:30',
                      'endTime': '10:30',
                      'isCancelled': false,
                      'caBadge': '',
                    });
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text("Add Slot"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoadingDay
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _dayClasses.isEmpty
                ? const Center(child: Text("No lectures found for this date."))
                : ListView.builder(
                    itemCount: _dayClasses.length,
                    itemBuilder: (context, index) {
                      var lecture = _dayClasses[index];
                      bool isCancelled = lecture['isCancelled'] ?? false;
                      String caBadge = lecture['caBadge'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: lecture['subject'],
                                      ),
                                      onChanged: (val) =>
                                          lecture['subject'] = val,
                                      decoration: const InputDecoration(
                                        labelText: "Subject Name",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: lecture['courseCode'],
                                      ),
                                      onChanged: (val) =>
                                          lecture['courseCode'] = val,
                                      decoration: const InputDecoration(
                                        labelText: "Code",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: lecture['startTime'],
                                      ),
                                      onChanged: (val) =>
                                          lecture['startTime'] = val,
                                      decoration: const InputDecoration(
                                        labelText: "Start (HH:mm)",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: lecture['endTime'],
                                      ),
                                      onChanged: (val) =>
                                          lecture['endTime'] = val,
                                      decoration: const InputDecoration(
                                        labelText: "End (HH:mm)",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: TextEditingController(
                                        text: caBadge,
                                      ),
                                      onChanged: (val) =>
                                          lecture['caBadge'] = val,
                                      decoration: const InputDecoration(
                                        labelText: "CA Badge (e.g. CA 2)",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: isCancelled,
                                        onChanged: (val) {
                                          setState(
                                            () => lecture['isCancelled'] =
                                                val ?? false,
                                          );
                                        },
                                      ),
                                      const Text(
                                        "Cancel Lecture",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _dayClasses.removeAt(index),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // Actions Row: Save Overrides vs Reset to Default
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoadingDay ? null : _saveDailyOverrides,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      "Save Overrides",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isLoadingDay ? null : _resetDayToDefault,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text(
                      "Reset to Default",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 2: HOLIDAY UI (Supports Single Day & Date Range) ---
  Widget _buildHolidayTab() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Holiday / Study Leave Setup",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: const Text("Single Day"),
                selected: !_isHolidayRange,
                onSelected: (val) => setState(() => _isHolidayRange = false),
                selectedColor: Colors.teal.shade100,
              ),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text("Date Range"),
                selected: _isHolidayRange,
                onSelected: (val) => setState(() => _isHolidayRange = true),
                selectedColor: Colors.teal.shade100,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              if (!_isHolidayRange) {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _singleHolidayDate = picked);
              } else {
                DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _holidayStart = picked.start;
                    _holidayEnd = picked.end;
                  });
                }
              }
            },
            icon: const Icon(Icons.date_range),
            label: Text(
              !_isHolidayRange
                  ? (_singleHolidayDate == null
                        ? "Pick Single Date"
                        : DateFormat('yyyy-MM-dd').format(_singleHolidayDate!))
                  : (_holidayStart == null
                        ? "Pick Date Range"
                        : "${DateFormat('yyyy-MM-dd').format(_holidayStart!)} to ${DateFormat('yyyy-MM-dd').format(_holidayEnd!)}"),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Custom Banner Message",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _holidayMsgController,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              hintText: "e.g., Public Holiday / Study Leave",
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSavingHoliday ? null : _saveHoliday,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              child: _isSavingHoliday
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Apply Holiday",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: EXAM SCHEDULER UI ---
  Widget _buildExamTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _examDate = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    _examDate == null
                        ? "Select Exam Date"
                        : "Date: ${DateFormat('yyyy-MM-dd').format(_examDate!)}",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addExamRow,
                icon: const Icon(Icons.add),
                label: const Text("Add Exam"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _examRows.isEmpty
                ? const Center(
                    child: Text("No exams added yet. Click 'Add Exam' above."),
                  )
                : ListView.builder(
                    itemCount: _examRows.length,
                    itemBuilder: (context, index) {
                      var row = _examRows[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: row['subject'],
                                      decoration: const InputDecoration(
                                        labelText: "Exam Name",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 100,
                                    child: TextField(
                                      controller: row['courseCode'],
                                      decoration: const InputDecoration(
                                        labelText: "Code",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: row['startTime'],
                                      decoration: const InputDecoration(
                                        labelText: "Start Time",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: row['endTime'],
                                      decoration: const InputDecoration(
                                        labelText: "End Time",
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: row['venue'],
                                      decoration: const InputDecoration(
                                        labelText: "Venue",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      setState(() => _examRows.removeAt(index)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSavingExam ? null : _saveExamSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "Publish Exam Schedule for Date",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
