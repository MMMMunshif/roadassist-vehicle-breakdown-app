import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/provider_availability.dart';

void main() {
  test('Sri Lanka daytime schedule and end boundary', () {
    final data = {
      'scheduleConfigured': true,
      'workStartMinute': 480,
      'workEndMinute': 1080,
    };
    expect(
      ProviderAvailability.withinHours(data, DateTime.utc(2026, 10, 6, 2, 30)),
      true,
    );
    expect(
      ProviderAvailability.withinHours(data, DateTime.utc(2026, 10, 6, 12, 30)),
      false,
    );
  });
  test('overnight shift and availability precedence', () {
    final data = <String, dynamic>{
      'online': true,
      'scheduleConfigured': true,
      'workStartMinute': 1320,
      'workEndMinute': 360,
    };
    final night = DateTime.utc(2026, 10, 6, 18);
    expect(ProviderAvailability.status(data, night), 'Online');
    expect(
      ProviderAvailability.status({...data, 'requestsPaused': true}, night),
      'Paused',
    );
    expect(
      ProviderAvailability.status({
        ...data,
        'requestsPaused': true,
        'activeRequestId': 'job',
      }, night),
      'Busy',
    );
    final midday = DateTime.utc(2026, 10, 6, 7);
    expect(ProviderAvailability.status(data, midday), 'Outside working hours');
    expect(
      ProviderAvailability.status(
        data,
        midday,
        overrideUntil: midday.add(const Duration(hours: 2)),
      ),
      'Online',
    );
  });
}
