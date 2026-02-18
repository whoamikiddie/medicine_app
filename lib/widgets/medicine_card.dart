import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../config/app_theme.dart';
import '../services/ai_service.dart';

class MedicineCard extends StatefulWidget {
  final Medicine medicine;
  final String time;
  final bool isTaken;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final int index;

  const MedicineCard({
    super.key,
    required this.medicine,
    required this.time,
    this.isTaken = false,
    this.onToggle,
    this.onDelete,
    this.index = 0,
  });

  @override
  State<MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<MedicineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final delay = widget.index * 0.1;
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delay.clamp(0.0, 0.6), 1.0, curve: Curves.easeOutCubic),
    );

    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(curve);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(curve);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData get _pillIcon {
    switch (widget.medicine.frequency) {
      case 'daily':
        return Icons.medication_rounded;
      case 'twice':
        return Icons.medication_liquid_rounded;
      case 'thrice':
        return Icons.vaccines_rounded;
      default:
        return Icons.medication_rounded;
    }
  }

  String get _foodLabel {
    switch (widget.medicine.foodInstruction) {
      case 'before':
        return 'Before meal';
      case 'after':
        return 'After meal';
      case 'with':
        return 'With meal';
      default:
        return '';
    }
  }

  String get _formattedTime {
    final parts = widget.time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  bool get _isTimePassed {
    final now = TimeOfDay.now();
    final parts = widget.time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour < now.hour || (hour == now.hour && minute < now.minute);
  }

  /// Remaining days until medicine endDate, null if no endDate
  int? get _remainingDays {
    if (widget.medicine.endDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(
      widget.medicine.endDate!.year,
      widget.medicine.endDate!.month,
      widget.medicine.endDate!.day,
    );
    return end.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMissed = _isTimePassed && !widget.isTaken;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: child,
            ),
          ),
        );
      },
      child: _buildCard(isDark, isMissed),
    );
  }

  Widget _buildCard(bool isDark, bool isMissed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.cardGradient : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isTaken
              ? AppColors.success.withValues(alpha: 0.5)
              : isMissed
                  ? AppColors.error.withValues(alpha: 0.3)
                  : (isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade200),
          width: widget.isTaken || isMissed ? 1.5 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: widget.isTaken
                  ? AppColors.success.withValues(alpha: 0.1)
                  : isMissed
                      ? AppColors.error.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Animated Pill Icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: widget.isTaken
                        ? const LinearGradient(
                            colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : isMissed
                            ? LinearGradient(
                                colors: [
                                  AppColors.error.withValues(alpha: 0.8),
                                  AppColors.error,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isTaken
                                ? AppColors.success
                                : isMissed
                                    ? AppColors.error
                                    : AppColors.primary)
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: Icon(
                      widget.isTaken
                          ? Icons.check_rounded
                          : isMissed
                              ? Icons.warning_rounded
                              : _pillIcon,
                      key: ValueKey(widget.isTaken ? 'taken' : isMissed ? 'missed' : 'active'),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medicine name
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.isTaken
                              ? (isDark ? Colors.white38 : Colors.grey)
                              : (isDark ? Colors.white : AppColors.textDark),
                          decoration:
                              widget.isTaken ? TextDecoration.lineThrough : null,
                        ),
                        child: Text(widget.medicine.name),
                      ),
                      const SizedBox(height: 6),
                      
                      // Time • Dosage row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: isMissed ? AppColors.error : AppColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formattedTime,
                            style: TextStyle(
                              fontSize: 12,
                              color: isMissed ? AppColors.error : AppColors.textMuted,
                              fontWeight: isMissed ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.medicine.dosage,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Badges: status + food + days — all in one Wrap row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (isMissed || widget.isTaken)
                            _buildBadge(
                              icon: widget.isTaken ? Icons.check_circle_rounded : Icons.error_rounded,
                              label: widget.isTaken ? 'Taken' : 'Missed',
                              color: widget.isTaken ? AppColors.success : AppColors.error,
                            ),
                          if (_foodLabel.isNotEmpty)
                            _buildBadge(
                              icon: Icons.restaurant_rounded,
                              label: _foodLabel,
                              color: AppColors.warning,
                            ),
                          if (_remainingDays != null)
                            _buildBadge(
                              icon: Icons.calendar_today_rounded,
                              label: _remainingDays! <= 0
                                  ? 'Last day'
                                  : '$_remainingDays day${_remainingDays == 1 ? '' : 's'} left',
                              color: _remainingDays! <= 3 ? AppColors.error : AppColors.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right column: Take button on top, icons below
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildActionButton(isDark, isMissed),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _showFoodAdvice(context),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppColors.warning.withValues(alpha: 0.8),
                            size: 18,
                          ),
                        ),
                        if (widget.onDelete != null) ...[
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error.withValues(alpha: 0.7),
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isDark, bool isMissed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: widget.isTaken
            ? const LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
              )
            : null,
        color: widget.isTaken
            ? null
            : (isMissed
                ? AppColors.error.withValues(alpha: 0.15)
                : AppColors.primary.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: child,
            ),
            child: Icon(
              widget.isTaken
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              key: ValueKey(widget.isTaken),
              size: 16,
              color: widget.isTaken
                  ? Colors.white
                  : (isMissed ? AppColors.error : AppColors.primary),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.isTaken
                  ? 'Taken'
                  : (isMissed ? 'Missed' : 'Take'),
              key: ValueKey(widget.isTaken ? 'taken' : isMissed ? 'missed' : 'take'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.isTaken
                    ? Colors.white
                    : (isMissed ? AppColors.error : AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showFoodAdvice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FoodAdviceSheet(
        medicine: widget.medicine,
        isDark: isDark,
      ),
    );
  }
}

class _FoodAdviceSheet extends StatefulWidget {
  final Medicine medicine;
  final bool isDark;

  const _FoodAdviceSheet({required this.medicine, required this.isDark});

  @override
  State<_FoodAdviceSheet> createState() => _FoodAdviceSheetState();
}

class _FoodAdviceSheetState extends State<_FoodAdviceSheet> {
  final AIService _aiService = AIService();
  String? _advice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdvice();
  }

  Future<void> _loadAdvice() async {
    try {
      final advice = await _aiService.getFoodAdvice(widget.medicine);
      if (mounted) setState(() { _advice = advice; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded,
                      color: AppColors.warning, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Food Advice',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : AppColors.textDark,
                        ),
                      ),
                      Text(widget.medicine.name,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Getting AI food advice...',
                            style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ))
                  : _error != null
                      ? Center(child: Text('Error: $_error',
                          style: const TextStyle(color: AppColors.error)))
                      : SingleChildScrollView(
                          controller: scrollController,
                          child: Text(
                            _advice ?? '',
                            style: TextStyle(
                              fontSize: 14, height: 1.6,
                              color: widget.isDark ? Colors.white70 : AppColors.textDark,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
