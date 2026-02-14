import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/medicine_provider.dart';
import '../widgets/medicine_card.dart';
import '../widgets/empty_state.dart';

class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<MedicineProvider>();
    final grouped = provider.groupedByPeriod;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: SafeArea(
        child: provider.activeMedicines.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_off_rounded,
                title: 'No Reminders',
                subtitle: 'Add medicines to see your daily reminders here',
              )
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Daily Reminders',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Build sections
                  ...grouped.entries
                      .where((e) => e.value.isNotEmpty)
                      .expand((entry) {
                    final periodIcon = _periodIcon(entry.key);
                    final periodColor = _periodColor(entry.key);

                    return [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: periodColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  periodIcon,
                                  size: 18,
                                  color: periodColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: periodColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${entry.value.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: periodColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = entry.value[index];
                              return MedicineCard(
                                medicine: item.key,
                                time: item.value,
                                isTaken: provider.isTaken(
                                    item.key.id, item.value),
                                onToggle: () => provider.toggleTaken(
                                    item.key.id, item.value),
                                index: index,
                              );
                            },
                            childCount: entry.value.length,
                          ),
                        ),
                      ),
                    ];
                  }),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _periodIcon(String period) {
    switch (period) {
      case 'Morning':
        return Icons.wb_sunny_rounded;
      case 'Afternoon':
        return Icons.wb_twilight_rounded;
      case 'Evening':
        return Icons.nightlight_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  Color _periodColor(String period) {
    switch (period) {
      case 'Morning':
        return const Color(0xFFFF9F1C);
      case 'Afternoon':
        return const Color(0xFF00B4D8);
      case 'Evening':
        return const Color(0xFF7B2FF7);
      default:
        return AppColors.primary;
    }
  }
}