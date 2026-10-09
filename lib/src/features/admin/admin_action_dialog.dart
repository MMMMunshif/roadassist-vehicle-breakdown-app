part of '../../screens.dart';

Future<String?> _adminReason(
  BuildContext context,
  String title, {
  String? expectedId,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _AdminActionDialog(
        title: title,
        expectedId: expectedId,
      );
    },
  );
}

class _AdminActionDialog extends StatefulWidget {
  const _AdminActionDialog({
    required this.title,
    this.expectedId,
  });

  final String title;
  final String? expectedId;

  @override
  State<_AdminActionDialog> createState() =>
      _AdminActionDialogState();
}

class _AdminActionDialogState
    extends State<_AdminActionDialog> {
  final controller = TextEditingController();

  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get confirmationMode =>
      widget.expectedId != null;

  String get heading {
    if (confirmationMode) {
      return 'Confirm Action';
    }

    return widget.title;
  }

  String get description {
    if (confirmationMode) {
      return 'This is a sensitive action. Enter the exact account ID shown below to continue.';
    }

    return 'Provide a clear reason. This information may be stored with the related workflow or administrative audit record.';
  }

  String get fieldLabel {
    if (confirmationMode) {
      return 'Enter account ID';
    }

    return 'Reason';
  }

  String? validate(
    String? value,
  ) {
    final text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return confirmationMode
          ? 'Enter the required ID'
          : 'Enter a reason';
    }

    if (confirmationMode &&
        text != widget.expectedId) {
      return 'The ID does not match';
    }

    return null;
  }

  void submit() {
    if (!(formKey.currentState?.validate() ??
        false)) {
      return;
    }

    Navigator.of(context).pop(
      controller.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final danger =
        confirmationMode;

    final tone = danger
        ? colors.error
        : colors.primary;

    return AlertDialog(
      icon: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: tone.withValues(
            alpha: .08,
          ),
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Icon(
          danger
              ? Icons.warning_amber_rounded
              : Icons.edit_note_outlined,
          color: tone,
          size: 28,
        ),
      ),
      title: Text(
        heading,
        textAlign:
            TextAlign.center,
        style:
            GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight:
              FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      content: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 440,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .stretch,
            children: [
              Text(
                description,
                textAlign:
                    TextAlign.center,
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 8.8,
                  height: 1.5,
                  color: colors
                      .onSurfaceVariant,
                ),
              ),

              if (confirmationMode) ...[
                const SizedBox(
                  height: 15,
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    11,
                  ),
                  decoration:
                      BoxDecoration(
                    color: colors.error
                        .withValues(
                      alpha: .055,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                    border: Border.all(
                      color: colors.error
                          .withValues(
                        alpha: .17,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'REQUIRED ID',
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 6.8,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: .6,
                          color: colors.error,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      SelectableText(
                        widget.expectedId!,
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 8.5,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(
                height: 16,
              ),

              TextFormField(
                controller: controller,
                autofocus: true,
                minLines:
                    confirmationMode
                        ? 1
                        : 3,
                maxLines:
                    confirmationMode
                        ? 1
                        : 6,
                maxLength:
                    confirmationMode
                        ? 128
                        : 500,
                textCapitalization:
                    confirmationMode
                        ? TextCapitalization.none
                        : TextCapitalization
                            .sentences,
                textInputAction:
                    confirmationMode
                        ? TextInputAction.done
                        : TextInputAction
                            .newline,
                decoration:
                    InputDecoration(
                  labelText: fieldLabel,
                  alignLabelWithHint:
                      !confirmationMode,
                  prefixIcon:
                      confirmationMode
                          ? const Icon(
                              Icons
                                  .fingerprint_rounded,
                            )
                          : const Padding(
                              padding:
                                  EdgeInsets.only(
                                bottom: 45,
                              ),
                              child: Icon(
                                Icons
                                    .notes_outlined,
                              ),
                            ),
                ),
                validator: validate,
                onFieldSubmitted:
                    confirmationMode
                        ? (_) {
                            submit();
                          }
                        : null,
              ),

              if (!confirmationMode) ...[
                const SizedBox(
                  height: 4,
                ),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Icon(
                      Icons
                          .info_outline_rounded,
                      size: 14,
                      color: colors
                          .onSurfaceVariant,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts
                            .plusJakartaSans(
                          fontSize: 7.4,
                          height: 1.4,
                          color: colors
                              .onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child:
              const Text('Cancel'),
        ),

        FilledButton.icon(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor:
                      colors.error,
                  foregroundColor:
                      colors.onError,
                )
              : null,
          onPressed: submit,
          icon: Icon(
            danger
                ? Icons
                    .warning_amber_rounded
                : Icons
                    .check_rounded,
          ),
          label: Text(
            danger
                ? 'Confirm'
                : 'Continue',
          ),
        ),
      ],
    );
  }
}