part of '../screens.dart';

class ProviderCorrectionDraft {
  const ProviderCorrectionDraft(this.documents, this.reason);
  final List<String> documents;
  final String reason;
}

class ProviderCorrectionDialog extends StatefulWidget {
  const ProviderCorrectionDialog({super.key, required this.documentKeys});
  final List<String> documentKeys;
  @override
  State<ProviderCorrectionDialog> createState() =>
      _ProviderCorrectionDialogState();
}

class _ProviderCorrectionDialogState extends State<ProviderCorrectionDialog> {
  final selected = <String>{};
  final reason = TextEditingController();
  final form = GlobalKey<FormState>();
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Request document corrections'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select only the documents that need to be resubmitted. Other documents and application details stay saved.',
            ),
            const SizedBox(height: 12),
            for (final key in widget.documentKeys)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(ProviderDocumentCorrection.labels[key] ?? key),
                value: selected.contains(key),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selected.add(key);
                  } else {
                    selected.remove(key);
                  }
                }),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Instructions for provider',
                hintText: 'Explain what needs to be corrected.',
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Enter clear instructions (at least 10 characters).'
                  : null,
            ),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!form.currentState!.validate()) return;
          if (selected.isEmpty) {
            setState(() => error = 'Select at least one document.');
            return;
          }
          Navigator.pop(
            context,
            ProviderCorrectionDraft(selected.toList(), reason.text.trim()),
          );
        },
        child: const Text('Send correction request'),
      ),
    ],
  );
}
