import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NoticeParser {
  // Using the refined, strict-classifier model setup with an expanded schema
  // to support both text input and image OCR extraction.
  final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.1-flash-lite',
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
      responseSchema: Schema.object(
        properties: {
          'title': Schema.string(
            description: 'The extracted or provided title of the notice.',
          ),
          'description': Schema.string(
            description:
                'The full description, body, or extracted text of the notice.',
          ),
          'tag': Schema.enumString(
            enumValues: ['EXAM', 'CA', 'EVENT', 'CANCELLED', 'GENERAL'],
          ),
          'summary': Schema.string(
            description:
                'One sentence, under 15 words, that a student can scan in 3 seconds.',
          ),
          'affectedDate': Schema.string(
            description:
                'The date the event or cancellation takes place, formatted strictly as YYYY-MM-DD. If none applies, return empty string.',
          ),
          'affectedStartTime': Schema.string(
            description:
                'The start time of the lecture/exam being cancelled or held, formatted as HH:mm (24-hour format like 09:30 or 13:30). If none applies, return empty string.',
          ),
        },
      ),
    ),
    systemInstruction: Content.system(
      'You are a strict academic notice classifier, OCR parser, and date extractor. '
      '1. EXAM: High stakes tests, finals, mid-terms. '
      '2. CA: Continuous assessments, quizzes, assignments, lab reports. '
      '3. EVENT: Workshops, seminars, club activities, parties, registration. '
      '4. CANCELLED: Lecture or class cancellations, postponed classes, or venue changes. '
      '5. GENERAL: Announcements, library info, general campus updates. '
      'When given an image or text, extract or refine the title, description, tag, summary, '
      'affectedDate (YYYY-MM-DD), and affectedStartTime (HH:mm). '
      'Return ONLY valid JSON matching the schema. Do not include any other text.',
    ),
  );

  /// Analyzes a manually typed notice title and description
  Future<Map<String, dynamic>> analyzeNotice({
    required String title,
    required String description,
  }) async {
    try {
      debugPrint("🤖 [AI] Sending text notice to Gemini...");

      final prompt =
          'Classify this notice and extract date/time details.\n'
          'Title: $title\nDescription: $description';

      final response = await _model.generateContent([Content.text(prompt)]);

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

  /// Analyzes an uploaded poster or flyer image using Gemini Vision OCR
  Future<Map<String, dynamic>> analyzePoster(Uint8List imageBytes) async {
    try {
      debugPrint("🤖 [AI] Sending poster image to Gemini Vision...");

      final prompt = Content.multi([
        TextPart(
          'Analyze this campus poster or flyer image. Extract the title, full description text, '
          'classify the tag, write a 1-sentence summary, and extract the affectedDate and affectedStartTime.',
        ),
        InlineDataPart(
          'image/jpeg',
          imageBytes,
        ), // <--- Corrected to capital 'I'
      ]);

      final response = await _model.generateContent([prompt]);

      if (response.text == null) {
        debugPrint("⚠️ [AI] Poster response text is NULL");
        throw Exception("AI returned empty response for poster");
      }

      debugPrint("🤖 [AI] Poster Success! RAW: ${response.text}");
      return jsonDecode(response.text!) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      debugPrint("🔥 [AI POSTER ERROR] Caught exception: $e");
      debugPrint("🔥 [AI POSTER ERROR] Stack Trace: $stackTrace");
      rethrow;
    }
  }
}
