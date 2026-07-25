import 'dart:convert';

/// කාලසටහනක අඩංගු වන එක් එක් විෂය/දේශන වාරය (Lecture slot) නිරූපණය කරන class එක.
class ScheduleItem {
  final String id;
  final String title;
  final String location;
  final DateTime startTime;
  final DateTime endTime;
  final String lecturer;

  ScheduleItem({
    required this.id,
    required this.title,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.lecturer,
  });

  /// Map (JSON) දත්ත වලින් ScheduleItem object එකක් සාදා ගැනීම.
  factory ScheduleItem.fromMap(String id, Map<String, dynamic> map) {
    return ScheduleItem(
      id: id,
      title: map['title'] ?? 'No Title',
      location: map['location'] ?? 'Online / TBD',
      // ISO String එකක් ලෙස ලැබෙන වෙලාව Dart DateTime එකක් බවට පත් කිරීම
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['endTime'] ?? DateTime.now().toIso8601String()),
      lecturer: map['lecturer'] ?? 'Unknown',
    );
  }

  /// AI Chatbot එකට කියවීමට පහසු වන පරිදි Text එකක් බවට පත් කිරීම (Prompt Stuffing සඳහා).
  String toTextSummary() {
    return "- $title with $lecturer at $location. From ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} to ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}";
  }
}

/// මුළු කාලසටහනම කළමනාකරණය කරන Compiler Class එක.
class ScheduleCompiler {
  
  /// Team Lead ගේ Stream එකෙන් ලැබෙන Raw Firestore List එක සාමාන්‍ය ScheduleItem List එකක් බවට පත් කිරීම.
  List<ScheduleItem> compileRawData(List<Map<String, dynamic>> rawDocuments) {
    List<ScheduleItem> compiledList = [];
    
    for (var doc in rawDocuments) {
      // සාමාන්‍යයෙන් Firestore doc එකක ID එක 'id' ලෙස පවතින බව සලකා
      String docId = doc['id'] ?? '';
      compiledList.add(ScheduleItem.fromMap(docId, doc));
    }

    // වෙලාව අනුව කාලසටහන පිළිවෙළකට සකස් කිරීම (Sort කිරීම)
    compiledList.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    return compiledList;
  }

  /// මුළු කාලසටහනම තනි String එකක් බවට පත් කරන ශ්‍රිතය (Function).
  /// මෙයින් ලැබෙන String එක අපිට SciBot එකේ `systemInstruction` එකට කෙලින්ම දෙන්න පුළුවන්.
  String generateSystemInstruction(List<ScheduleItem> items) {
    if (items.isEmpty) {
      return "The student currently has no classes scheduled.";
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln("You are SciBot, an intelligent academic schedule assistant.");
    buffer.writeln("Here is the student's current schedule. Use this data strictly to answer their questions:\n");

    for (var item in items) {
      buffer.writeln(item.toTextSummary());
    }

    buffer.writeln("\nIf the student asks about a time with no classes, tell them they are free.");
    return buffer.toString();
  }
}