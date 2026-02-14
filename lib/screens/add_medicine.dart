import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../models/medicine.dart';
import '../providers/medicine_provider.dart';
import '../providers/user_provider.dart';


class AddMedicine extends StatefulWidget {
  const AddMedicine({super.key});

  @override
  State<AddMedicine> createState() => _AddMedicineState();
}

class _AddMedicineState extends State<AddMedicine> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedFrequency = 'daily';
  String _selectedFoodInstruction = 'after';
  String _selectedUnit = 'mg';
  final List<String> _selectedTimes = ['08:00'];

  final List<String> _frequencies = ['daily', 'twice', 'thrice', 'weekly'];
  final List<String> _foodInstructions = ['before', 'after', 'with'];
  final List<String> _units = ['mg', 'ml', 'tablets', 'capsules'];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    final parts = _selectedTimes[index].split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTimes[index] =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addTimeSlot() {
    setState(() {
      _selectedTimes.add('12:00');
    });
  }

  void _removeTimeSlot(int index) {
    if (_selectedTimes.length > 1) {
      setState(() {
        _selectedTimes.removeAt(index);
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<MedicineProvider>();
    final userProvider = context.read<UserProvider>();
    final userId = userProvider.currentUser?.uid ?? '';
    
    final medicine = Medicine(
      id: provider.generateId(),
      userId: userId,
      name: _nameController.text.trim(),
      dosage: '${_dosageController.text.trim()} $_selectedUnit',
      frequency: _selectedFrequency,
      times: List.from(_selectedTimes),
      foodInstruction: _selectedFoodInstruction,
      startDate: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      // Add medicine to Firestore - provider will auto-schedule notifications
      await provider.addMedicine(medicine);
      
      // Wait a moment for Firestore stream to trigger and schedule notifications
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('${medicine.name} added successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Clear form
      _nameController.clear();
      _dosageController.clear();
      _notesController.clear();
      setState(() {
        _selectedTimes.clear();
        _selectedTimes.add('08:00');
        _selectedFrequency = 'daily';
        _selectedFoodInstruction = 'after';
        _selectedUnit = 'mg';
      });

    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Failed to add medicine'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Add Medicine',
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

            // Form
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Medicine Name
                      _sectionLabel('Medicine Name', isDark),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Enter medicine name' : null,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Paracetamol',
                          prefixIcon:
                              Icon(Icons.medication_rounded),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Dosage + Unit
                      _sectionLabel('Dosage', isDark),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _dosageController,
                              keyboardType: TextInputType.number,
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Enter dosage' : null,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 500',
                                prefixIcon: Icon(Icons.numbers_rounded),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkCard
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedUnit,
                                  isExpanded: true,
                                  dropdownColor: isDark
                                      ? AppColors.darkCard
                                      : Colors.white,
                                  items: _units.map((u) {
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedUnit = v!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Frequency
                      _sectionLabel('Frequency', isDark),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _frequencies.map((f) {
                          final isSelected = _selectedFrequency == f;
                          return ChoiceChip(
                            label: Text(
                              f[0].toUpperCase() + f.substring(1),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundColor: isDark
                                ? AppColors.darkCard
                                : Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? Colors.white70 : Colors.black54),
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedFrequency = f),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Times
                      _sectionLabel('Reminder Times', isDark),
                      const SizedBox(height: 8),
                      ...List.generate(_selectedTimes.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _pickTime(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkCard
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? AppColors.primary.withValues(alpha: 0.2)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _formatTime(_selectedTimes[index]),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.textDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_selectedTimes.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => _removeTimeSlot(index),
                                ),
                            ],
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: _addTimeSlot,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add another time'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Food Instruction
                      _sectionLabel('Food Instruction', isDark),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _foodInstructions.map((f) {
                          final isSelected = _selectedFoodInstruction == f;
                          final icons = {
                            'before': Icons.restaurant_menu_rounded,
                            'after': Icons.restaurant_rounded,
                            'with': Icons.dining_rounded,
                          };
                          return ChoiceChip(
                            avatar: Icon(
                              icons[f],
                              size: 18,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            label: Text(
                              '${f[0].toUpperCase()}${f.substring(1)} meal',
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            backgroundColor: isDark
                                ? AppColors.darkCard
                                : Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? Colors.white70 : Colors.black54),
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedFoodInstruction = f),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // Notes
                      _sectionLabel('Notes (Optional)', isDark),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Any additional notes...',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 48),
                            child: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save_rounded),
                          label: const Text(
                            'Save Medicine',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }
}