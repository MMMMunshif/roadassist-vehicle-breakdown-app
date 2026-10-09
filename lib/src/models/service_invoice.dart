import 'completion_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceCharge {
  const InvoiceCharge(this.label, this.amount);
  final String label;
  final int amount;
}

/// A read-only view of recorded charges; never invents a price breakdown.
class ServiceInvoice {
  ServiceInvoice._({
    required this.requestId,
    required this.number,
    required this.issuedAt,
    required this.providerName,
    required this.providerPhone,
    required this.driverName,
    required this.vehicle,
    required this.service,
    required this.work,
    required this.charges,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paid,
    required this.paymentMethod,
    required this.warranty,
    required this.breakdownNote,
  });

  factory ServiceInvoice.fromRequest(
    String id,
    Map<String, dynamic> data, {
    Map<String, dynamic>? approvedOffer,
  }) {
    if (data['status'] != 'completed') {
      throw StateError('The invoice is available after service completion.');
    }
    int? amount(String key) {
      final value = data[key];
      if (value is! num ||
          !value.isFinite ||
          value < 0 ||
          value != value.roundToDouble())
        return null;
      return value.toInt();
    }

    final approved = amount('estimatedCost');
    if (data['finalCost'] != null && amount('finalCost') == null) {
      throw StateError('The recorded final amount is invalid.');
    }
    final total = amount('finalCost') ?? approved;
    if (total == null)
      throw StateError('The final service amount has not been recorded.');
    final serviceFee = amount('serviceFee');
    final travel = amount('dispatchFee') ?? amount('travelFee');
    final other = amount('extraFee');
    final detailTotal = (serviceFee ?? 0) + (travel ?? 0) + (other ?? 0);
    final subtotal = approved != null && approved >= total ? approved : total;
    final itemized =
        detailTotal == subtotal &&
        (serviceFee != null || travel != null || other != null);
    final charges = itemized
        ? <InvoiceCharge>[
            if (serviceFee != null)
              InvoiceCharge('Service / labour', serviceFee),
            if (travel != null) InvoiceCharge('Travel / dispatch', travel),
            if (other != null && other > 0)
              InvoiceCharge('Parts / other approved charges', other),
          ]
        : <InvoiceCharge>[InvoiceCharge('Recorded service charge', subtotal)];
    final offer = approvedOffer ?? data;
    final days = offer['warrantyDays'];
    final terms = _text(offer['warrantyTerms']);
    final warranty = days is num && days > 0
        ? '${days.toInt()} days${terms.isEmpty ? '. Coverage terms were not recorded.' : ' — $terms'}'
        : days == 0
        ? 'No service warranty offered.'
        : 'Warranty was not recorded for this service.';
    final issues =
        (data['issues'] as List?)
            ?.whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(', ') ??
        '';
    return ServiceInvoice._(
      requestId: id,
      number: _text(data['invoiceNumber']).isEmpty
          ? 'RA-$id'
          : _text(data['invoiceNumber']),
      issuedAt: _date(data['invoiceIssuedAt']) ?? _date(data['completedAt']),
      providerName: _first([
        data['providerBusinessName'],
        data['providerName'],
      ], 'Service provider'),
      providerPhone: _text(data['providerPhone']),
      driverName: _first([data['driverName']], 'Driver'),
      vehicle: [
        data['vehicleType'],
        data['modelYear'],
        data['registration'],
      ].map(_text).where((s) => s.isNotEmpty).join(' • '),
      service: issues.isNotEmpty
          ? issues
          : _first([
              data['issue'],
              data['assistanceType'],
            ], 'Roadside assistance'),
      work: [
        CompletionReport.description(data),
        _first([data['serviceNotes'], data['providerDiagnosis']], ''),
      ].where((v) => v.isNotEmpty).join('\n\n'),
      charges: List.unmodifiable(charges),
      subtotal: subtotal,
      discount: subtotal - total,
      total: total,
      paid: data['providerConfirmedPayment'] == true,
      paymentMethod: _text(data['paymentMethod']),
      warranty: warranty,
      breakdownNote: itemized
          ? ''
          : 'A complete itemized breakdown was not recorded for this service.',
    );
  }

  static String _text(Object? value) => value is String ? value.trim() : '';
  static String _first(List<Object?> values, String fallback) =>
      values.map(_text).firstWhere((s) => s.isNotEmpty, orElse: () => fallback);
  static DateTime? _date(Object? value) => value is Timestamp
      ? value.toDate().toLocal()
      : value is DateTime
      ? value.toLocal()
      : null;
  final String requestId,
      number,
      providerName,
      providerPhone,
      driverName,
      vehicle,
      service,
      work;
  final DateTime? issuedAt;
  final List<InvoiceCharge> charges;
  final int subtotal, discount, total;
  final bool paid;
  final String paymentMethod, warranty, breakdownNote;
  String get paymentLabel => paid ? 'Paid' : 'Payment pending';
  String get dateLabel {
    final date = issuedAt;
    if (date == null) return 'Date not recorded';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String get filename =>
      'RoadAssist-Invoice-${requestId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.pdf';
  static String money(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}
