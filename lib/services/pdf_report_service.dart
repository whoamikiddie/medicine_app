import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';

class PdfReportService {
  /// Generate and share a PDF adherence report
  static Future<void> generateAndShare({
    required List<Medicine> medicines,
    required int takenToday,
    required int missedToday,
    required double adherencePercentage,
    required List<Map<String, dynamic>> weeklyHistory,
    String patientName = 'Patient',
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(dateStr, patientName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildAdherenceSummary(adherencePercentage, takenToday, missedToday),
          pw.SizedBox(height: 20),
          _buildMedicineTable(medicines),
          pw.SizedBox(height: 20),
          _buildWeeklyHistory(weeklyHistory),
          pw.SizedBox(height: 20),
          _buildDisclaimer(),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'medicine_report_${DateFormat('yyyy-MM-dd').format(now)}.pdf',
    );
  }

  static pw.Widget _buildHeader(String date, String name) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 2, color: PdfColors.indigo),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MediTrack',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Health & Adherence Report',
                style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Patient: $name',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: $date',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}  |  MediTrack',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
      ),
    );
  }

  static pw.Widget _buildAdherenceSummary(
      double adherence, int taken, int missed) {
    final riskLevel = adherence >= 80
        ? 'LOW'
        : adherence >= 50
            ? 'MEDIUM'
            : 'HIGH';
    final riskColor = adherence >= 80
        ? PdfColors.green700
        : adherence >= 50
            ? PdfColors.orange700
            : PdfColors.red700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.indigo200),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.indigo50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Today's Adherence Summary",
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statBox('Adherence', '${adherence.toInt()}%', PdfColors.indigo),
              _statBox('Taken', '$taken', PdfColors.green700),
              _statBox('Missed', '$missed', PdfColors.red700),
              _statBox('Risk', riskLevel, riskColor),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildMedicineTable(List<Medicine> medicines) {
    final activeMeds = medicines.where((m) => m.isActive).toList();
    if (activeMeds.isEmpty) {
      return pw.Text('No active medicines.',
          style: const pw.TextStyle(color: PdfColors.grey600));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Active Medicines',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 11,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.center,
            2: pw.Alignment.center,
            3: pw.Alignment.center,
          },
          headers: ['Medicine', 'Dosage', 'Frequency', 'Food Timing'],
          data: activeMeds
              .map((m) => [
                    m.name,
                    m.dosage,
                    m.frequency,
                    '${m.foodInstruction} food',
                  ])
              .toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildWeeklyHistory(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return pw.Text('No weekly history available.',
          style: const pw.TextStyle(color: PdfColors.grey600));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '7-Day Adherence History',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            fontSize: 11,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo400),
          cellStyle: const pw.TextStyle(fontSize: 10),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          headers: ['Date', 'Taken', 'Total', 'Adherence %'],
          data: history.map((entry) {
            final taken = (entry['taken'] ?? 0) as num;
            final total = (entry['total'] ?? 0) as num;
            final pct = total > 0 ? (taken / total * 100).toInt() : 0;
            return [
              entry['date'] ?? '-',
              '$taken',
              '$total',
              '$pct%',
            ];
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(color: PdfColors.amber200),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'Disclaimer: This report is generated by the MediTrack app for personal tracking purposes only. '
        'It does not constitute medical advice. Please consult your doctor for any medical decisions.',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }
}
