// lib/features/ai_notice/notice_parser.dart

import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';

class NoticeParser {
  // Define the Gemini model configuration with strict schema enforcement
  final _model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash', // Stable, hackathon-friendly model
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json', // Forces Gemini to speak only valid JSON[cite: 1]
      responseSchema: Schema.object(
        properties: {
          'tag': Schema.enumString(enumValues: ['EXAM' , 'EVENTS' , 'CANCELLATION' , 'GENERAL'], ),
          'summary': Schema.string(
            description: 'One sentence, under 30 words, that a student can scan in 3 seconds.',
          ),
        },
        optionalProperties: ['tag', 'summary'],
      ),
    ),
    systemInstruction: Content.system(
      'You classify university notices for students. Read the title and description '
      'and return the single best tag plus a short punchy summary. '
      'EXAM = tests, quizzes, continuous assessments, exam schedule changes. '
      'EVENT = workshops, seminars, club activities, registration deadlines. '
      'CANCELLATION = a class, exam, or event being cancelled or postponed. '
      'GENERAL = anything else that does not fit the above categories.',
    ),
  );

  /// Receives notice text from the admin form, analyzes it with Gemini, 
  /// and returns a structured map containing 'tag' and 'summary'[cite: 1].
  Future<Map<String, dynamic>> analyzeNotice({
    required String title,
    required String description,
  }) async {
    try {
      // Send the text payload to Gemini
      final response = await _model.generateContent([
        Content.text('Title: $title\nDescription: $description'),
      ]);
      
      // Safeguard against null text responses
      if (response.text == null) {
        return {'tag': 'GENERAL', 'summary': title};
      }

      // Parse and return the pristine JSON structure directly
      return jsonDecode(response.text!) as Map<String, dynamic>;
    } catch (e) {
      // Universal Guardrail: Never let a network or API timeout crash the app demo[cite: 1]
      return {
        'tag': 'GENERAL', 
        'summary': title // Fallback to the original title if AI fails[cite: 1]
      };
    }
  }
}