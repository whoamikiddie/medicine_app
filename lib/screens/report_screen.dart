import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../providers/medicine_provider.dart';
import '../providers/user_provider.dart';
import '../services/pdf_report_service.dart';
import '../widgets/empty_state.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<MedicineProvider>();
    final userProvider = context.watch<UserProvider>();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: SafeArea(
        child: provider.activeMedicines.isEmpty
            ? const EmptyState(
                icon: Icons.analytics_rounded,
                title: 'No Data Yet',
                subtitle: 'Add medicines and track your adherence to see reports',
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7B2FF7), Color(0xFFB721FF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.analytics_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Health Report',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ),
                        // Export PDF button
                        GestureDetector(
                          onTap: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Generating PDF report...'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                            final history =
                                await provider.getAdherenceHistory(7);
                            await PdfReportService.generateAndShare(
                              medicines: provider.medicines,
                              takenToday: provider.takenTodayCount,
                              missedToday: provider.missedTodayCount,
                              adherencePercentage:
                                  provider.adherencePercentage,
                              weeklyHistory: history,
                              patientName:
                                  userProvider.currentUser?.name ??
                                      'Patient',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF7B2FF7),
                                  Color(0xFFB721FF)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.picture_as_pdf_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Export',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Adherence Circle
                    _buildAdherenceCard(context, provider, isDark),

                    const SizedBox(height: 20),

                    // Risk Level
                    _buildRiskCard(provider, isDark),

                    const SizedBox(height: 20),

                    // Medicine Breakdown
                    Text(
                      'Medicine Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...provider.activeMedicines.map(
                      (med) => _buildMedicineBreakdown(med, provider, isDark),
                    ),

                    const SizedBox(height: 20),

                    // Weekly Chart
                    Text(
                      'Weekly Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildWeeklyChart(isDark, provider),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAdherenceCard(
      BuildContext context, MedicineProvider provider, bool isDark) {
    final adherence = provider.adherencePercentage;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.cardGradient : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 42,
                      startDegreeOffset: -90,
                      sections: [
                        PieChartSectionData(
                          value: adherence,
                          color: _adherenceColor(adherence),
                          radius: 14,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: 100 - adherence,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade200,
                          radius: 14,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${adherence.toInt()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    const Text(
                      'Score',
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
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Adherence',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow('Taken', '${provider.takenTodayCount}',
                    AppColors.success),
                const SizedBox(height: 4),
                _infoRow('Missed', '${provider.missedTodayCount}',
                    AppColors.error),
                const SizedBox(height: 4),
                _infoRow('Total',
                    '${provider.totalMedicines} medicines', AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard(MedicineProvider provider, bool isDark) {
    final adherence = provider.adherencePercentage;
    final String riskLevel;
    final Color riskColor;
    final IconData riskIcon;
    final String riskMessage;

    if (adherence >= 80) {
      riskLevel = 'LOW';
      riskColor = AppColors.success;
      riskIcon = Icons.check_circle_rounded;
      riskMessage = 'Great job! You\'re staying on track with your medicines.';
    } else if (adherence >= 50) {
      riskLevel = 'MEDIUM';
      riskColor = AppColors.warning;
      riskIcon = Icons.warning_rounded;
      riskMessage = 'You\'ve missed some doses. Try setting stronger reminders.';
    } else {
      riskLevel = 'HIGH';
      riskColor = AppColors.error;
      riskIcon = Icons.error_rounded;
      riskMessage =
          'You\'re missing many doses. Please improve your adherence for better health.';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.cardGradient : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.3)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(riskIcon, color: riskColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Risk Level: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        riskLevel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: riskColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  riskMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineBreakdown(
      dynamic med, MedicineProvider provider, bool isDark) {
    final totalDoses = med.times.length;
    int takenDoses = 0;
    for (final time in med.times) {
      if (provider.isTaken(med.id, time)) takenDoses++;
    }
    final progress = totalDoses > 0 ? takenDoses / totalDoses : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.cardGradient : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.medication_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  med.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '$takenDoses/$totalDoses',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: progress >= 1.0
                      ? AppColors.success
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(bool isDark, MedicineProvider provider) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: provider.getAdherenceHistory(7),
      builder: (context, snapshot) {
        // Build 7-day labels (last 7 days)
        final now = DateTime.now();
        final dayLabels = List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          return DateFormat('E').format(date); // Mon, Tue...
        });
        final dateKeys = List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          return DateFormat('yyyy-MM-dd').format(date);
        });

        // Map adherence data to values
        final historyMap = <String, Map<String, dynamic>>{};
        if (snapshot.hasData) {
          for (final entry in snapshot.data!) {
            final date = entry['date'] as String?;
            if (date != null) historyMap[date] = entry;
          }
        }

        final values = List.generate(7, (i) {
          final data = historyMap[dateKeys[i]];
          if (data == null) return 0.0;
          final taken = (data['taken'] ?? 0) as num;
          final total = (data['total'] ?? 1) as num;
          return total > 0 ? (taken / total * 100).clamp(0.0, 100.0) : 0.0;
        });

        return Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isDark ? AppColors.cardGradient : null,
            color: isDark ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: snapshot.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(strokeWidth: 2))
              : BarChart(
                  BarChartData(
                    maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100,
                        strokeWidth: 1,
                      ),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < dayLabels.length) {
                              final isToday = index == 6;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  isToday ? 'Today' : dayLabels[index],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isToday
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    barGroups: List.generate(7, (i) {
                      final isToday = i == 6;
                      final barValue = values[i];
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: barValue,
                            width: 18,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            gradient: LinearGradient(
                              colors: isToday
                                  ? [
                                      const Color(0xFF00C9FF),
                                      const Color(0xFF92FE9D),
                                    ]
                                  : [
                                      AppColors.primary.withValues(alpha: 0.7),
                                      AppColors.primary,
                                    ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
        );
      },
    );
  }

  Color _adherenceColor(double adherence) {
    if (adherence >= 80) return AppColors.success;
    if (adherence >= 50) return AppColors.warning;
    return AppColors.error;
  }
}