part of '../screens.dart';

Future<Map<String, dynamic>?> requestFinalBill(
  BuildContext context,
  Map<String, dynamic> data,
) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _FinalBillForm(data: data),
);

class _BillItemFields {
  _BillItemFields([Map<String, dynamic>? data]) {
    label.text = data?['label']?.toString() ?? '';
    reason.text = data?['reason']?.toString() ?? '';
    amount.text = data?['amount']?.toString() ?? '';
  }
  final label = TextEditingController(),
      reason = TextEditingController(),
      amount = TextEditingController();
  void dispose() {
    label.dispose();
    reason.dispose();
    amount.dispose();
  }
}

class _FinalBillForm extends StatefulWidget {
  const _FinalBillForm({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_FinalBillForm> createState() => _FinalBillFormState();
}

class _FinalBillFormState extends State<_FinalBillForm> {
  final form = GlobalKey<FormState>();
  late final inspection = TextEditingController(
    text: '${widget.data['inspectionFee'] ?? 0}',
  );
  late final labour = TextEditingController(
    text: '${widget.data['serviceFee'] ?? 0}',
  );
  late final items = (widget.data['billItems'] as List? ?? [])
      .whereType<Map>()
      .map((i) => _BillItemFields(i.cast<String, dynamic>()))
      .toList();
  @override
  void dispose() {
    inspection.dispose();
    labour.dispose();
    for (final i in items) {
      i.dispose();
    }
    super.dispose();
  }

  int get total =>
      (widget.data['dispatchFee'] as num).toInt() +
      (int.tryParse(inspection.text) ?? 0) +
      (int.tryParse(labour.text) ?? 0) +
      items.fold<int>(0, (sum, i) => sum + (int.tryParse(i.amount.text) ?? 0));
  Widget moneyField(
    TextEditingController controller,
    String label, {
    bool positive = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(8),
    ],
    decoration: InputDecoration(labelText: label, prefixText: 'Rs. '),
    onChanged: (_) => setState(() {}),
    validator: (value) {
      final n = int.tryParse(value ?? '');
      return n == null || n < (positive ? 1 : 0) || n > 10000000
          ? 'Enter a valid amount'
          : null;
    },
  );
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Final service bill',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text('Visit fee (fixed): Rs. ${widget.data['dispatchFee']}'),
          const SizedBox(height: 12),
          moneyField(inspection, 'Inspection fee'),
          const SizedBox(height: 12),
          moneyField(labour, 'Labour / repair fee'),
          for (final item in items) ...[
            const Divider(height: 28),
            Row(
              children: [
                const Expanded(child: Text('Part / additional charge')),
                IconButton(
                  tooltip: 'Remove charge',
                  onPressed: () => setState(() {
                    items.remove(item);
                    item.dispose();
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextFormField(
              controller: item.label,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Part or item name'),
              validator: (v) =>
                  (v ?? '').trim().length < 2 ? 'Enter the item name' : null,
            ),
            TextFormField(
              controller: item.reason,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Why it was replaced / charged',
              ),
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Explain the charge' : null,
            ),
            moneyField(item.amount, 'Item amount', positive: true),
          ],
          const SizedBox(height: 12),
          if (items.length < 10)
            OutlinedButton.icon(
              onPressed: () => setState(() => items.add(_BillItemFields())),
              icon: const Icon(Icons.add),
              label: const Text('Add part / additional charge'),
            ),
          const SizedBox(height: 16),
          Text(
            'Total: Rs. ${ServiceInvoice.money(total)}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'The driver reviews this bill once, then accepts and pays. Explain every replacement or additional charge.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              if (total > 10000000) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('The bill exceeds the supported total.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, <String, dynamic>{
                'inspectionFee': int.parse(inspection.text),
                'labourFee': int.parse(labour.text),
                'items': items
                    .map(
                      (i) => <String, dynamic>{
                        'label': i.label.text.trim(),
                        'reason': i.reason.text.trim(),
                        'amount': int.parse(i.amount.text),
                      },
                    )
                    .toList(),
              });
            },
            icon: const Icon(Icons.send_outlined),
            label: const Text('Send Final Bill'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to work'),
          ),
        ],
      ),
    ),
  );
}

class FinalBillBreakdown extends StatelessWidget {
  const FinalBillBreakdown({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in <(String, Object?)>[
        ('Visit fee', data['dispatchFee']),
        ('Inspection', data['inspectionFee']),
        ('Labour / repair', data['serviceFee']),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(row.$1)),
              Text('Rs. ${row.$2 ?? 0}'),
            ],
          ),
        ),
      for (final item in (data['billItems'] as List? ?? []).whereType<Map>())
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item['label']?.toString() ?? 'Additional charge',
                    ),
                  ),
                  Text('Rs. ${item['amount']}'),
                ],
              ),
              Text(
                item['reason']?.toString() ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
    ],
  );
}
