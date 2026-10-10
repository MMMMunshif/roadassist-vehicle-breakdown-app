class LocationFreshness {
  static bool isFresh(DateTime? updatedAt, DateTime now) {
    if (updatedAt == null) return false;
    final age = now.difference(updatedAt);
    return age >= const Duration(seconds: -30) &&
        age < const Duration(minutes: 2);
  }

  static String label(DateTime? updatedAt, DateTime now) {
    if (updatedAt == null ||
        updatedAt.difference(now) > const Duration(seconds: 30))
      return 'Provider location is not available yet.';
    final seconds = now.difference(updatedAt).inSeconds;
    if (isFresh(updatedAt, now))
      return seconds < 60
          ? 'Location updated just now'
          : 'Location updated 1 minute ago';
    final minutes = seconds ~/ 60;
    return minutes < 60
        ? 'Last location update: $minutes minutes ago'
        : 'Last location update: ${minutes ~/ 60} hours ago';
  }
}
