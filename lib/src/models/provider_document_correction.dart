/// Revision-bound document corrections; previously accepted documents stay locked.
class ProviderDocumentCorrection {
  const ProviderDocumentCorrection({
    required this.revision,
    required this.documents,
  });
  final int revision;
  final List<String> documents;
  static const labels = {
    'selfie': 'Provider selfie',
    'nicFront': 'NIC front',
    'nicBack': 'NIC back',
    'serviceProof': 'Service capability proof',
    'recoveryProof': 'Recovery vehicle proof',
    'businessProof': 'Business registration',
  };
  static ProviderDocumentCorrection? active(
    Map<String, dynamic>? application,
    Map<String, dynamic>? moderation,
  ) {
    final raw = moderation?['correctionRequest'];
    if (application == null ||
        application['applicationStatus'] == 'withdrawn' ||
        moderation?['verification'] != 'pending' ||
        raw is! Map ||
        raw['revision'] is! int ||
        raw['documents'] is! List ||
        raw['revision'] != application['revision'])
      return null;
    final documents = (raw['documents'] as List? ?? [])
        .whereType<String>()
        .toList();
    if (documents.isEmpty ||
        documents.toSet().length != documents.length ||
        !documents.every(labels.containsKey) ||
        documents.length != (raw['documents'] as List).length)
      return null;
    return ProviderDocumentCorrection(
      revision: raw['revision'] as int,
      documents: documents,
    );
  }

  Map<String, dynamic> replaceDocuments(
    Map<String, dynamic> previous,
    Map<String, String> replacements,
  ) {
    if (previous['revision'] != revision ||
        previous['applicationStatus'] == 'withdrawn')
      throw StateError('The application changed. Refresh before submitting.');
    if (replacements.length != documents.length ||
        !documents.every(replacements.containsKey))
      throw StateError('Replace every requested document.');
    final saved = Map<String, dynamic>.from(
      previous['documents'] as Map? ?? {},
    );
    for (final key in documents) {
      final value = replacements[key]!;
      if (value.trim().isEmpty || value == saved[key])
        throw StateError('Upload a new image for each requested document.');
      saved[key] = value;
    }
    return {...previous, 'documents': saved};
  }
}
