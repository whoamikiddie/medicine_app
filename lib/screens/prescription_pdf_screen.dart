import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../config/app_theme.dart';
import '../providers/medicine_provider.dart';
import '../providers/user_provider.dart';
import '../models/medicine.dart';

class PrescriptionPdfScreen extends StatefulWidget {
  const PrescriptionPdfScreen({super.key});

  @override
  State<PrescriptionPdfScreen> createState() => _PrescriptionPdfScreenState();
}

class _PrescriptionPdfScreenState extends State<PrescriptionPdfScreen> {
  bool _generating = false;
  String _doctorName = '';
  String _diagnosis = '';
  String _notes = '';
  final _doctorController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _doctorController.dispose();
    _diagnosisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generatePdf() async {
    final medicines = context.read<MedicineProvider>().medicines
        .where((m) => m.isActive)
        .toList();
    final user = context.read<UserProvider>().currentUser;
    final patientName = user?.name ?? 'Patient';

    setState(() => _generating = true);

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => _buildHeader(patientName, dateStr),
          footer: (ctx) => _buildFooter(ctx),
          build: (ctx) => [
            _buildPatientInfo(patientName, dateStr),
            pw.SizedBox(height: 20),
            if (_diagnosisController.text.isNotEmpty) ...[
              _buildSection('Diagnosis / Condition', _diagnosisController.text),
              pw.SizedBox(height: 16),
            ],
            _buildMedicineTable(medicines),
            pw.SizedBox(height: 16),
            if (_notesController.text.isNotEmpty) ...[
              _buildSection('Doctor\'s Notes', _notesController.text),
              pw.SizedBox(height: 16),
            ],
            _buildFoodInstructions(medicines),
            pw.SizedBox(height: 24),
            _buildSignature(_doctorController.text),
            pw.SizedBox(height: 16),
            _buildDisclaimer(),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'MediTrack_Prescription_${DateFormat('yyyyMMdd').format(now)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  pw.Widget _buildHeader(String name, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 2, color: PdfColors.indigo)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MediTrack',
                  style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo)),
              pw.Text('Smart Medicine Reminder System',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('PRESCRIPTION',
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo)),
              pw.Text('Date: $date',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        'Page ${ctx.pageNumber} of ${ctx.pagesCount}  |  MediTrack',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildPatientInfo(String name, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.indigo200),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Patient Name',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                pw.Text(name,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          if (_doctorController.text.isNotEmpty)
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prescribed By',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Dr. ${_doctorController.text}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildSection(String title, String content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo)),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(content, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  pw.Widget _buildMedicineTable(List<Medicine> medicines) {
    if (medicines.isEmpty) {
      return pw.Text('No active medicines.',
          style: const pw.TextStyle(color: PdfColors.grey600));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Prescribed Medicines',
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 11),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
            4: pw.Alignment.center,
          },
          headers: ['Medicine', 'Dosage', 'Frequency', 'Food Timing', 'Times'],
          data: medicines.map((m) => [
            m.name,
            m.dosage,
            m.frequency,
            '${m.foodInstruction} food',
            m.times.join(', '),
          ]).toList(),
        ),
      ],
    );
  }

  pw.Widget _buildFoodInstructions(List<Medicine> medicines) {
    final beforeFood = medicines.where((m) => m.foodInstruction == 'before').toList();
    final afterFood = medicines.where((m) => m.foodInstruction == 'after').toList();
    final withFood = medicines.where((m) => m.foodInstruction == 'with').toList();

    if (beforeFood.isEmpty && afterFood.isEmpty && withFood.isEmpty) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Food Instructions',
            style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo)),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.orange200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (beforeFood.isNotEmpty)
                pw.Text(
                    '• Before food (30 min): ${beforeFood.map((m) => m.name).join(', ')}',
                    style: const pw.TextStyle(fontSize: 10)),
              if (withFood.isNotEmpty)
                pw.Text(
                    '• With food: ${withFood.map((m) => m.name).join(', ')}',
                    style: const pw.TextStyle(fontSize: 10)),
              if (afterFood.isNotEmpty)
                pw.Text(
                    '• After food (30 min): ${afterFood.map((m) => m.name).join(', ')}',
                    style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignature(String doctorName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 150,
              height: 1,
              color: PdfColors.grey700,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              doctorName.isNotEmpty ? 'Dr. $doctorName' : 'Doctor\'s Signature',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Authorized Physician',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'This prescription was generated by MediTrack for personal tracking. '
        'Always consult your licensed physician for medical decisions.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicines = context.watch<MedicineProvider>().medicines
        .where((m) => m.isActive)
        .toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Generate Prescription PDF'),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C7BFF), Color(0xFF9C6BFF)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prescription PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${medicines.length} active medicine${medicines.length != 1 ? 's' : ''} will be included',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Optional fields
            Text(
              'Optional Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            _buildTextField(
              controller: _doctorController,
              label: 'Doctor Name',
              hint: 'e.g. Dr. Smith',
              icon: Icons.person_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _diagnosisController,
              label: 'Diagnosis / Condition',
              hint: 'e.g. Hypertension, Diabetes',
              icon: Icons.medical_information_rounded,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _notesController,
              label: 'Additional Notes',
              hint: 'Any special instructions...',
              icon: Icons.note_rounded,
              isDark: isDark,
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Medicine preview
            Text(
              'Medicines to Include',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            if (medicines.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_rounded, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('No active medicines to include',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              )
            else
              ...medicines.map((med) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
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
                              Text(
                                '${med.dosage} • ${med.foodInstruction} food • ${med.times.join(', ')}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 20),
                      ],
                    ),
                  )),

            const SizedBox(height: 32),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: medicines.isEmpty || _generating ? null : _generatePdf,
                icon: _generating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: Text(
                  _generating ? 'Generating...' : 'Generate & Share PDF',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textDark,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
