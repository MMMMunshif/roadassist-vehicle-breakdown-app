import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/admin_earnings_report.dart';

class AdminEarningsPdfService {
  static Future<Uint8List> generate(AdminEarningsReport report) async {
    final logo = await rootBundle.load('assets/images/roadassist_logo.png');
    final background = await rootBundle.load(
      'assets/images/welcome_background_light.png',
    );
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Manrope-Variable.ttf'),
    );
    final decodedBackground = img.decodeImage(background.buffer.asUint8List())!;
    final decodedLogo = img.decodeImage(logo.buffer.asUint8List())!;
    final backgroundImage = pw.MemoryImage(
      img.encodeJpg(img.copyResize(decodedBackground, width: 900), quality: 70),
    );
    final logoImage = pw.MemoryImage(
      img.encodePng(img.copyResize(decodedLogo, width: 600)),
    );
    final navy = PdfColor.fromHex('#0C285F'),
        blue = PdfColor.fromHex('#006AE8');
    final doc = pw.Document(
      title: 'Provider earnings - ${report.period}',
      author: 'RoadAssist',
      creator: 'RoadAssist Admin',
    );
    pw.Widget text(String value, {double size = 10}) => pw.Text(
      value,
      style: pw.TextStyle(fontSize: size, color: navy),
    );
    doc.addPage(
      pw.MultiPage(
        maxPages: 2000,
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: font),
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Opacity(
              opacity: .08,
              child: pw.Image(
                backgroundImage,
                fit: pw.BoxFit.cover,
                width: PdfPageFormat.a4.width,
                height: PdfPageFormat.a4.height,
              ),
            ),
          ),
        ),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logoImage, width: 175, height: 55, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 12),
            text('PROVIDER EARNINGS REPORT', size: 20),
            pw.SizedBox(height: 6),
            text('Period: ${report.period} | Currency: LKR'),
            text('Generated: ${report.generatedLabel}'),
            pw.Divider(color: blue),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Column(
          children: [
            pw.Divider(color: blue),
            text(
              'RoadAssist | Confidential admin report | Page ${context.pageNumber} of ${context.pagesCount}',
              size: 8,
            ),
          ],
        ),
        build: (_) => [
          text('Completed jobs: ${report.jobs}', size: 13),
          pw.SizedBox(height: 6),
          text(
            'Total service earnings: ${AdminEarningsReport.money(report.billedCents)}',
            size: 16,
          ),
          pw.SizedBox(height: 6),
          text(
            'Provider-confirmed payments: ${AdminEarningsReport.money(report.confirmedCents)}',
          ),
          text(
            'Unconfirmed amount: ${AdminEarningsReport.money(report.billedCents - report.confirmedCents)}',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Provider details',
              'Month',
              'Jobs',
              'Final bills (LKR)',
              'Confirmed (LKR)',
            ],
            data: [
              for (final row in report.rows)
                [
                  [
                    row.name,
                    'Email: ${row.email.isEmpty ? 'Not available' : row.email}',
                    'Phone: ${row.phone.isEmpty ? 'Not available' : row.phone}',
                  ].join('\n'),
                  row.month,
                  '${row.jobs}',
                  (row.billedCents / 100).toStringAsFixed(2),
                  (row.confirmedCents / 100).toStringAsFixed(2),
                ],
            ],
            headerDecoration: pw.BoxDecoration(color: blue),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.all(7),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(.6),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.4),
            },
          ),
          if (report.details.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            text('Completed job breakdown', size: 15),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'Completed / Provider',
                'Driver / Vehicle',
                'Service',
                'Final bill (LKR)',
                'Payment',
              ],
              data: [
                for (final job in report.details)
                  [
                    '${AdminEarningsReport.sriLanka(job['completedAt'] as DateTime).toIso8601String().substring(0, 16).replaceFirst('T', ' ')}\n${report.rows.firstWhere((row) => row.providerId == job['providerId']).name}',
                    '${job['driverName'] ?? 'Driver name not recorded'}\n${job['registration'] ?? 'Registration not recorded'}',
                    job['issues'] is List
                        ? (job['issues'] as List).join(', ')
                        : job['issue']?.toString() ?? 'Service not recorded',
                    ((job['amountCents'] as int) / 100).toStringAsFixed(2),
                    job['providerConfirmedPayment'] == true
                        ? 'Confirmed'
                        : 'Unconfirmed',
                  ],
              ],
              headerDecoration: pw.BoxDecoration(color: blue),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ],
          pw.SizedBox(height: 16),
          text(
            'Service earnings are completed final bill totals, not app revenue or profit. Payment confirmation is recorded by providers and is not bank verification. Months use Sri Lanka time (UTC+05:30).',
          ),
          pw.SizedBox(height: 8),
          text(
            'Excluded invalid/missing final bill or provider records: ${report.excluded}. Jobs without a completion timestamp are outside this dated report. Figures reflect records read at generation time.',
          ),
          if (report.rows.isEmpty)
            text('No eligible completed jobs for this period.'),
        ],
      ),
    );
    return doc.save();
  }
}
