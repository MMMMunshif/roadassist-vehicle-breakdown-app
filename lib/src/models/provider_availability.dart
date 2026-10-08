class ProviderAvailability {
  static const locationLifetime = Duration(minutes: 2);

  static bool hasFreshLocation(DateTime? updated, DateTime now) {
    if (updated == null) return false;
    final age = now.difference(updated);
    return !age.isNegative && age < locationLifetime;
  }

  static bool withinHours(Map<String, dynamic> data, DateTime now) {
    if (data['available24Hours'] == true || data['scheduleConfigured'] != true)
      return true;
    final start = data['workStartMinute'] as int? ?? 0;
    final end = data['workEndMinute'] as int? ?? 0;
    final sriLanka = now.toUtc().add(const Duration(hours: 5, minutes: 30));
    final minute = sriLanka.hour * 60 + sriLanka.minute;
    return start == end
        ? false
        : start < end
        ? minute >= start && minute < end
        : minute >= start || minute < end;
  }

  static String status(
    Map<String, dynamic> data,
    DateTime now, {
    DateTime? overrideUntil,
    DateTime? locationUpdatedAt,
  }) {
    if (data['online'] != true || !hasFreshLocation(locationUpdatedAt, now)) {
      return 'Offline';
    }
    if ((data['activeRequestId'] as String? ?? '').isNotEmpty) return 'Busy';
    if (data['requestsPaused'] == true) return 'Paused';
    if (overrideUntil?.isAfter(now) != true && !withinHours(data, now))
      return 'Outside working hours';
    return 'Online';
  }
}
