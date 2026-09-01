import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NoticeParser {
  // Using the refined, strict-classifier model setup
  final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.1-flash-lite',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'tag': Schema.enumString(
            enumValues: ['EXAM', 'CA', 'EVENT', 'CANCELLED', 'GENERAL'],
          ),
          'summary': Schema.string(
            description:
                'One sentence, under 15 words, that a student can scan in 3 seconds.',
          ),
          // NEW: Required so the schedule engine knows what date to target!
          'affectedDate': Schema.string(
            description:
                'The date the event or cancellation takes place, formatted strictly as YYYY-MM-DD. If none applies, return empty string.',
          ),
          // NEW: Required so the schedule engine knows which lecture slot to remove or add!
          'affectedStartTime': Schema.string(
            description:
                'The start time of the lecture/exam being cancelled or held, formatted as HH:mm (24-hour format like 09:30 or 13:30). If none applies, return empty string.',
          ),
        },
      ),
    ),
    systemInstruction: Content.system(
      'You are a strict academic notice classifier and date extractor. '
      '1. EXAM: High stakes tests, finals, mid-terms. '
      '2. CA: Continuous assessments, quizzes, assignments, lab reports. '
      '3. EVENT: Workshops, seminars, club activities, parties, registration. '
      '4. CANCELLED: Lecture or class cancellations, postponed classes, or venue changes. '
      '5. GENERAL: Announcements, library info, general campus updates. '
      'You must also extract the affectedDate (YYYY-MM-DD) and affectedStartTime (HH:mm) if mentioned in the notice text. '
      'Return ONLY valid JSON matching the schema. Do not include any other text.',
    ),
  );

  Future<Map<String, dynamic>> analyzeNotice({
    required String title,
    required String description,
  }) async {
    try {
      debugPrint("🤖 [AI] Sending to Gemini...");

      final prompt =
          'Classify this notice and extract date/time details.\n'
          'Title: $title\nDescription: $description';

      final response = await _model.generateContent([Content.text(prompt)]);

      // Check if response exists and is usable
      if (response.text == null) {
        debugPrint("⚠️ [AI] Response text is NULL");
        throw Exception("AI returned empty response");
      }

      debugPrint("🤖 [AI] Success! RAW: ${response.text}");
      return jsonDecode(response.text!) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint("🔥 [AI ERROR] Caught exception: $e");
      debugPrint("🔥 [AI ERROR] Stack Trace: $stackTrace");
      rethrow;
    }
  }
}
