import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine.dart';
import '../services/ai_service.dart';

class FoodScheduleScreen extends StatefulWidget {
  const FoodScheduleScreen({super.key});

  @override
  State<FoodScheduleScreen> createState() => _FoodScheduleScreenState();
}

class _FoodScheduleScreenState extends State<FoodScheduleScreen> {
  final AIService _aiService = AIService();
  String? _aiTip;
  bool _loadingTip = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_aiTip == null && !_loadingTip) _loadAITip();
  }

  Future<void> _loadAITip() async {
    final medicines = context.read<MedicineProvider>().activeMedicines;
    if (medicines.isEmpty) return;
    setState(() => _loadingTip = true);
    _aiService.initialize(medicines: medicines);
    final tip = await _aiService.sendMessage(
      'As a clinical pharmacist, provide ONE concise food-drug interaction note (2-3 sentences) '
      'for a patient taking: '
      '${medicines.map((m) => '${m.name} (${m.foodInstruction} food)').join(', ')}. '
      'Use professional clinical language. Focus on the most clinically significant interaction.',
    );
    if (mounted) setState(() { _aiTip = tip; _loadingTip = false; });
  }

  String _foodIcon(String instruction) {
    switch (instruction.toLowerCase()) {
      case 'before': return 'Before Food';
      case 'after': return 'After Food';
      case 'with': return 'With Food';
      default: return 'Any Time';
    }
  }

  IconData _foodIconData(String instruction) {
    switch (instruction.toLowerCase()) {
      case 'before': return Icons.wb_twilight_rounded;
      case 'after': return Icons.dinner_dining_rounded;
      case 'with': return Icons.restaurant_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  Color _foodColor(String instruction) {
    switch (instruction.toLowerCase()) {
      case 'before': return const Color(0xFFFF9800);
      case 'after': return const Color(0xFF4CAF50);
      case 'with': return const Color(0xFF2196F3);
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicines = context.watch<MedicineProvider>().medicines
        .where((m) => m.isActive)
        .toList();

    // Group medicines by food instruction
    final beforeFood = medicines.where((m) => m.foodInstruction == 'before').toList();
    final afterFood = medicines.where((m) => m.foodInstruction == 'after').toList();
    final withFood = medicines.where((m) => m.foodInstruction == 'with').toList();
    final anyTime = medicines.where((m) =>
        m.foodInstruction != 'before' &&
        m.foodInstruction != 'after' &&
        m.foodInstruction != 'with').toList();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Food Schedule',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Medicine & meal timing guide',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),

            // AI Clinical Tip Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6CF7), Color(0xFF7B2FF7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4A6CF7).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Clinical Food Guidance',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('Personalised by MediBot AI',
                                style: TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (!_loadingTip && _aiTip != null)
                          GestureDetector(
                            onTap: () { setState(() { _aiTip = null; }); _loadAITip(); },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 16),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _loadingTip
                          ? const Row(
                              children: [
                                SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 1.5)),
                                SizedBox(width: 10),
                                Text('Analysing your medication schedule...',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                              ],
                            )
                          : Text(
                              _aiTip ?? (medicines.isEmpty
                                ? 'Add your medications to receive personalised food-drug interaction guidance.'
                                : 'Maintain consistent meal timing to optimise medication absorption and efficacy.'),
                              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Meal Timeline
            Expanded(
              child: medicines.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.no_meals_rounded, size: 56, color: AppColors.primary),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Active Medications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add medications to view your food schedule',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        if (beforeFood.isNotEmpty) ...[
                          _buildMealSection(
                            context,
                            isDark,
                            icon: Icons.wb_twilight_rounded,
                            title: 'Before Meals',
                            subtitle: 'Administer 30 minutes prior to eating',
                            medicines: beforeFood,
                            color: const Color(0xFFFF9800),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (withFood.isNotEmpty) ...[
                          _buildMealSection(
                            context,
                            isDark,
                            icon: Icons.restaurant_rounded,
                            title: 'With Meals',
                            subtitle: 'Administer during your meal',
                            medicines: withFood,
                            color: const Color(0xFF2196F3),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (afterFood.isNotEmpty) ...[
                          _buildMealSection(
                            context,
                            isDark,
                            icon: Icons.dinner_dining_rounded,
                            title: 'After Meals',
                            subtitle: 'Administer 30 minutes after eating',
                            medicines: afterFood,
                            color: const Color(0xFF4CAF50),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (anyTime.isNotEmpty) ...[
                          _buildMealSection(
                            context,
                            isDark,
                            icon: Icons.schedule_rounded,
                            title: 'Any Time',
                            subtitle: 'No dietary restriction required',
                            medicines: anyTime,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Daily Schedule
                        _buildDailySchedule(context, isDark, medicines),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Medicine> medicines,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${medicines.length} med${medicines.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Per-medicine tappable cards
          ...medicines.map((med) => _buildMedicineInfoTile(context, isDark, med, color)),
        ],
      ),
    );
  }

  Widget _buildMedicineInfoTile(BuildContext context, bool isDark, Medicine med, Color color) {
    return InkWell(
      onTap: () => _showMedicineAIInfo(context, isDark, med),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.medication_rounded, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  Text(
                    '${med.dosage}  •  ${med.times.join(', ')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, color: color, size: 13),
                  const SizedBox(width: 4),
                  Text('AI Info', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMedicineAIInfo(BuildContext context, bool isDark, Medicine med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MedicineAIInfoSheet(medicine: med, isDark: isDark),
    );
  }

  Widget _buildDailySchedule(
      BuildContext context, bool isDark, List<Medicine> medicines) {
    // Collect all time slots
    final slots = <_TimeSlot>[];
    for (final med in medicines) {
      for (final time in med.times) {
        slots.add(_TimeSlot(
          time: time,
          medicineName: med.name,
          dosage: med.dosage,
          foodInstruction: med.foodInstruction,
        ));
      }
    }
    slots.sort((a, b) => a.time.compareTo(b.time));

    if (slots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Schedule',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ...slots.map((slot) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  SizedBox(
                    width: 56,
                    child: Text(
                      slot.time,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  // Timeline dot
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _foodColor(slot.foodInstruction),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Medicine info
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _foodColor(slot.foodInstruction)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  slot.medicineName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  slot.dosage,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _foodColor(slot.foodInstruction).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_foodIconData(slot.foodInstruction),
                                  color: _foodColor(slot.foodInstruction), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  _foodIcon(slot.foodInstruction),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _foodColor(slot.foodInstruction),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _TimeSlot {
  final String time;
  final String medicineName;
  final String dosage;
  final String foodInstruction;

  _TimeSlot({
    required this.time,
    required this.medicineName,
    required this.dosage,
    required this.foodInstruction,
  });
}

// ─── Per-Medicine AI Info Sheet ───────────────────────────────────────────────

class _MedicineAIInfoSheet extends StatefulWidget {
  final Medicine medicine;
  final bool isDark;
  const _MedicineAIInfoSheet({required this.medicine, required this.isDark});

  @override
  State<_MedicineAIInfoSheet> createState() => _MedicineAIInfoSheetState();
}

class _MedicineAIInfoSheetState extends State<_MedicineAIInfoSheet> {
  final AIService _aiService = AIService();
  String? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      _aiService.initialize(medicines: [widget.medicine]);
      final result = await _aiService.sendMessage(
        'Provide a structured clinical summary for ${widget.medicine.name} '
        '(${widget.medicine.dosage}, ${widget.medicine.foodInstruction} food, '
        'taken at: ${widget.medicine.times.join(", ")}). Include:\n'
        '1. Therapeutic purpose\n'
        '2. Food-drug interaction guidance\n'
        '3. Key adverse effects to monitor\n'
        '4. Storage requirements\n'
        'Use professional clinical language. Keep it concise.',
      );
      if (mounted) setState(() { _info = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F36) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A6CF7), Color(0xFF7B2FF7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medication_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medicine.name,
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1A1F36),
                          ),
                        ),
                        Text(
                          '${widget.medicine.dosage}  •  ${widget.medicine.foodInstruction} food',
                          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A6CF7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services_rounded, color: Color(0xFF4A6CF7), size: 13),
                        SizedBox(width: 4),
                        Text('MediBot', style: TextStyle(color: Color(0xFF4A6CF7), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('MediBot is preparing clinical summary...',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(child: Text('Error: $_error',
                          style: const TextStyle(color: AppColors.error)))
                      : SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFormattedText(_info ?? '', isDark),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'AI-generated clinical information. Always consult your physician or pharmacist for personalised guidance.',
                                        style: TextStyle(color: AppColors.warning, fontSize: 11, height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isDark) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) return const SizedBox(height: 8);
        // Numbered header lines like "1. Therapeutic purpose"
        final isHeader = RegExp(r'^\d+\.\s').hasMatch(line.trim());
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildRichLine(line.trim(), isDark, isHeader),
        );
      }).toList(),
    );
  }

  Widget _buildRichLine(String line, bool isDark, bool isHeader) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final match in regex.allMatches(line)) {
      if (match.start > last) {
        spans.add(TextSpan(text: line.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      last = match.end;
    }
    if (last < line.length) spans.add(TextSpan(text: line.substring(last)));

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: isHeader ? 14 : 13,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
          color: isHeader
              ? (isDark ? Colors.white : const Color(0xFF1A1F36))
              : (isDark ? Colors.white70 : Colors.black87),
          height: 1.5,
        ),
        children: spans.isEmpty ? [TextSpan(text: line)] : spans,
      ),
    );
  }
}
