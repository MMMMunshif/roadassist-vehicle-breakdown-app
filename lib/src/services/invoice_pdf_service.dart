import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/service_invoice.dart';

class InvoicePdfService {
  static Future<Uint8List> generate(ServiceInvoice invoice) async {
    final logo = await rootBundle.load('assets/images/roadassist_logo.png');
    final fontData = await rootBundle.load('assets/fonts/Manrope-Variable.ttf');
    final font = pw.Font.ttf(fontData);
    final doc = pw.Document(
      title: 'Service invoice ${invoice.number}',
      author: invoice.providerName,
      creator: 'RoadAssist',
      subject: 'Roadside service invoice',
    );
    final navy = PdfColor.fromHex('#0C285F');
    final blue = PdfColor.fromHex('#006AE8');
    final pale = PdfColor.fromHex('#EDF6FF');
    final gray = PdfColor.fromHex('#52627C');
    pw.Text text(
      String value, {
      double size = 10,
      bool bold = false,
      PdfColor? color,
    }) => pw.Text(
      value,
      style: pw.TextStyle(
        fontSize: size,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? navy,
        fontFallback: [font],
        lineSpacing: 3,
      ),
    );
    pw.Widget rule() =>
        pw.Divider(color: PdfColor.fromHex('#DCE7F4'), thickness: .6);
    pw.Widget pair(String label, String value, {bool strong = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: text(label, size: strong ? 14 : 10, bold: strong),
              ),
              pw.SizedBox(width: 14),
              text(value, size: strong ? 17 : 11, bold: strong),
            ],
          ),
        );
    pw.Widget section(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        text(label, bold: true, color: blue),
        pw.SizedBox(height: 6),
        text(value, size: 11),
      ],
    );
    const road =
        '<svg xmlns="http://www.w3.org/2000/svg" width="520" height="30" viewBox="0 0 520 30"><path d="M270 -10 C340 42 440 -28 530 23" fill="none" stroke="#e6f4ff" stroke-width="21"/><path d="M270 -10 C340 42 440 -28 530 23" fill="none" stroke="#ffffff" stroke-width="1.5" stroke-dasharray="9 9"/></svg>';
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(38, 30, 38, 32),
        theme: pw.ThemeData.withFont(base: font, bold: pw.Font.helveticaBold()),
        header: (context) => pw.Column(
          children: [
            pw.SvgImage(svg: road, width: 520, height: 30),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Image(
                      pw.MemoryImage(logo.buffer.asUint8List()),
                      width: 185,
                      height: 65,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      text('SERVICE INVOICE', size: 18, bold: true),
                      pw.SizedBox(height: 10),
                      text('Invoice: ${invoice.number}'),
                      text('Issued: ${invoice.dateLabel}'),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            rule(),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            rule(),
            text(
              'Service provided by ${invoice.providerName}. Invoice generated with RoadAssist.',
              size: 8,
              color: gray,
            ),
            pw.SizedBox(height: 4),
            text(
              'Job ${invoice.requestId} • Page ${context.pageNumber} of ${context.pagesCount}',
              size: 8,
              color: gray,
            ),
            pw.SvgImage(svg: road, width: 520, height: 25),
          ],
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: section(
                  'Service provider',
                  [
                    invoice.providerName,
                    if (invoice.providerPhone.isNotEmpty) invoice.providerPhone,
                  ].join('\n'),
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: section(
                  'Bill to',
                  [
                    invoice.driverName,
                    if (invoice.vehicle.isNotEmpty) invoice.vehicle,
                  ].join('\n'),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          rule(),
          pw.SizedBox(height: 10),
          section('Service performed', invoice.service),
          if (invoice.work.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            text(invoice.work, color: gray),
          ],
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: PdfColor.fromHex('#E0EAF4'),
                width: .5,
              ),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: pale),
                repeat: true,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: text('Description', bold: true),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(10),
                    child: text('Amount (LKR)', bold: true),
                  ),
                ],
              ),
              for (final charge in invoice.charges)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: text(charge.label),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: text(ServiceInvoice.money(charge.amount)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (invoice.breakdownNote.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            text(invoice.breakdownNote, size: 9, color: gray),
          ],
          pw.SizedBox(height: 12),
          pair('Subtotal', ServiceInvoice.money(invoice.subtotal)),
          pair('Discount', ServiceInvoice.money(invoice.discount)),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: pale,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pair(
              'Total',
              'LKR ${ServiceInvoice.money(invoice.total)}',
              strong: true,
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex(invoice.paid ? '#E5F7EF' : '#FFF4DE'),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: text(
              invoice.paymentLabel.toUpperCase(),
              bold: true,
              color: PdfColor.fromHex(invoice.paid ? '#087C53' : '#9B5C00'),
            ),
          ),
          pw.SizedBox(height: 6),
          text(
            invoice.paid
                ? 'Payment receipt confirmed by the service provider${invoice.paymentMethod.isEmpty ? '.' : ' (${invoice.paymentMethod}).'}'
                : 'Payment confirmation has not yet been recorded.',
            size: 9,
            color: gray,
          ),
          pw.SizedBox(height: 18),
          rule(),
          pw.SizedBox(height: 8),
          section('Warranty', invoice.warranty),
          pw.SizedBox(height: 18),
        ],
      ),
    );
    return doc.save();
  }

  /// Uses a system save chooser on mobile/desktop; browser downloads on web.
  static Future<bool> download(Uint8List bytes, String filename) async {
    final path = await FileSaver.instance.saveAs(
      name: filename.replaceFirst(RegExp(r'\.pdf$'), ''),
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
    return path != null;
  }

  static Future<bool> share(Uint8List bytes, String filename, {Rect? bounds}) =>
      Printing.sharePdf(bytes: bytes, filename: filename, bounds: bounds);
}
