/// Legacy profiles retain their primary role; new roles share the same UID.
List<String> accountRoles(Map<String, dynamic>? profile) {
  final values = <String>{
    if (profile?['role'] is String) profile!['role'] as String,
    ...((profile?['roles'] as List?) ?? const []).whereType<String>(),
  };
  return values
      .where((role) => role == 'driver' || role == 'provider')
      .toList();
}

bool accountHasRole(Map<String, dynamic>? profile, String role) =>
    accountRoles(profile).contains(role);

String? accountLastRole(Map<String, dynamic>? profile) {
  final last = profile?['lastRole'];
  return last is String && accountHasRole(profile, last)
      ? last
      : accountRoles(profile).firstOrNull;
}
