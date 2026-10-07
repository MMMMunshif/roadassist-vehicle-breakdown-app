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
    barrierDismissible: false,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colors = theme.colorScheme;

      final destructive = expectedId != null;

      return AlertDialog(
        icon: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: destructive
                ? colors.errorContainer
                : colors.primaryContainer,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Icon(
            destructive
                ? Icons.warning_amber_rounded
                : Icons.admin_panel_settings_outlined,
            color: destructive
                ? colors.error
                : colors.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
        ),
        content: Form(
          key: formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 430,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                if (expectedId != null) ...[
                  Text(
                    'This action permanently deletes the account profile. Copy the account ID below and enter it exactly to continue.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                  Container(
                    padding: const EdgeInsets.all(
                      RaSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: colors
                          .surfaceContainerHighest
                          .withValues(alpha: .45),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: SelectableText(
                      expectedId,
                      style: theme
                          .textTheme.labelLarge
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: RaSpace.lg),
                ] else ...[
                  Text(
                    'Administrative actions require a reason. The reason will be recorded in the audit history.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: RaSpace.md),
                ],
                TextFormField(
                  controller: controller,
                  maxLength:
                      expectedId == null ? 500 : 128,
                  minLines:
                      expectedId == null ? 3 : 1,
                  maxLines:
                      expectedId == null ? 6 : 1,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: expectedId == null
                        ? 'Administrative reason'
                        : 'Account ID',
                    hintText: expectedId == null
                        ? 'Explain why this action is required'
                        : 'Paste the exact ID shown above',
                    prefixIcon: Icon(
                      expectedId == null
                          ? Icons.edit_note_outlined
                          : Icons
                              .fingerprint_rounded,
                    ),
                    helperText:
                        expectedId == null
                        ? 'Minimum 10 characters'
                        : null,
                    errorMaxLines: 3,
                  ),
                  validator: (value) {
                    final text =
                        (value ?? '').trim();

                    if (expectedId != null) {
                      return text == expectedId
                          ? null
                          : 'Paste the exact account ID shown above.';
                    }

                    return text.length >= 10
                        ? null
                        : 'Enter a reason with at least 10 characters.';
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor:
                        colors.error,
                    foregroundColor:
                        colors.onError,
                  )
                : null,
            onPressed: () {
              if (formKey.currentState
                      ?.validate() ??
                  false) {
                Navigator.pop(
                  dialogContext,
                  controller.text.trim(),
                );
              }
            },
            icon: Icon(
              destructive
                  ? Icons.delete_forever_outlined
                  : Icons.check_rounded,
            ),
            label: Text(
              destructive
                  ? 'Confirm Deletion'
                  : 'Confirm',
            ),
          ),
        ],
      );
    },
  );

  controller.dispose();

  return result;
}