part of '../../screens.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> editContact(BuildContext context, String currentContact) async {
    final formKey = GlobalKey<FormState>();

    var updatedContact = currentContact == 'Not added' ? '' : currentContact;

    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            RaSpace.lg,
            0,
            RaSpace.lg,
            MediaQuery.of(sheetContext).viewInsets.bottom + RaSpace.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: raDangerPale,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.contact_emergency_outlined,
                        color: raDanger,
                      ),
                    ),
                    const SizedBox(width: RaSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency contact',
                            style: Theme.of(sheetContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Add a trusted contact you may need during roadside assistance.',
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: RaSpace.xl),

                TextFormField(
                  initialValue: updatedContact,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+94 77 123 4567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: validateSriLankaPhone,
                  onChanged: (value) {
                    updatedContact = value;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.pop(
                        sheetContext,
                        normalizeSriLankaPhone(updatedContact),
                      );
                    }
                  },
                ),

                const SizedBox(height: RaSpace.lg),

                FilledButton.icon(
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }

                    Navigator.pop(
                      sheetContext,
                      normalizeSriLankaPhone(updatedContact),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Contact'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (value == null || value.isEmpty || !context.mounted) {
      return;
    }

    try {
      await AuthService().updateCurrentProfile({'emergencyContact': value});

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Emergency contact saved.')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save emergency contact: $error'),
          backgroundColor: raDanger,
        ),
      );
    }
  }

  Widget _hero(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(RaSpace.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD8362A), Color(0xFFAA2720)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            bottom: -28,
            child: Icon(
              Icons.sos_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: RaSpace.lg),
              Text(
                'Emergency assistance',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'For immediate danger, contact emergency services first. Your saved family contact is available below for personal assistance.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .86),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(title: const Text('Emergency')),

      body: !signedIn
          ? const Padding(
              padding: EdgeInsets.all(RaSpace.lg),
              child: EmptyState(
                icon: Icons.login_outlined,
                title: 'Sign in required',
                message: 'Sign in as a driver to manage an emergency contact.',
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AuthService().watchCurrentProfile(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Unable to load contact',
                    message: 'Check your connection and try again.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data() ?? {};

                final contact = data['emergencyContact'] as String? ?? '';

                final configured =
                    contact.trim().isNotEmpty && contact != 'Not added';

                final location =
                    data['currentLocationLabel'] as String? ??
                    'Current location not available';

                final hasLocation =
                    location != 'Current location not available';

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    RaSpace.lg,
                    RaSpace.md,
                    RaSpace.lg,
                    RaSpace.xxxl,
                  ),
                  children: [
                    _hero(context),

                    const SizedBox(height: RaSpace.xl),

                    Text(
                      'Emergency services',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: RaSpace.md),

                    _EmergencyScreenActionCard(
                      icon: Icons.sos_rounded,
                      title: 'Police Emergency',
                      subtitle: 'Call 119 for immediate emergency assistance.',
                      danger: true,
                      actionLabel: 'Call 119',
                      onTap: () => showCallPrompt(
                        context,
                        name: 'Emergency Services',
                        number: '119',
                      ),
                    ),

                    const SizedBox(height: RaSpace.xxl),

                    Text(
                      'Trusted contact',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: RaSpace.md),

                    Container(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .6),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Icon(
                                  Icons.contact_emergency_outlined,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),

                              const SizedBox(width: RaSpace.md),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Family Contact',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      configured
                                          ? contact
                                          : 'No emergency contact added',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                tooltip: configured
                                    ? 'Change contact'
                                    : 'Add contact',
                                onPressed: () => editContact(context, contact),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),

                          const SizedBox(height: RaSpace.md),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: configured
                                  ? () => showCallPrompt(
                                      context,
                                      name: 'Family Contact',
                                      number: contact,
                                    )
                                  : () => editContact(context, contact),
                              icon: Icon(
                                configured
                                    ? Icons.call_rounded
                                    : Icons.person_add_alt_1_outlined,
                              ),
                              label: Text(
                                configured
                                    ? 'Call Emergency Contact'
                                    : 'Add Emergency Contact',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: RaSpace.xxl),

                    Text(
                      'Current location',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: RaSpace.md),

                    Container(
                      padding: const EdgeInsets.all(RaSpace.lg),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: .6),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: hasLocation
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  hasLocation
                                      ? Icons.location_on_rounded
                                      : Icons.location_off_outlined,
                                  color: hasLocation
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: RaSpace.md),
                              Expanded(
                                child: Text(
                                  location,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: RaSpace.md),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: hasLocation
                                  ? () => copyLocation(context, location)
                                  : null,
                              icon: const Icon(Icons.share_location_outlined),
                              label: const Text('Copy / Share Location'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _EmergencyScreenActionCard extends StatelessWidget {
  const _EmergencyScreenActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = theme.colorScheme;

    final color = danger ? colors.error : colors.primary;

    return Container(
      padding: const EdgeInsets.all(RaSpace.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: RaSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RaSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              onPressed: onTap,
              icon: const Icon(Icons.call_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
