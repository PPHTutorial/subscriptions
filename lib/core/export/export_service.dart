import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../features/subscriptions/domain/subscription.dart';

/// Service for exporting subscription data
class ExportService {
  /// Export subscriptions to CSV
  Future<File> exportToCsv(List<Subscription> subscriptions) async {
    final List<List<dynamic>> rows = [
      // Header row
      [
        'Service Name',
        'Category',
        'Cost',
        'Currency',
        'Billing Cycle',
        'Renewal Date',
        'Trial End Date',
        'Auto Renew',
        'Payment Method',
        'Reminder Days',
        'Notes',
      ],
    ];

    // Data rows
    for (final subscription in subscriptions) {
      rows.add([
        subscription.serviceName,
        subscription.category.displayName,
        subscription.cost.toStringAsFixed(2),
        subscription.currencyCode,
        subscription.billingLabel,
        DateFormat('yyyy-MM-dd').format(subscription.renewalDate),
        subscription.trialEndsOn != null
            ? DateFormat('yyyy-MM-dd').format(subscription.trialEndsOn!)
            : '',
        subscription.autoRenew ? 'Yes' : 'No',
        subscription.paymentMethod,
        subscription.reminderDays.join(', '),
        subscription.notes ?? '',
      ]);
    }

    // Convert to CSV string
    final csvString = const ListToCsvConverter().convert(rows);

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/subscriptions_$timestamp.csv');
    await file.writeAsString(csvString);

    return file;
  }

  /// Export subscriptions to PDF
  Future<File> exportToPdf(List<Subscription> subscriptions) async {
    final pdf = pw.Document();

    // Add a page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Text(
                'Subscriptions Export',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Total Subscriptions: ${subscriptions.length}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 30),

            // Summary table
            _buildSummaryTable(subscriptions),
            pw.SizedBox(height: 30),

            // Detailed list
            pw.Header(
              level: 1,
              child: pw.Text(
                'Subscription Details',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),

            // Subscription details
            ...subscriptions
                .map((subscription) => _buildSubscriptionCard(subscription)),
          ];
        },
      ),
    );

    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${directory.path}/subscriptions_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Build summary table for PDF
  pw.Widget _buildSummaryTable(List<Subscription> subscriptions) {
    final totalCost = subscriptions.fold<double>(
      0,
      (sum, sub) => sum + sub.cost,
    );
    final activeCount = subscriptions.where((s) => !s.isPastDue).length;
    final trialCount = subscriptions.where((s) => s.isTrial).length;

    return pw.Table(
      border: pw.TableBorder.all(),
      children: [
        pw.TableRow(
          children: [
            _buildTableCell('Total Subscriptions', isHeader: true),
            _buildTableCell('${subscriptions.length}'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Active Subscriptions', isHeader: true),
            _buildTableCell('$activeCount'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Trial Subscriptions', isHeader: true),
            _buildTableCell('$trialCount'),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Total Monthly Cost', isHeader: true),
            _buildTableCell(_formatCurrency(totalCost)),
          ],
        ),
      ],
    );
  }

  /// Build subscription card for PDF
  pw.Widget _buildSubscriptionCard(Subscription subscription) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            subscription.serviceName,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Category: ${subscription.category.displayName}'),
              pw.Text(
                  '${subscription.cost.toStringAsFixed(2)} ${subscription.currencyCode}'),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Billing: ${subscription.billingLabel}'),
              pw.Text('Auto Renew: ${subscription.autoRenew ? "Yes" : "No"}'),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Renewal Date: ${DateFormat('yyyy-MM-dd').format(subscription.renewalDate)}',
          ),
          if (subscription.trialEndsOn != null)
            pw.Text(
              'Trial Ends: ${DateFormat('yyyy-MM-dd').format(subscription.trialEndsOn!)}',
            ),
          pw.SizedBox(height: 4),
          pw.Text('Payment Method: ${subscription.paymentMethod}'),
          if (subscription.notes != null && subscription.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Notes: ${subscription.notes}'),
          ],
        ],
      ),
    );
  }

  /// Build table cell for PDF
  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Format currency for display
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  /// Share exported file
  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Subscriptions Export',
      text: 'My subscriptions export from Subscriptions App',
    );
  }
}
