part of '../screens.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  Future<void> editContact(BuildContext context, String currentContact) async {
    final formKey = GlobalKey<FormState>();
    var updatedContact = currentContact == 'Not added' ? '' : currentContact;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Form(
        key: formKey,
        child: AlertDialog(
          title: const Text('Emergency Contact'),
          content: TextFormField(
            initialValue: updatedContact,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+94 77 123 4567',
              prefixIcon: Icon(Icons.contact_emergency_outlined),
            ),
            validator: validateSriLankaPhone,
            onChanged: (value) => updatedContact = value,
            onFieldSubmitted: (_) {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(
                  dialogContext,
                  normalizeSriLankaPhone(updatedContact),
                );
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(
                  dialogContext,
                  normalizeSriLankaPhone(updatedContact),
                );
              },
              child: const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
    if (value == null || value.isEmpty || !context.mounted) return;
    try {
      await AuthService().updateCurrentProfile({'emergencyContact': value});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency contact saved.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save emergency contact: $error'),
            backgroundColor: raDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Emergency Contact')),
    body: !signedIn
        ? const EmptyState(
            icon: Icons.login_outlined,
            title: 'Sign in required',
            message: 'Sign in as a driver to manage an emergency contact.',
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
              return ListView(
                padding: const EdgeInsets.all(RaSpace.xl),
                children: [
                  InfoStrip(
                    icon: Icons.contact_emergency_outlined,
                    title: 'Family Contact',
                    value: configured ? contact : 'No contact added',
                  ),
                  const SizedBox(height: RaSpace.md),
                  OutlinedButton.icon(
                    onPressed: () => editContact(context, contact),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(configured ? 'Change Contact' : 'Add Contact'),
                  ),
                  const SizedBox(height: RaSpace.xl),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RaRadius.md),
                    child: const SizedBox(height: 250, child: MapMock()),
                  ),
                  const SizedBox(height: RaSpace.md),
                  FilledButton.icon(
                    onPressed: configured
                        ? () => showCallPrompt(
                            context,
                            name: 'Family Contact',
                            number: contact,
                          )
                        : null,
                    icon: const Icon(Icons.call),
                    label: const Text('Call Emergency Contact'),
                  ),
                  const SizedBox(height: RaSpace.sm),
                  OutlinedButton.icon(
                    onPressed: location == 'Current location not available'
                        ? null
                        : () => copyLocation(context, location),
                    icon: const Icon(Icons.share_location),
                    label: const Text('Share Current Location'),
                  ),
                ],
              );
            },
          ),
  );
}

// ============================================================
// PROVIDER SHELL
// ============================================================
