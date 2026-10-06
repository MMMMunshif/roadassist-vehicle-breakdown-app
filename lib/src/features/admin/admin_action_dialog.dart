part of '../../screens.dart';

Future<String?> _adminReason(
  BuildContext context,
  String title, {
  String? expectedId,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expectedId != null) ...[
              const Text(
                'Copy this account ID and paste it below to confirm deletion:',
              ),
              SelectableText(expectedId),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: controller,
              maxLength: expectedId == null ? 500 : 128,
              minLines: expectedId == null ? 2 : 1,
              maxLines: expectedId == null ? 5 : 1,
              decoration: InputDecoration(
                labelText: expectedId == null
                    ? 'Reason (at least 10 characters)'
                    : 'Account ID',
                errorMaxLines: 3,
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (expectedId != null)
                  return text == expectedId
                      ? null
                      : 'Paste the exact account ID shown above.';
                return text.length >= 10
                    ? null
                    : 'Enter a reason with at least 10 characters.';
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate())
              Navigator.pop(context, controller.text.trim());
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}
