import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_theme.dart';
import '../services/notification_service.dart';
import '../providers/user_provider.dart';
import '../models/medicine.dart';
import 'report_screen.dart';
import 'food_schedule_screen.dart';
import 'prescription_pdf_screen.dart';

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
          const FoodScheduleScreen(),
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
                _navItem(4, Icons.restaurant_rounded, Icons.restaurant_outlined),
                _navItem(5, Icons.person_rounded, Icons.person_outline_rounded),
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
        padding: const EdgeInsets.all(12),
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
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
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
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFirstName(user?.name ?? 'Guest'),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // SOS Emergency Button
                  GestureDetector(
                    onTap: () async {
                      final emergency = user?.emergencyContact ?? '';
                      if (emergency.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Set emergency contact in Profile first'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }
                      final uri = Uri.parse('tel:$emergency');
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency_rounded, color: AppColors.error, size: 16),
                          SizedBox(width: 4),
                          Text('SOS', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Settings icon
                  Material(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onNavigate(5),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.settings_rounded,
                          color: isDark ? Colors.white70 : AppColors.textDark,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // AI Coaching Banner (shown when adherence < 70%)
          if (provider.activeMedicines.isNotEmpty &&
              provider.adherencePercentage < 70) ...[
            GestureDetector(
              onTap: () => onNavigate(3), // Navigate to AI Chat
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4081)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MediBot Coaching Available',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(
                            'Your adherence is ${provider.adherencePercentage.toStringAsFixed(0)}%. Tap for AI tips to improve!',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ],

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

          // Quick Action Cards
          Row(
            children: [
              _buildQuickAction(
                context: context,
                isDark: isDark,
                icon: Icons.description_rounded,
                color: const Color(0xFF6B4CFF),
                title: 'Rx Records',
                subtitle: (user?.isDoctor ?? false) ? 'Upload' : 'View',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrescriptionListScreen()),
                ),
              ),
              const SizedBox(width: 10),
              _buildQuickAction(
                context: context,
                isDark: isDark,
                icon: Icons.restaurant_rounded,
                color: Colors.orange,
                title: 'Diet Plan',
                subtitle: 'Meals',
                onTap: () => onNavigate(4),
              ),
              const SizedBox(width: 10),
              _buildQuickAction(
                context: context,
                isDark: isDark,
                icon: Icons.picture_as_pdf_rounded,
                color: const Color(0xFF00C853),
                title: 'Export',
                subtitle: 'PDF',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrescriptionPdfScreen()),
                ),
              ),
            ],
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
            _buildMedicineList(context, provider),
        ],
      ),
    );
  }

  Widget _buildMedicineList(BuildContext context, MedicineProvider provider) {
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
                onDelete: () => _confirmDelete(context, provider, medicine),
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

  String _getFirstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Guest';
    final firstName = trimmed.split(' ').first;
    // Capitalize first letter
    return firstName[0].toUpperCase() + firstName.substring(1);
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, MedicineProvider provider, Medicine medicine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
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
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Delete Medicine?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${medicine.name}"? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.removeMedicine(medicine.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${medicine.name} deleted'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

