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
            enumValues: ['EXAM', 'CA', 'EVENT', 'GENERAL'],
          ),
          'summary': Schema.string(
            description:
                'One sentence, under 15 words, that a student can scan in 3 seconds.',
          ),
        },
        // We force these two to always be present so the UI doesn't crash
      ),
    ),
    systemInstruction: Content.system(
      'You are a strict academic notice classifier. '
      '1. EXAM: High stakes tests, finals, mid-terms. '
      '2. CA: Continuous assessments, quizzes, assignments, lab reports. '
      '3. EVENT: Workshops, seminars, club activities, parties, registration. '
      '4. GENERAL: Announcements, library info, general campus updates. '
      'Return ONLY valid JSON. Do not include any other text.',
    ),
  );

  Future<Map<String, dynamic>> analyzeNotice({
    required String title,
    required String description,
  }) async {
    try {
      debugPrint("🤖 [AI] Sending to Gemini...");

      final prompt =
          'Classify this notice. Tag: EXAM, CA, EVENT, or GENERAL. Summary: 15 words.\n'
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
      // THIS IS THE MOST IMPORTANT CHANGE:
      // Instead of hiding the error, we print the FULL stack trace.
      debugPrint("🔥 [AI ERROR] Caught exception: $e");
      debugPrint("🔥 [AI ERROR] Stack Trace: $stackTrace");

      // We re-throw so we know it failed, instead of silently returning 'GENERAL'
      rethrow;
    }
  }
}
