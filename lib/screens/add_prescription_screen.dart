import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../services/prescription_service.dart';

class AddPrescriptionScreen extends StatefulWidget {
  const AddPrescriptionScreen({super.key});

  @override
  State<AddPrescriptionScreen> createState() => _AddPrescriptionScreenState();
}

class _AddPrescriptionScreenState extends State<AddPrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _doctorController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();
  final _medicineController = TextEditingController();

  File? _imageFile;
  DateTime _dateIssued = DateTime.now();
  final List<String> _medicines = [];
  bool _isLoading = false;

  final _prescriptionService = PrescriptionService();
  final _imagePicker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _doctorController.dispose();
    _hospitalController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    _medicineController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Upload Prescription',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _imageSourceOption(
                      isDark,
                      Icons.camera_alt_rounded,
                      'Camera',
                      'Take a photo',
                      () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imageSourceOption(
                      isDark,
                      Icons.photo_library_rounded,
                      'Gallery',
                      'Choose from gallery',
                      () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _imageSourceOption(bool isDark, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateIssued,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateIssued = picked);
    }
  }

  void _addMedicine() {
    final name = _medicineController.text.trim();
    if (name.isNotEmpty) {
      setState(() {
        _medicines.add(name);
        _medicineController.clear();
      });
      // Keep focus on the text field for quick entry
      FocusScope.of(context).previousFocus();
    }
  }

  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

      await _prescriptionService.addPrescription(
        userId: userId,
        title: _titleController.text.trim(),
        doctorName: _doctorController.text.trim(),
        hospitalName: _hospitalController.text.trim(),
        diagnosis: _diagnosisController.text.trim(),
        notes: _notesController.text.trim(),
        imageFile: _imageFile,
        medicines: _medicines,
        dateIssued: _dateIssued,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Add Prescription'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : AppColors.textDark,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image upload area
                _buildImageUpload(isDark),
                const SizedBox(height: 24),

                // Title
                _buildLabel('Prescription Title *', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  isDark,
                  _titleController,
                  'e.g. Monthly Checkup',
                  Icons.title_rounded,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                // Doctor Name
                _buildLabel('Doctor Name', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  isDark,
                  _doctorController,
                  'e.g. Dr. Smith',
                  Icons.person_rounded,
                ),
                const SizedBox(height: 16),

                // Hospital
                _buildLabel('Hospital / Clinic', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  isDark,
                  _hospitalController,
                  'e.g. City Hospital',
                  Icons.local_hospital_rounded,
                ),
                const SizedBox(height: 16),

                // Diagnosis
                _buildLabel('Diagnosis', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  isDark,
                  _diagnosisController,
                  'e.g. Seasonal Flu',
                  Icons.medical_information_rounded,
                ),
                const SizedBox(height: 16),

                // Date
                _buildLabel('Date Issued', isDark),
                const SizedBox(height: 8),
                _buildDatePicker(isDark),
                const SizedBox(height: 16),

                // Medicines
                _buildLabel('Medicines Prescribed', isDark),
                const SizedBox(height: 8),
                _buildMedicineInput(isDark),
                if (_medicines.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildMedicineChips(isDark),
                ],
                const SizedBox(height: 16),

                // Notes
                _buildLabel('Additional Notes', isDark),
                const SizedBox(height: 8),
                _buildTextField(
                  isDark,
                  _notesController,
                  'Any special instructions...',
                  Icons.notes_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _savePrescription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded),
                              SizedBox(width: 8),
                              Text(
                                'Save Prescription',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : AppColors.textDark,
      ),
    );
  }

  Widget _buildTextField(
    bool isDark,
    TextEditingController controller,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : AppColors.textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildImageUpload(bool isDark) {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        width: double.infinity,
        height: _imageFile != null ? 220 : 140,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
            // Dashed border effect
          ),
          image: _imageFile != null
              ? DecorationImage(
                  image: FileImage(_imageFile!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _imageFile != null
            ? Stack(
                children: [
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _imageFile = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.greenAccent, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Image attached',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_rounded,
                    size: 40,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload Prescription Image',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to take photo or choose from gallery',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('dd MMMM yyyy').format(_dateIssued),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const Spacer(),
            const Icon(Icons.edit_calendar_rounded,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineInput(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _medicineController,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textDark,
            ),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Add medicine name',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.medication_rounded,
                  color: AppColors.primary, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
            onFieldSubmitted: (_) => _addMedicine(),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _addMedicine,
            borderRadius: BorderRadius.circular(12),
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineChips(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _medicines.asMap().entries.map((entry) {
        return Chip(
          label: Text(
            entry.value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textDark,
              fontSize: 13,
            ),
          ),
          deleteIcon:
              const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
          onDeleted: () {
            setState(() => _medicines.removeAt(entry.key));
          },
          backgroundColor:
              isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        );
      }).toList(),
    );
  }
}
