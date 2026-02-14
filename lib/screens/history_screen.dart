import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_theme.dart';
import '../providers/medicine_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final provider = context.read<MedicineProvider>();
    final days = _dateRange.end.difference(_dateRange.start).inDays + 1;
    _history = await provider.getAdherenceHistory(days);
    setState(() => _loading = false);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E2E),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadHistory();
    }
  }

  /// Build list of dose entries from history data
  List<_DoseEntry> _buildEntries(bool takenOnly) {
    final provider = context.read<MedicineProvider>();
    final medicines = provider.medicines;
    final entries = <_DoseEntry>[];

    for (final dayData in _history) {
      final dateStr = dayData['date']?.toString() ?? '';
      DateTime? date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        continue;
      }

      // Check if date is in range
      final dayStart = DateTime(date.year, date.month, date.day);
      final rangeStart = DateTime(
          _dateRange.start.year, _dateRange.start.month, _dateRange.start.day);
      if (dayStart.isBefore(rangeStart)) continue;

      dayData.forEach((key, value) {
        if (key == 'date') return;
        final parts = key.split('_');
        if (parts.length < 2) return;

        final medicineId = parts.sublist(0, parts.length - 1).join('_');
        final time = parts.last;
        final taken = value == true;

        if (takenOnly && !taken) return;
        if (!takenOnly && taken) return;

        // Find medicine name
        final med = medicines.where((m) => m.id == medicineId).firstOrNull;
        final name = med?.name ?? 'Unknown';
        final dosage = med?.dosage ?? '';

        entries.add(_DoseEntry(
          date: date!,
          medicineName: name,
          dosage: dosage,
          time: time,
          taken: taken,
        ));
      });
    }

    // Sort by date descending
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<void> _exportPdf() async {
    final takenEntries = _buildEntries(true);
    final missedEntries = _buildEntries(false);
    final dateFormat = DateFormat('MMM dd, yyyy');

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Medicine History Report',
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
            ),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          // Summary
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat('Taken', '${takenEntries.length}', PdfColors.green),
                _pdfStat(
                    'Missed', '${missedEntries.length}', PdfColors.red),
                _pdfStat(
                  'Adherence',
                  takenEntries.length + missedEntries.length > 0
                      ? '${(takenEntries.length / (takenEntries.length + missedEntries.length) * 100).toStringAsFixed(0)}%'
                      : 'N/A',
                  PdfColors.blue,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Taken section
          if (takenEntries.isNotEmpty) ...[
            pw.Text('Taken',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfTable(takenEntries, dateFormat),
            pw.SizedBox(height: 16),
          ],

          // Missed section
          if (missedEntries.isNotEmpty) ...[
            pw.Text('Missed',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _pdfTable(missedEntries, dateFormat),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Medicine_History_${DateFormat('yyyyMMdd').format(DateTime.now())}',
    );
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: color)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _pdfTable(List<_DoseEntry> entries, DateFormat fmt) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _pdfCell('Date', bold: true),
            _pdfCell('Medicine', bold: true),
            _pdfCell('Dosage', bold: true),
            _pdfCell('Time', bold: true),
          ],
        ),
        ...entries.map((e) => pw.TableRow(children: [
              _pdfCell(fmt.format(e.date)),
              _pdfCell(e.medicineName),
              _pdfCell(e.dosage),
              _pdfCell(e.time),
            ])),
      ],
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd');

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppColors.darkGradient : null,
        color: isDark ? null : AppColors.lightBg,
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'History',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                  const Spacer(),
                  // Export PDF
                  IconButton(
                    onPressed: _exportPdf,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Date range selector
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      '${dateFormat.format(_dateRange.start)} — ${dateFormat.format(_dateRange.end)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                tabs: const [
                  Tab(text: 'Taken'),
                  Tab(text: 'Missed'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildList(true, isDark),
                        _buildList(false, isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(bool takenOnly, bool isDark) {
    final entries = _buildEntries(takenOnly);

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              takenOnly
                  ? Icons.check_circle_outline_rounded
                  : Icons.warning_amber_rounded,
              size: 64,
              color: AppColors.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              takenOnly ? 'No doses taken yet' : 'No missed doses',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<_DoseEntry>>{};
    final dateFormat = DateFormat('EEE, MMM dd yyyy');
    for (final entry in entries) {
      final key = dateFormat.format(entry.date);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final dateKey = grouped.keys.elementAt(index);
          final dayEntries = grouped[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  dateKey,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              // Entries for this date
              ...dayEntries.map((entry) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: entry.taken
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: entry.taken
                                ? AppColors.success.withValues(alpha: 0.15)
                                : AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            entry.taken
                                ? Icons.check_rounded
                                : Icons.close_rounded,
                            color: entry.taken
                                ? AppColors.success
                                : AppColors.error,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.medicineName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${entry.dosage} • ${entry.time}',
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
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: entry.taken
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.taken ? 'Taken' : 'Missed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: entry.taken
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _DoseEntry {
  final DateTime date;
  final String medicineName;
  final String dosage;
  final String time;
  final bool taken;

  _DoseEntry({
    required this.date,
    required this.medicineName,
    required this.dosage,
    required this.time,
    required this.taken,
  });
}
