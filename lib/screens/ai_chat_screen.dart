import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import '../config/app_theme.dart';
import '../providers/medicine_provider.dart';
import '../services/ai_service.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _initialized = false;

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _lastWords = '';

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initializeAI();
      _initSpeech();
      _initialized = true;
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
            // Auto-send if we got words
            if (_messageController.text.trim().isNotEmpty) {
              _sendMessage(_messageController.text);
            }
          }
        }
      },
      onError: (error) {
        debugPrint('[Speech] Error: $error');
        if (mounted) setState(() => _isListening = false);
      },
    );
    debugPrint('[Speech] Available: $_speechAvailable');
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device')),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _lastWords = '';
      });
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _messageController.text = _lastWords;
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: _messageController.text.length),
            );
          });
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
    }
  }

  void _initializeAI() {
    final medicines = context.read<MedicineProvider>().activeMedicines;
    _aiService.initialize(medicines: medicines);

    // Add welcome message
    setState(() {
      _messages.add(_ChatMessage(
        text: 'Hello! I\'m **MediBot**, your AI health assistant.\n\n'
            'I can help you with:\n'
            '  **Symptom Check** — Is that side effect from your medicine?\n'
            '  **Dose Rescheduler** — Missed a dose? I\'ll fix your schedule\n'
            '  **Meal Planner** — What to eat around your medicines\n'
            '  **Adherence Coach** — Personalized tips to stay on track\n'
            '  Drug interactions, food advice, and more\n\n'
            '_Ask me anything, or tap a suggestion below!_',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    final trimmed = text.trim();

    setState(() {
      _messages.add(_ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final medicines = context.read<MedicineProvider>().activeMedicines;
      final provider = context.read<MedicineProvider>();
      final lower = trimmed.toLowerCase();
      String response;

      // ─── Smart Intent Detection ─────────────────────────────────
      if (_isSymptomQuery(lower)) {
        response = await _aiService.checkSymptoms(trimmed, medicines);
      } else if (_isRescheduleQuery(lower)) {
        response = await _aiService.rescheduleDoses(
          medicines: medicines,
          situation: trimmed,
          takenToday: provider.takenToday,
        );
      } else if (_isMealPlanQuery(lower)) {
        response = await _aiService.generateMealPlan(medicines);
      } else if (_isAdherenceQuery(lower)) {
        response = await _aiService.getAdherenceCoaching(
          medicines: medicines,
          adherencePercent: provider.adherencePercentage,
          totalDoses: provider.activeMedicines.fold(0, (s, m) => s + m.times.length),
          missedDoses: provider.missedMedicines.length,
        );
      } else if (lower.contains('interaction')) {
        response = await _aiService.checkInteractions(medicines);
      } else {
        response = await _aiService.sendMessage(trimmed);
      }

      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: 'Failed to get response. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }

    _scrollToBottom();
  }

  // ─── Intent Detection Helpers ────────────────────────────────────

  bool _isSymptomQuery(String text) {
    const keywords = [
      'symptom', 'feeling', 'headache', 'dizzy', 'nausea', 'nauseous',
      'pain', 'ache', 'rash', 'itching', 'vomiting', 'drowsy', 'tired',
      'fatigue', 'swelling', 'burning', 'stomach', 'cramp', 'blurry',
      'insomnia', 'anxiety', 'is it my medicine', 'side effect',
      'i feel', 'i\'m feeling', 'experiencing',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isRescheduleQuery(String text) {
    const keywords = [
      'reschedule', 'woke up late', 'woke late', 'overslept', 'missed',
      'forgot', 'skipped', 'late today', 'running late', 'adjust schedule',
      'fix my schedule', 'what now',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isMealPlanQuery(String text) {
    const keywords = [
      'meal plan', 'plan my meal', 'plan my food', 'what to eat',
      'daily meal', 'food plan', 'diet plan', 'eating schedule',
      'meals around', 'breakfast lunch dinner',
    ];
    return keywords.any((k) => text.contains(k));
  }

  bool _isAdherenceQuery(String text) {
    const keywords = [
      'adherence', 'how am i doing', 'my progress', 'coach me',
      'motivate', 'improve my', 'consistency', 'track record',
      'am i on track', 'doing with',
    ];
    return keywords.any((k) => text.contains(k));
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSendImage() async {
    try {
      // Step 1: Ask what type of image
      final imageType = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('What are you sharing?',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    )),
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4CFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF6B4CFF)),
                  ),
                  title: const Text('Prescription / Doctor Note'),
                  subtitle: const Text('AI will read and explain it'),
                  onTap: () => Navigator.pop(ctx, 'prescription'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.medication_rounded, color: Colors.orange),
                  ),
                  title: const Text('Medicine Label / Packaging'),
                  subtitle: const Text('AI will identify and explain'),
                  onTap: () => Navigator.pop(ctx, 'medicine'),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.science_rounded, color: Colors.green),
                  ),
                  title: const Text('Health Report / Lab Result'),
                  subtitle: const Text('AI will summarize key values'),
                  onTap: () => Navigator.pop(ctx, 'report'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );

      if (imageType == null) return;

      // Step 2: Pick image source
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(ctx).brightness == Brightness.dark
                ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );

      if (source == null) return;

      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;

      // Step 3: Show analyzing indicator
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Analysing image with AI...',
          isUser: true,
          timestamp: DateTime.now(),
        ));
        _isTyping = true;
      });
      _scrollToBottom();

      // Step 4: Encode to base64
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Step 5: Build type-specific prompt
      final prompt = switch (imageType) {
        'prescription' =>
          'This is a medical prescription or doctor note. Please:\n'
          '1. List all medicines prescribed with their dosages\n'
          '2. Explain what each medicine is for in simple language\n'
          '3. Note any important instructions (before/after food, frequency, duration)\n'
          '4. Flag any important warnings or precautions\n'
          'Be clear and patient-friendly. Add a disclaimer to consult the doctor.',
        'medicine' =>
          'This is a medicine label or packaging. Please:\n'
          '1. Identify the medicine name and active ingredients\n'
          '2. State the dosage and how to take it\n'
          '3. List key side effects and warnings\n'
          '4. Note food interactions if any\n'
          'Explain in simple, easy-to-understand language.',
        _ =>
          'This is a health report or lab result. Please:\n'
          '1. Identify the type of test/report\n'
          '2. Highlight key values and whether they appear normal or abnormal\n'
          '3. Explain what the values mean in simple language\n'
          '4. Note if anything may require medical attention\n'
          'Always recommend consulting a doctor for proper interpretation.',
      };

      // Step 6: Send to Groq vision API
      final response = await _aiService.sendMessageWithImage(prompt, base64Image);

      if (!mounted) return;

      setState(() {
        _messages.removeLast(); // Remove "Analyzing..." message
        _messages.add(_ChatMessage(
          text: 'Image submitted for AI analysis',
          isUser: true,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
        _messages.add(_ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          if (_messages.isNotEmpty &&
              (_messages.last.text == '📷 Analyzing with AI...' ||
               _messages.last.text == '📷 Uploading image...')) {
            _messages.removeLast();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image analysis failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicines = context.watch<MedicineProvider>().activeMedicines;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(isDark),

            // Disclaimer banner
            _buildDisclaimer(isDark),

            // Messages
            Expanded(
              child: _messages.length <= 1
                  ? _buildWelcomeView(isDark, medicines)
                  : _buildMessageList(isDark),
            ),

            // Typing indicator
            if (_isTyping) _buildTypingIndicator(isDark),

            // Quick suggestions (show when not typing and few messages)
            if (!_isTyping && _messages.length <= 3)
              _buildQuickSuggestions(isDark, medicines),

            // Input
            _buildInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2FF7), Color(0xFFB721FF)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7B2FF7).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MediBot AI',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online • Medicine Assistant',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              final medicines =
                  context.read<MedicineProvider>().activeMedicines;
              _aiService.resetChat(medicines: medicines);
              setState(() {
                _messages.clear();
                _initializeAI();
              });
            },
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : Colors.grey,
            ),
            tooltip: 'New conversation',
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF6B35),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI can make incorrect suggestions. Always consult your doctor before following any medical advice.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFFFFAB76) : const Color(0xFFCC5500),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView(bool isDark, List<dynamic> medicines) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Welcome message bubble
          if (_messages.isNotEmpty)
            _buildMessageBubble(_messages.first, isDark),

          const SizedBox(height: 20),

          // NEW: Smart feature cards
          _buildFeatureCard(
            isDark,
            Icons.health_and_safety_rounded,
            'Symptom Checker',
            'Describe symptoms — I\'ll check if your medicines are the cause',
            const Color(0xFFE91E63),
          ),
          _buildFeatureCard(
            isDark,
            Icons.schedule_send_rounded,
            'Dose Rescheduler',
            'Missed a dose or woke late? I\'ll adjust your entire schedule',
            const Color(0xFF9C27B0),
          ),
          _buildFeatureCard(
            isDark,
            Icons.restaurant_menu_rounded,
            'Meal Planner',
            'Full-day meals timed around your medicine schedule',
            const Color(0xFFFF6B35),
          ),
          _buildFeatureCard(
            isDark,
            Icons.trending_up_rounded,
            'Adherence Coach',
            'Data-driven coaching based on your real progress',
            const Color(0xFF00C853),
          ),
          _buildFeatureCard(
            isDark,
            Icons.compare_arrows_rounded,
            'Drug Interactions',
            'Check if your medicines interact with each other',
            const Color(0xFF00B4D8),
          ),
          _buildFeatureCard(
            isDark,
            Icons.medication_rounded,
            'Medicine Info',
            'Understand your medicines, dosages & side effects',
            const Color(0xFFFF9800),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
      bool isDark, IconData icon, String title, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.cardGradient : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) =>
          _buildMessageBubble(_messages[index], isDark),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, bool isDark) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2FF7), Color(0xFFB721FF)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUser ? AppColors.primaryGradient : null,
                color: isUser
                    ? null
                    : (isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.grey.shade200,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          message.imageUrl!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              width: 200,
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: loadingProgress
                                              .expectedTotalBytes !=
                                          null
                                      ? loadingProgress
                                              .cumulativeBytesLoaded /
                                          loadingProgress
                                              .expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 200,
                            height: 100,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                      ),
                    ),
                  _buildFormattedText(
                    message.text,
                    isUser,
                    isDark,
                  ),
                ],
              ),
            ),
          ),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Simple markdown-like text formatting
  Widget _buildFormattedText(String text, bool isUser, bool isDark) {
    final defaultStyle = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: isUser
          ? Colors.white
          : (isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textDark),
    );

    // Split into lines and process
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      final line = lines[i];
      // Process bold text (**text**)
      final parts = line.split('**');
      for (int j = 0; j < parts.length; j++) {
        if (j % 2 == 1) {
          // Bold
          spans.add(TextSpan(
            text: parts[j],
            style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
          ));
        } else {
          // Process italic (_text_)
          final italicParts = parts[j].split('_');
          for (int k = 0; k < italicParts.length; k++) {
            if (k % 2 == 1) {
              spans.add(TextSpan(
                text: italicParts[k],
                style: defaultStyle.copyWith(fontStyle: FontStyle.italic),
              ));
            } else {
              spans.add(TextSpan(text: italicParts[k]));
            }
          }
        }
      }
    }

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: spans,
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B2FF7), Color(0xFFB721FF)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
                const SizedBox(width: 8),
                const Text(
                  'Thinking...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.3 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildQuickSuggestions(bool isDark, List<dynamic> medicines) {
    final suggestions = _aiService.getQuickSuggestions(
      medicines.cast<dynamic>().whereType<dynamic>().toList().cast(),
    );

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _sendMessage(suggestions[index]),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  suggestions[index],
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Listening indicator bar
        if (_isListening)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: AppColors.error.withValues(alpha: 0.1),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  _lastWords.isEmpty ? 'Listening... speak now' : _lastWords,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.textDark,
                    fontStyle: _lastWords.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _speech.stop();
                    setState(() {
                      _isListening = false;
                      _messageController.clear();
                      _lastWords = '';
                    });
                  },
                  child: const Icon(Icons.close, size: 18, color: AppColors.error),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              // Mic button
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppColors.error.withValues(alpha: 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListening ? AppColors.error : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Image picker button
              GestureDetector(
                onTap: _pickAndSendImage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.image_rounded,
                    color: AppColors.textMuted,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isListening ? 'Listening...' : 'Ask MediBot anything...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textDark,
                      fontSize: 14,
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Send button
              GestureDetector(
                onTap: () => _sendMessage(_messageController.text),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Simple chat message model for the AI chat
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });
}
