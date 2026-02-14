import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../config/app_theme.dart';
import '../models/user_model.dart';
import '../models/medicine.dart';
import '../providers/user_provider.dart';
import '../services/doctor_service.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import '../models/appointment.dart';

class PatientDetailScreen extends StatefulWidget {
  final UserModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  UserModel get patient => widget.patient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctorService = DoctorService();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(patient.name),
          actions: [
            // Chat button
            IconButton(
              icon: const Icon(Icons.chat_rounded, color: AppColors.primary),
              onPressed: () async {
                final doctor = context.read<UserProvider>().currentUser;
                if (doctor == null) return;

                final chatService = ChatService();
                final chatRoomId = await chatService.getOrCreateChatRoom(
                  doctor.uid,
                  patient.uid,
                );

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatRoomId: chatRoomId,
                      currentUserId: doctor.uid,
                      currentUserName: doctor.name,
                      otherUserName: patient.name,
                      otherUserId: patient.uid,
                    ),
                  ),
                );
              },
            ),
            // Remove patient
            IconButton(
              icon: const Icon(Icons.person_remove_rounded),
              color: AppColors.error,
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Patient'),
                    content: Text('Remove ${patient.name} from your patients?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await doctorService.unassignPatient(patient.uid);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Patient Info Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: isDark ? AppColors.cardGradient : null,
                      color: isDark ? null : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            patient.name.isNotEmpty ? patient.name[0].toUpperCase() : 'P',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                patient.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              if (patient.phone != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  patient.phone!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Medicines Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    'Medicines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),

              // Medicines List
              StreamBuilder<List<Medicine>>(
                stream: doctorService.getPatientMedicines(patient.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      )),
                    );
                  }

                  final medicines = snapshot.data ?? [];

                  if (medicines.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.medication_rounded,
                                size: 48,
                                color: AppColors.textMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No medicines added yet',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final med = medicines[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: isDark ? AppColors.cardGradient : null,
                              color: isDark ? null : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (med.isActive
                                            ? AppColors.primary
                                            : AppColors.textMuted)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.medication_rounded,
                                    color: med.isActive
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${med.dosage} • ${med.frequency} • ${med.foodInstruction} food',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Times: ${med.times.join(", ")}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (med.isActive
                                            ? AppColors.success
                                            : AppColors.textMuted)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    med.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: med.isActive
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  color: AppColors.primary,
                                  onPressed: () => _showEditMedicineDialog(context, med),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: medicines.length,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Action Buttons Row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.description_rounded,
                          label: 'Send Prescription',
                          color: const Color(0xFFE91E63),
                          onTap: () => _showSendPrescriptionDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.restaurant_menu_rounded,
                          label: 'Add Instructions',
                          color: AppColors.warning,
                          onTap: () => _showAddInstructionsDialog(context),
                        ),
                      ),
                      ],
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Schedule Appointment Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _ActionButton(
                    icon: Icons.calendar_today_rounded,
                    label: 'Schedule Appointment',
                    color: const Color(0xFF673AB7),
                    onTap: () => _showScheduleAppointmentDialog(context),
                  ),
                ),
              ),

              // Adherence Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Today\'s Adherence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FutureBuilder<Map<String, dynamic>?>(
                    future: doctorService.getPatientAdherence(patient.uid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final data = snap.data;
                      if (data == null || data.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: isDark ? AppColors.cardGradient : null,
                            color: isDark ? null : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: const Center(
                            child: Text('No adherence data for today',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        );
                      }
                      final entries = data.entries.where((e) => e.key != 'date').toList();
                      final taken = entries.where((e) => e.value == true).length;
                      final total = entries.length;
                      final pct = total > 0 ? taken / total : 0.0;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isDark ? AppColors.cardGradient : null,
                          color: isDark ? null : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _StatChip(
                                  label: 'Taken',
                                  value: '$taken',
                                  color: AppColors.success,
                                  isDark: isDark,
                                ),
                                _StatChip(
                                  label: 'Missed',
                                  value: '${total - taken}',
                                  color: AppColors.error,
                                  isDark: isDark,
                                ),
                                _StatChip(
                                  label: 'Rate',
                                  value: '${(pct * 100).toInt()}%',
                                  color: AppColors.primary,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(
                                  pct >= 0.8
                                      ? AppColors.success
                                      : pct >= 0.5
                                          ? AppColors.warning
                                          : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Doctor Instructions Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Doctor Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(patient.uid)
                        .collection('doctor_instructions')
                        .doc('latest')
                        .snapshots(),
                    builder: (context, snap) {
                      final data = snap.data?.data() as Map<String, dynamic>?;
                      if (data == null || data.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: isDark ? AppColors.cardGradient : null,
                            color: isDark ? null : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: const Center(
                            child: Text('No instructions added yet',
                                style: TextStyle(color: AppColors.textMuted)),
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isDark ? AppColors.cardGradient : null,
                          color: isDark ? null : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['foodInstructions'] != null &&
                                (data['foodInstructions'] as String).isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.restaurant_rounded,
                                      color: AppColors.warning, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Food Instructions',
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(data['foodInstructions'],
                                style: const TextStyle(
                                  fontSize: 13, color: AppColors.textMuted, height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (data['medicineInstructions'] != null &&
                                (data['medicineInstructions'] as String).isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.medication_rounded,
                                      color: AppColors.primary, size: 16),
                                  const SizedBox(width: 6),
                                  Text('Medicine Instructions',
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(data['medicineInstructions'],
                                style: const TextStyle(
                                  fontSize: 13, color: AppColors.textMuted, height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendPrescriptionDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final diagnosisCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final medicinesCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: const Text('Send Prescription'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: titleCtrl, label: 'Title', isDark: isDark),
              const SizedBox(height: 12),
              _DialogField(controller: diagnosisCtrl, label: 'Diagnosis', isDark: isDark),
              const SizedBox(height: 12),
              _DialogField(controller: medicinesCtrl, label: 'Medicines (comma-separated)', isDark: isDark),
              const SizedBox(height: 12),
              _DialogField(controller: notesCtrl, label: 'Notes', isDark: isDark, maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              final doctor = context.read<UserProvider>().currentUser;
              final prescId = const Uuid().v4();
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(patient.uid)
                  .collection('prescriptions')
                  .doc(prescId)
                  .set({
                'id': prescId,
                'userId': patient.uid,
                'title': titleCtrl.text.trim(),
                'doctorName': doctor?.name ?? 'Doctor',
                'diagnosis': diagnosisCtrl.text.trim(),
                'notes': notesCtrl.text.trim(),
                'medicines': medicinesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                'dateIssued': FieldValue.serverTimestamp(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription sent ✓'),
                      backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAddInstructionsDialog(BuildContext context) {
    final foodCtrl = TextEditingController();
    final medCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Load existing instructions
    FirebaseFirestore.instance
        .collection('users')
        .doc(patient.uid)
        .collection('doctor_instructions')
        .doc('latest')
        .get()
        .then((doc) {
      if (doc.exists) {
        final data = doc.data();
        foodCtrl.text = data?['foodInstructions'] ?? '';
        medCtrl.text = data?['medicineInstructions'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: const Text('Food & Medicine Instructions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: foodCtrl, label: 'Food Instructions',
                  isDark: isDark, maxLines: 3,
                  hint: 'e.g. Avoid citrus fruits, eat dairy...'),
              const SizedBox(height: 12),
              _DialogField(controller: medCtrl, label: 'Medicine Instructions',
                  isDark: isDark, maxLines: 3,
                  hint: 'e.g. Take on empty stomach, avoid alcohol...'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final doctor = context.read<UserProvider>().currentUser;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(patient.uid)
                  .collection('doctor_instructions')
                  .doc('latest')
                  .set({
                'foodInstructions': foodCtrl.text.trim(),
                'medicineInstructions': medCtrl.text.trim(),
                'doctorName': doctor?.name ?? 'Doctor',
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Instructions saved ✓'),
                      backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditMedicineDialog(BuildContext context, Medicine med) {
    final dosageCtrl = TextEditingController(text: med.dosage);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isActive = med.isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Text('Edit ${med.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(controller: dosageCtrl, label: 'Dosage', isDark: isDark),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Status'),
                value: isActive,
                onChanged: (val) => setDialogState(() => isActive = val),
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updated = med.copyWith(
                  dosage: dosageCtrl.text.trim(),
                  isActive: isActive,
                );
                await DoctorService().updateMedicine(patient.uid, updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Medicine updated'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleAppointmentDialog(BuildContext context) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final notesCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: const Text('Schedule Appointment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Date'),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                trailing: const Icon(Icons.calendar_month_rounded),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setDialogState(() => selectedDate = date);
                  }
                },
              ),
              ListTile(
                title: const Text('Time'),
                subtitle: Text(selectedTime.format(context)),
                trailing: const Icon(Icons.access_time_rounded),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) {
                    setDialogState(() => selectedTime = time);
                  }
                },
              ),
              const SizedBox(height: 10),
              _DialogField(controller: notesCtrl, label: 'Notes (Optional)', isDark: isDark),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final doctor = context.read<UserProvider>().currentUser;
                if (doctor == null) return;

                final DateTime appointmentDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final appointment = Appointment(
                  id: const Uuid().v4(),
                  doctorId: doctor.uid,
                  doctorName: doctor.name,
                  patientId: patient.uid,
                  patientName: patient.name,
                  dateTime: appointmentDateTime,
                  notes: notesCtrl.text.trim(),
                  createdAt: DateTime.now(),
                );

                await DoctorService().createAppointment(appointment);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appointment scheduled'), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.cardGradient : null,
          color: isDark ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : AppColors.textDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatChip({required this.label, required this.value,
      required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold, color: color,
          ),
        ),
        Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final int maxLines;
  final String? hint;

  const _DialogField({required this.controller, required this.label,
      required this.isDark, this.maxLines = 1, this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
