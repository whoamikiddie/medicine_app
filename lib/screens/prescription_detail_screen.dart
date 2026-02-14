import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_theme.dart';
import '../models/prescription.dart';
import '../services/prescription_service.dart';

class PrescriptionDetailScreen extends StatelessWidget {
  final Prescription prescription;

  const PrescriptionDetailScreen({super.key, required this.prescription});

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
          title: const Text('Prescription Details'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? Colors.white : AppColors.textDark,
          actions: [
            // Generate PDF
            IconButton(
              onPressed: () => _generatePDF(context),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export as PDF',
            ),
            // Delete
            IconButton(
              onPressed: () => _showDeleteDialog(context),
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              tooltip: 'Delete',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              if (prescription.imageUrl != null) _buildImageCard(isDark),

              const SizedBox(height: 16),

              // Title card
              _buildInfoCard(isDark, [
                _buildInfoRow(isDark, Icons.description_rounded,
                    'Title', prescription.title),
                if (prescription.doctorName != null &&
                    prescription.doctorName!.isNotEmpty)
                  _buildInfoRow(isDark, Icons.person_rounded,
                      'Doctor', 'Dr. ${prescription.doctorName}'),
                if (prescription.hospitalName != null &&
                    prescription.hospitalName!.isNotEmpty)
                  _buildInfoRow(isDark, Icons.local_hospital_rounded,
                      'Hospital', prescription.hospitalName!),
                _buildInfoRow(
                  isDark,
                  Icons.calendar_today_rounded,
                  'Date Issued',
                  DateFormat('dd MMMM yyyy').format(prescription.dateIssued),
                ),
              ]),

              const SizedBox(height: 16),

              // Diagnosis
              if (prescription.diagnosis != null &&
                  prescription.diagnosis!.isNotEmpty) ...[
                _buildSectionTitle('Diagnosis', isDark),
                const SizedBox(height: 8),
                _buildContentCard(isDark, prescription.diagnosis!,
                    Icons.medical_information_rounded, const Color(0xFFE91E63)),
                const SizedBox(height: 16),
              ],

              // Medicines
              if (prescription.medicines.isNotEmpty) ...[
                _buildSectionTitle(
                    'Medicines (${prescription.medicines.length})', isDark),
                const SizedBox(height: 8),
                ...prescription.medicines
                    .map((med) => _buildMedicineItem(isDark, med)),
                const SizedBox(height: 16),
              ],

              // Notes
              if (prescription.notes != null &&
                  prescription.notes!.isNotEmpty) ...[
                _buildSectionTitle('Notes', isDark),
                const SizedBox(height: 8),
                _buildContentCard(isDark, prescription.notes!,
                    Icons.notes_rounded, const Color(0xFF00B4D8)),
                const SizedBox(height: 16),
              ],

              // Generate PDF button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _generatePDF(context),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text(
                    'Export as PDF',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Share button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _generatePDF(context, share: true),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text(
                    'Share Prescription',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.network(
          prescription.imageUrl!,
          width: double.infinity,
          height: 250,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 250,
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 200,
              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image_rounded,
                      color: AppColors.textMuted, size: 48),
                  SizedBox(height: 8),
                  Text('Could not load image',
                      style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: children
            .asMap()
            .entries
            .map((entry) => Column(
                  children: [
                    entry.value,
                    if (entry.key < children.length - 1)
                      Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100,
                        height: 20,
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInfoRow(
      bool isDark, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textDark,
      ),
    );
  }

  Widget _buildContentCard(
      bool isDark, String content, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineItem(bool isDark, String medicine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.cardGradient : null,
        color: isDark ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.medication_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            medicine,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate and show/share PDF prescription
  Future<void> _generatePDF(BuildContext context, {bool share = false}) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'MEDICAL PRESCRIPTION',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'MediTrack App',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Doctor & Hospital info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (prescription.doctorName != null &&
                          prescription.doctorName!.isNotEmpty)
                        pw.Text(
                          'Dr. ${prescription.doctorName}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (prescription.hospitalName != null &&
                          prescription.hospitalName!.isNotEmpty)
                        pw.Text(
                          prescription.hospitalName!,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(prescription.dateIssued)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 16),

              // Title
              pw.Text(
                prescription.title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),

              // Diagnosis
              if (prescription.diagnosis != null &&
                  prescription.diagnosis!.isNotEmpty) ...[
                pw.Text(
                  'Diagnosis:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  prescription.diagnosis!,
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 16),
              ],

              // Rx Symbol
              pw.Text(
                'Rx',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),

              // Medicines
              if (prescription.medicines.isNotEmpty)
                ...prescription.medicines.asMap().entries.map((entry) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Text(
                          '${entry.key + 1}.',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          entry.value,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }),

              pw.SizedBox(height: 16),

              // Notes
              if (prescription.notes != null &&
                  prescription.notes!.isNotEmpty) ...[
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  prescription.notes!,
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated by MediTrack',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (share) {
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'prescription_${prescription.id.substring(0, 8)}.pdf',
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => pdf.save(),
        name: 'Prescription - ${prescription.title}',
      );
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prescription?'),
        content: const Text(
          'This will permanently delete this prescription and its image. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
              await PrescriptionService().deletePrescription(
                userId,
                prescription.id,
                prescription.imageUrl,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prescription deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
