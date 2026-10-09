class AdminAuditPresentation {
  static String friendlyKey(String value) {
    final separated = value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (m) => '${m[1]} ${m[2]}',
        )
        .replaceAll('_', ' ')
        .trim();
    return separated.isEmpty
        ? 'Unknown'
        : separated
              .split(RegExp(r'\s+'))
              .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
              .join(' ');
  }

  static bool same(dynamic a, dynamic b) {
    if (a is Map && b is Map)
      return a.length == b.length &&
          a.keys.every((key) => b.containsKey(key) && same(a[key], b[key]));
    if (a is List && b is List)
      return a.length == b.length &&
          List.generate(a.length, (i) => i).every((i) => same(a[i], b[i]));
    return a == b;
  }

  static String action(Map<String, dynamic> data) {
    final before = data['before'] is Map ? data['before'] as Map : const {};
    final after = data['after'] is Map ? data['after'] as Map : const {};
    if (data['kind'] == 'account') {
      if (after['verification'] == 'verified' &&
          (!same(
                after['verificationRevision'],
                before['verificationRevision'],
              ) ||
              !same(after['validUntil'], before['validUntil'])))
        return 'Provider approved';
      if (after['verification'] != before['verification']) {
        if (after['verification'] == 'verified') return 'Provider approved';
        if (after['verification'] == 'rejected') return 'Provider rejected';
        if (after['verification'] == 'pending')
          return after['correctionRequest'] is Map
              ? 'Document corrections requested'
              : 'Verification set to pending';
      }
      if (!same(after['correctionRequest'], before['correctionRequest']) &&
          after['correctionRequest'] is Map)
        return 'Document corrections requested';
      if (after['status'] != before['status'])
        return after['status'] == 'suspended'
            ? 'Account suspended'
            : 'Account activated';
      if (after['flagged'] != before['flagged'])
        return after['flagged'] == true
            ? 'Account flagged'
            : 'Account flag cleared';
      return 'Account review updated';
    }
    return switch (data['kind']) {
      'complaint' => 'Complaint reviewed',
      'settings' => 'Platform settings updated',
      _ => friendlyKey(data['kind']?.toString() ?? 'Administrative action'),
    };
  }

  static Map<String, dynamic> visibleValues(dynamic raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (!const [
          'lastAuditId',
          'updatedBy',
          'updatedAt',
        ].contains(entry.key))
          entry.key.toString(): entry.value,
    };
  }
}
