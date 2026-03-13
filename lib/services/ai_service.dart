import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  // ─── Groq API (FREE — 14,400 requests/day, no credit card) ─────
  // Get a free key from: https://console.groq.com/keys
  static final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';
  static const String _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';

  final List<Map<String, dynamic>> _chatHistory = [];
  String _systemPrompt = '';

  /// Initialize the AI with patient's medicine context
  void initialize({List<Medicine> medicines = const []}) {
    _chatHistory.clear();

    final medicineContext = medicines.isEmpty
        ? 'The patient has no medicines added yet.'
        : 'The patient is currently taking:\n${medicines.map((m) => '  • ${m.name} (${m.dosage}) — ${m.frequency}, ${m.foodInstruction} food, times: ${m.times.join(", ")}').join('\n')}';

    _systemPrompt = '''
You are MediBot, a smart AI assistant inside the MediTrack app. You are friendly, knowledgeable, and helpful.

YOU CAN DISCUSS ANY TOPIC — health, fitness, nutrition, mental wellness, general knowledge, lifestyle, and more. You are NOT restricted to medication-only topics.

SAFETY (ALWAYS FOLLOW):
- For medical emergencies (chest pain, difficulty breathing, severe bleeding, allergic reactions): respond immediately — "This sounds like a medical emergency. Please call emergency services or go to the nearest hospital immediately."
- Never prescribe or modify any medication. Suggest consulting a doctor for prescriptions.
- Never diagnose a condition. You can discuss symptoms and suggest seeing a doctor.

WHEN DISCUSSING HEALTH & MEDICINES:
- You have access to the patient's medication profile below — use it to give personalised advice.
- Explain medicines in simple language, cover side effects, food interactions, and timing.
- Cross-reference symptoms against current medicines to flag possible side effects.
- Help plan meals around medicine schedules.
- Give adherence tips and motivational support.
- You can recommend OTC categories (e.g., "an antacid may help") without naming specific brands.

RESPONSE STYLE:
- Be warm, professional, and concise.
- Use **bold** for key terms and medicine names.
- Use numbered or bulleted lists for clarity.
- Keep responses under 250 words unless the user asks for detail.
- Do NOT use emojis.

PATIENT MEDICATION PROFILE:
$medicineContext
''';

    debugPrint('AI Service initialized with ${medicines.length} medicines context');
  }

  /// Send a message with an image (Vision API)
  Future<String> sendMessageWithImage(String message, String base64Image) async {
    if (_systemPrompt.isEmpty) initialize();

    // Vision request payload
    final userMessage = {
      'role': 'user',
      'content': [
        {'type': 'text', 'text': message},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
        }
      ]
    };

    // Add to local history (simplified for text-only history display,
    // as we don't want to store huge base64 strings in history for future context usually,
    // or we store it but Groq might have limits. For now, let's try to append acts like a normal message)
    _chatHistory.add({
      'role': 'user',
      'content': '$message [Image Attached]' // Store text representation in history context to save tokens/space
    });

    try {
      const visionSystemPrompt =
          'You are a medical image analysis assistant. Your job is to carefully examine '
          'medical images including prescriptions, medicine labels, lab reports, and health documents. '
          'Always provide detailed, clear, and helpful analysis. '
          'For prescriptions: list all medicines, dosages, and instructions. '
          'For medicine labels: identify the drug, dosage, side effects, and warnings. '
          'For lab reports: explain key values and whether they are normal or abnormal. '
          'Always recommend consulting a doctor for medical decisions. '
          'Be thorough, accurate, and patient-friendly in your response.';

      final messages = [
        {'role': 'system', 'content': visionSystemPrompt},
        userMessage, // The actual vision request with image
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _visionModel, // Use vision model
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final aiResponse = data['choices'][0]['message']['content'] as String;
        _chatHistory.add({'role': 'assistant', 'content': aiResponse});
        return aiResponse;
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
        debugPrint('Groq Vision API error ${response.statusCode}: $errorMsg');
        return 'AI Vision Error: $errorMsg';
      }
    } catch (e) {
      debugPrint('AI Vision Service error: $e');
      return 'Failed to analyze image. Please try again.';
    }
  }

  /// Send a text message and get AI response via Groq API
  Future<String> sendMessage(String message) async {
    if (_systemPrompt.isEmpty) {
      initialize();
    }

    _chatHistory.add({'role': 'user', 'content': message});

    // Keep last 10 messages for context
    if (_chatHistory.length > 10) {
      _chatHistory.removeRange(0, _chatHistory.length - 10);
    }

    try {
      final messages = [
        {'role': 'system', 'content': _systemPrompt},
        ..._chatHistory,
      ];

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;
        _chatHistory.add({'role': 'assistant', 'content': aiResponse});
        return aiResponse;
      } else if (response.statusCode == 401) {
        return '[!] **API Key Required**\n\n'
            'To use MediBot AI, get a free Groq API key:\n\n'
            '1. Go to **console.groq.com/keys**\n'
            '2. Sign up (free, no credit card)\n'
            '3. Create an API key\n\n'
            'Free tier: **14,400 requests/day**';
      } else {
        final errorBody = jsonDecode(response.body);
        final errorMsg = errorBody['error']?['message'] ?? 'Unknown error';
        debugPrint('Groq API error ${response.statusCode}: $errorMsg');
        return 'AI Error: $errorMsg';
      }
    } catch (e) {
      debugPrint('AI Service error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection')) {
        return '**No Internet Connection**\n\nPlease check your internet and try again.';
      }
      return 'Something went wrong. Please try again.';
    }
  }

  /// Get food advice for a specific medicine
  Future<String> getFoodAdvice(Medicine medicine) async {
    return sendMessage(
      'Give me detailed food advice for taking ${medicine.name} (${medicine.dosage}). '
      'It should be taken ${medicine.foodInstruction} food. '
      'What foods should I eat or avoid? What timing is best?',
    );
  }

  /// Explain a medicine in simple terms
  Future<String> explainMedicine(Medicine medicine) async {
    return sendMessage(
      'Explain ${medicine.name} (${medicine.dosage}) in simple language. '
      'What is it for? Common side effects? Important precautions?',
    );
  }

  /// Check drug interactions
  Future<String> checkInteractions(List<Medicine> medicines) async {
    if (medicines.length < 2) {
      return 'You need at least 2 medicines to check for interactions.';
    }
    final names = medicines.map((m) => m.name).join(', ');
    return sendMessage(
      'Are there any known drug interactions between these medicines I am taking: $names? '
      'Give me general awareness information about potential interactions.',
    );
  }

  /// Get adherence tips
  Future<String> getAdherenceTips() async {
    return sendMessage(
      'Give me practical tips to remember and take my medicines on time every day. '
      'Include tips about building habits and using reminders effectively.',
    );
  }

  /// Get side effects info
  Future<String> getSideEffects(Medicine medicine) async {
    return sendMessage(
      'What are the common side effects of ${medicine.name}? '
      'When should I be concerned and contact my doctor about side effects?',
    );
  }

  /// Reset chat
  void resetChat({List<Medicine> medicines = const []}) {
    initialize(medicines: medicines);
  }

  // ─── NEW: Symptom Checker ─────────────────────────────────────────

  /// Cross-reference symptoms against the patient's current medicines
  Future<String> checkSymptoms(String symptoms, List<Medicine> medicines) async {
    final medNames = medicines.map((m) => '${m.name} (${m.dosage})').join(', ');
    return sendMessage(
      'SYMPTOM CHECK REQUEST:\n'
      'I am experiencing these symptoms: $symptoms\n\n'
      'My current medicines: $medNames\n\n'
      'Please analyze: Could any of my current medicines be causing these symptoms? '
      'For each medicine, tell me if the symptom is a known side effect. '
      'Rate the concern level (Low / Medium / High). '
      'Tell me if I should contact my doctor urgently.',
    );
  }

  // ─── NEW: Smart Dose Rescheduler ──────────────────────────────────

  /// Generate a revised dose schedule when user missed a dose or woke late
  Future<String> rescheduleDoses({
    required List<Medicine> medicines,
    required String situation,
    required Map<String, bool> takenToday,
  }) async {
    final now = DateTime.now();
    final currentTime = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    final scheduleLines = StringBuffer();
    for (final med in medicines) {
      if (!med.isActive) continue;
      for (final time in med.times) {
        final key = '${med.id}_$time';
        final taken = takenToday[key] ?? false;
        scheduleLines.writeln(
          '  - ${med.name} (${med.dosage}) at $time — ${taken ? "TAKEN" : "NOT YET TAKEN"} '
          '[${med.foodInstruction} food]',
        );
      }
    }

    return sendMessage(
      'DOSE RESCHEDULE REQUEST:\n'
      'Current time: $currentTime\n'
      'Situation: $situation\n\n'
      'My full schedule today:\n$scheduleLines\n'
      'Based on what I\'ve taken and missed, create a revised schedule for the rest of today. '
      'For each remaining dose, tell me the best adjusted time and any spacing rules to follow. '
      'Format as a clear timeline.',
    );
  }

  // ─── NEW: Medicine-Meal Planner ───────────────────────────────────

  /// Generate a full-day meal plan around medicine schedule
  Future<String> generateMealPlan(List<Medicine> medicines) async {
    final scheduleLines = medicines
        .where((m) => m.isActive)
        .map((m) => '  - ${m.name} (${m.dosage}) at ${m.times.join(", ")} '
            '[${m.foodInstruction} food]')
        .join('\n');

    return sendMessage(
      'MEAL PLAN REQUEST:\n'
      'Generate a full-day meal timeline around my medicine schedule:\n'
      '$scheduleLines\n\n'
      'For each meal, suggest:\n'
      '1. Exact time to eat (respecting before/after food rules)\n'
      '2. What to eat (specific, healthy meal ideas)\n'
      '3. What to AVOID eating with each medicine\n'
      '4. Water/hydration reminders\n\n'
      'Format as a chronological timeline from morning to night.',
    );
  }

  // ─── NEW: Weekly Adherence Coach ──────────────────────────────────

  /// Analyze adherence patterns and give personalized coaching
  Future<String> getAdherenceCoaching({
    required List<Medicine> medicines,
    required double adherencePercent,
    required int totalDoses,
    required int missedDoses,
  }) async {
    final medSummary = medicines
        .where((m) => m.isActive)
        .map((m) => '${m.name} at ${m.times.join(", ")}')
        .join(', ');

    return sendMessage(
      'ADHERENCE COACHING REQUEST:\n'
      'My adherence: ${adherencePercent.toStringAsFixed(0)}% '
      '(missed $missedDoses out of $totalDoses doses recently)\n'
      'Medicines: $medSummary\n\n'
      'Analyze my adherence pattern and give me:\n'
      '1. What I\'m doing well (positive reinforcement)\n'
      '2. Specific tips to improve based on my schedule\n'
      '3. One simple habit I can build this week\n'
      '4. Motivational note on why consistency matters for my medicines',
    );
  }

  /// Quick suggestion prompts
  List<String> getQuickSuggestions(List<Medicine> medicines) {
    final suggestions = <String>[
      'I have a headache, is it my medicine?',
      'Plan my meals around my medicines',
      'I woke up late, reschedule my doses',
      'How am I doing with adherence?',
    ];

    if (medicines.isNotEmpty) {
      suggestions.add('Explain ${medicines.first.name}');
      suggestions.add('Side effects of ${medicines.first.name}');
      if (medicines.length > 1) {
        suggestions.add('Check drug interactions');
      }
    }

    suggestions.addAll([
      'What food should I eat today?',
      'I missed a dose, what do I do?',
      'Tips to never miss a dose',
      'Best time for medicines & sleep?',
      'What if I feel side effects?',
    ]);

    return suggestions;
  }
}
