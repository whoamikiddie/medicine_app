import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_theme.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';
import 'report_screen.dart';

import 'chat_list_screen.dart';
import 'ai_chat_screen.dart';
import 'profile_screen.dart';
import 'add_medicine.dart';
import 'prescription_list_screen.dart';

import '../widgets/medicine_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/empty_state.dart';
import '../providers/medicine_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final notifService = NotificationService();
    
    // First check if permissions are granted
    final hasPermissions = await notifService.ensurePermissionsGranted();
    if (!hasPermissions) {
      debugPrint('[Home] ⚠️ Notification permissions not granted');
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    // Then check battery optimization
    final isExempt = await notifService.isBatteryOptimizationDisabled();
    if (!isExempt && mounted) {
      _showBatteryDialog(notifService);
    }
  }

  void _showPermissionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_off_rounded,
                  color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Permissions Required',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'MediTrack needs notification permissions to remind you about your medicines. Please grant permissions in the next screen.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await NotificationService().ensurePermissionsGranted();
            },
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    );
  }

  void _showBatteryDialog(NotificationService notifService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.battery_alert_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Enable Reliable Reminders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'For medicine reminders to work properly, please disable battery optimization for MediTrack.',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifService.requestBatteryOptimizationExemption();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Enable Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        children: [
          _DashboardView(
            onNavigate: (index) {
              _pageController.jumpToPage(index);
              setState(() => _currentIndex = index);
            },
          ),
          const ReportScreen(),
          const AddMedicine(),
          const AIChatScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatListScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: _buildGlassNavBar(isDark),
    );
  }

  Widget _buildGlassNavBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF1E1E2E) : Colors.white)
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined),
                _navItem(1, Icons.analytics_rounded, Icons.analytics_outlined),
                _middleNavItem(),
                _navItem(3, Icons.psychology_rounded, Icons.psychology_outlined),
                _navItem(4, Icons.person_rounded, Icons.person_outline_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData selectedIcon, IconData unselectedIcon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.jumpToPage(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
          size: 26,
        ),
      ),
    );
  }

  Widget _middleNavItem() {
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = 2);
        _pageController.jumpToPage(2);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ─── DASHBOARD VIEW ───────────────────────────────────────────────

class _DashboardView extends StatelessWidget {
  final Function(int) onNavigate;

  const _DashboardView({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final user = context.watch<UserProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get unique medicines for today
    final todaysMedicines = provider.todaysMedicines;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getGreetingIcon(),
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'Guest',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
              ClipOval( // Profile Image / Settings
                child: Material(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                  child: InkWell(
                    onTap: () => onNavigate(4), // Go to Profile
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: user?.profileImageUrl != null
                          ? CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(user!.profileImageUrl!),
                            )
                          : Icon(
                              Icons.settings_rounded,
                              color: isDark ? Colors.white : AppColors.textDark,
                              size: 24,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stats Cards
          SizedBox(
            height: 140, 
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total',
                    value: '${provider.totalMedicinesToday}',
                    icon: Icons.medication_rounded,
                    iconColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Taken',
                    value: '${provider.takenCount}',
                    icon: Icons.check_circle_rounded,
                    iconColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Missed',
                    value: '${provider.missedTodayCount}',
                    icon: Icons.warning_rounded,
                    iconColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // My Prescriptions Card
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrescriptionListScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6B4CFF).withValues(alpha: 0.15),
                    const Color(0xFF6B4CFF).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6B4CFF).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4CFF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFF6B4CFF)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Prescriptions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Upload, view & export',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Doctor's Instructions Card
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              final user = userProvider.currentUser;
              if (user == null) return const SizedBox.shrink();

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('doctor_instructions')
                    .doc('latest')
                    .snapshots(),
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>?;
                  
                  final doctorName = data?['doctorName'] ?? 'Doctor';
                  final foodInstructions = data?['foodInstructions']?.toString() ?? '';
                  final medicineInstructions = data?['medicineInstructions']?.toString() ?? '';
                  
                  // Also check individual medicine notes
                  final medNotes = provider.activeMedicines
                      .where((m) => m.notes != null && m.notes!.isNotEmpty)
                      .toList();

                  final hasInstructions = foodInstructions.isNotEmpty || 
                                        medicineInstructions.isNotEmpty || 
                                        medNotes.isNotEmpty;

                  // Hide only if absolutely no data AND no assigned doctor
                  if (!hasInstructions && (user.assignedDoctorId == null || user.assignedDoctorId!.isEmpty)) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withValues(alpha: 0.15),
                            Colors.orange.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.medical_services_rounded, color: Colors.orange),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Doctor's Instructions",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'From Dr. $doctorName',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          if (!hasInstructions)
                             Padding(
                               padding: const EdgeInsets.only(top: 16),
                               child: Text(
                                 'No specific instructions for today.',
                                 style: TextStyle(
                                   color: isDark ? Colors.white70 : AppColors.textMuted,
                                   fontStyle: FontStyle.italic,
                                 ),
                               ),
                             ),

                          if (foodInstructions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.restaurant_rounded, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(child: Text(foodInstructions, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textDark))),
                              ],
                            ),
                          ],

                          if (medicineInstructions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.medication_rounded, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                Expanded(child: Text(medicineInstructions, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textDark))),
                              ],
                            ),
                          ],

                          if (medNotes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text('Medicine Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                            const SizedBox(height: 4),
                            ...medNotes.take(3).map((med) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 4, color: isDark ? Colors.white54 : Colors.black45),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${med.name}: ${med.notes}',
                                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textDark),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ]
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 24),

          // Today's Medicines Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Medicines",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              Text(
                '${provider.takenCount}/${provider.totalMedicinesToday}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),

          // Medicine List
          if (todaysMedicines.isEmpty)
            const EmptyState(
              icon: Icons.sunny,
              title: 'No medicines today',
              subtitle: 'Enjoy your healthy day!',
            )
          else
            _buildMedicineList(provider),
        ],
      ),
    );
  }

  Widget _buildMedicineList(MedicineProvider provider) {
    // Sort times
    final sortedTimes = provider.medicineTimes.keys.toList()
      ..sort((a, b) {
        final aParts = a.split(':').map(int.parse).toList();
        final bParts = b.split(':').map(int.parse).toList();
        return (aParts[0] * 60 + aParts[1])
            .compareTo(bParts[0] * 60 + bParts[1]);
      });

    return Column(
      children: sortedTimes.map((time) {
        final medsAtTime = provider.medicineTimes[time]!;
        // Sort meds by taken status (unchecked first)
        medsAtTime.sort((a, b) {
          final aTaken = provider.isTaken(a.id, time);
          final bTaken = provider.isTaken(b.id, time);
          if (aTaken == bTaken) return 0;
          return aTaken ? 1 : -1;
        });

        return Column(
          children: [
            // Time Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(time),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const Expanded(child: Divider(indent: 12)),
                ],
              ),
            ),
            // Medicines at this time
            ...medsAtTime.map((medicine) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MedicineCard(
                key: ValueKey('${medicine.id}_$time'),
                medicine: medicine,
                time: time,
                isTaken: provider.isTaken(medicine.id, time),
                onToggle: () => provider.toggleTaken(medicine.id, time),
              ),
            )),
          ],
        );
      }).toList(),
    );
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_cloudy_rounded;
    return Icons.nights_stay_rounded;
  }
}

