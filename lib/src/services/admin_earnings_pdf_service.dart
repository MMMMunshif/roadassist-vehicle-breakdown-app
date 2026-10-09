import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/admin_earnings_report.dart';

class AdminEarningsPdfService {
  static Future<Uint8List> generate(AdminEarningsReport report) async {
    final logo = await rootBundle.load('assets/images/roadassist_logo.png');
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Variable.ttf'),
    );
    final decodedLogo = img.decodeImage(logo.buffer.asUint8List())!;
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
          theme: pw.ThemeData.withFont(base: font, bold: font),
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.SvgImage(svg: _roadBackground),
          ),
        ),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Image(logoImage, width: 175, height: 55, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 12),
            text('Provider Earnings', size: 23),
            pw.SizedBox(height: 6),
            text('${report.period} | Monthly service report | LKR'),
            text('Generated: ${report.generatedLabel}', size: 8),
            text(
              'Report: RA-${report.period.replaceAll(' ', '-')} | ${report.jobs} completed jobs',
              size: 8,
            ),
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
          pw.Row(
            children: [
              pw.Expanded(
                child: _metric('Service earnings', report.billedCents, navy),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _metric(
                  'Confirmed payments',
                  report.confirmedCents,
                  PdfColor.fromHex('#008C78'),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _metric(
                  'Unconfirmed',
                  report.billedCents - report.confirmedCents,
                  navy,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          text('Provider summary / Monthly earnings', size: 15),
          pw.SizedBox(height: 10),
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
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#EAF3FB'),
            ),
            headerStyle: pw.TextStyle(
              color: navy,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: 10, color: navy),
            cellPadding: const pw.EdgeInsets.all(9),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            rowDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5FAFE')),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#DBE7F1'),
              width: .5,
            ),
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
            for (final job in report.details) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(
                    color: PdfColor.fromHex('#DBE7F1'),
                    width: .6,
                  ),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          text(
                            AdminEarningsReport.sriLanka(
                                  job['completedAt'] as DateTime,
                                )
                                .toIso8601String()
                                .substring(0, 16)
                                .replaceFirst('T', ' '),
                          ),
                          pw.SizedBox(height: 4),
                          text(
                            report.rows
                                .firstWhere(
                                  (row) => row.providerId == job['providerId'],
                                )
                                .name,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          text(
                            'Driver: ${job['driverName'] ?? 'Not recorded'}',
                          ),
                          text(
                            'Vehicle: ${job['registration'] ?? 'Not recorded'}',
                          ),
                          pw.SizedBox(height: 4),
                          text(
                            job['issues'] is List
                                ? (job['issues'] as List).join(', ')
                                : job['issue']?.toString() ??
                                      'Service not recorded',
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          text('Final bill', size: 8),
                          text(
                            AdminEarningsReport.money(
                              job['amountCents'] as int,
                            ),
                            size: 13,
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            job['providerConfirmedPayment'] == true
                                ? 'Payment confirmed'
                                : 'Unconfirmed',
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: job['providerConfirmedPayment'] == true
                                  ? PdfColor.fromHex('#008C78')
                                  : navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
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

  static pw.Widget _metric(String label, int cents, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(9),
          border: pw.Border.all(color: PdfColor.fromHex('#DBE7F1'), width: .6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 8),
            pw.Text(
              AdminEarningsReport.money(cents),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );

  static String get _roadBackground {
    final curves = StringBuffer();
    for (var i = 0; i < 9; i++) {
      final x = 595 * (.12 + i * .15);
      curves.write(
        '<path d="M $x 0 C ${x + 110} 109 ${x - 150} 168 ${x - 40} 303 C ${x + 100} 438 ${x - 90} 631 ${x + 50} 842" fill="none" stroke="#E0F0FA" stroke-width="1"/>',
      );
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" width="595" height="842" viewBox="0 0 595 842"><rect width="595" height="842" fill="#F7FBFF"/><path d="M464 0 C690 101 286 135 535 236" fill="none" stroke="#E4F6FC" stroke-width="28"/><path d="M464 0 C690 101 286 135 535 236" fill="none" stroke="#BDE6F8" stroke-width="1.5" stroke-dasharray="8 11"/>$curves</svg>';
  }
}

