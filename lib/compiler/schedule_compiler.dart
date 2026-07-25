
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

  factory ScheduleItem.fromMap(String id, Map<String, dynamic> map) {
    return ScheduleItem(
      id: id,
      title: map['title'] ?? 'No Title',
      location: map['location'] ?? 'Online / TBD',
      
      startTime: DateTime.parse(map['startTime'] ?? DateTime.now().toIso8601String()),
      endTime: DateTime.parse(map['endTime'] ?? DateTime.now().toIso8601String()),
      lecturer: map['lecturer'] ?? 'Unknown',
    );
  }

  
  String toTextSummary() {
    return "- $title with $lecturer at $location. From ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} to ${endTime.hour}:${endTime.minute.toString().padLeft(2, '0')}";
  }
}


class ScheduleCompiler {
  
  
  List<ScheduleItem> compileRawData(List<Map<String, dynamic>> rawDocuments) {
    List<ScheduleItem> compiledList = [];
    
    for (var doc in rawDocuments) {
      String docId = doc['id'] ?? '';
      compiledList.add(ScheduleItem.fromMap(docId, doc));
    }

    
    compiledList.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    return compiledList;
  }

 
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
