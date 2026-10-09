part of '../../screens.dart';

/// Shared on-screen bill mirrors the PDF's recorded amounts and payment state.
class InvoiceBillView extends StatelessWidget {
  const InvoiceBillView({
    super.key,
    required this.invoice,
    this.onDownload,
    this.onShare,
    this.busy = false,
  });
  final ServiceInvoice invoice;
  final VoidCallback? onDownload, onShare;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget label(String value) =>
        Text(value, style: _providerText(context, size: 12, muted: true));
    Widget heading(String value) => Text(
      value,
      style: _providerText(context, size: 16, weight: FontWeight.w700),
    );
    Widget amount(String title, int value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: _providerText(
                context,
                size: strong ? 16 : 14,
                weight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              '${strong ? 'LKR ' : ''}${ServiceInvoice.money(value)}',
              textAlign: TextAlign.right,
              style: _providerText(
                context,
                size: strong ? 20 : 14,
                weight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    Widget party(String title, String name, String detail) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(title),
        const SizedBox(height: 6),
        heading(name),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(detail, style: _providerText(context, size: 14, muted: true)),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandMark(size: 32),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'RoadAssist',
                      style: _providerText(
                        context,
                        size: 20,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              StatusPill(
                label: invoice.paymentLabel,
                tone: invoice.paid ? RaTone.success : RaTone.warning,
              ),
              const SizedBox(height: 14),
              label('SERVICE INVOICE'),
              const SizedBox(height: 4),
              Text(
                invoice.number,
                style: _providerText(
                  context,
                  size: 18,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              label('Issued ${invoice.dateLabel}'),
              const SizedBox(height: 4),
              label('Job ${invoice.requestId}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RaProviderCard(
          child: LayoutBuilder(
            builder: (context, box) {
              final provider = party(
                'Service provider',
                invoice.providerName,
                invoice.providerPhone,
              );
              final driver = party(
                'Bill to',
                invoice.driverName,
                invoice.vehicle,
              );
              if (box.maxWidth < 380 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [provider, const Divider(height: 28), driver],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: provider),
                  const SizedBox(width: 24),
                  Expanded(child: driver),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('Service performed'),
              const SizedBox(height: 6),
              heading(invoice.service),
              if (invoice.work.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  invoice.work,
                  style: _providerText(context, size: 14, muted: true),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading('Itemized charges'),
              const SizedBox(height: 4),
              label('Amounts in LKR'),
              const SizedBox(height: 8),
              for (final charge in invoice.charges)
                amount(charge.label, charge.amount),
              if (invoice.breakdownNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                label(invoice.breakdownNote),
              ],
              const Divider(height: 24),
              amount('Subtotal', invoice.subtotal),
              amount('Discount', invoice.discount),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: amount('Total', invoice.total, strong: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RaProviderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('Warranty'),
              const SizedBox(height: 6),
              Text(
                invoice.warranty,
                style: _providerText(context, size: 14, muted: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : onDownload,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(busy ? 'Preparing PDF…' : 'Download PDF'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onShare,
          icon: const Icon(Icons.share_outlined),
          label: const Text('Share PDF'),
        ),
        const SizedBox(height: 12),
        label(
          'Service provided by ${invoice.providerName}. Invoice generated with RoadAssist.',
        ),
      ],
    );
  }
}
