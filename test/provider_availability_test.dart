import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/provider_availability.dart';

void main() {
  test('finished service never becomes busy again during directory sync', () {
    for (final state in ['accepted', 'en_route', 'arrived']) {
      expect(ProviderAvailability.hasActiveService({'status': state}), isTrue);
      expect(
        ProviderAvailability.hasActiveService({
          'status': state,
          'serviceCompletedAt': DateTime.now(),
        }),
        isFalse,
      );
    }
    expect(
      ProviderAvailability.hasActiveService({'status': 'completed'}),
      isFalse,
    );
  });

  test('online flag requires a recent location heartbeat', () {
    final now = DateTime.utc(2026, 10, 8, 8);
    final data = <String, dynamic>{'online': true};
    expect(ProviderAvailability.status(data, now), 'Refresh location');
    expect(
      ProviderAvailability.status(
        data,
        now,
        locationUpdatedAt: now.subtract(const Duration(seconds: 119)),
      ),
      'Online',
    );
    expect(
      ProviderAvailability.status(
        data,
        now,
        locationUpdatedAt: now.subtract(const Duration(minutes: 2)),
      ),
      'Refresh location',
    );
    expect(
      ProviderAvailability.status(
        data,
        now,
        locationUpdatedAt: now.add(const Duration(seconds: 1)),
      ),
      'Online',
    );
    expect(
      ProviderAvailability.status(
        data,
        now,
        locationUpdatedAt: now.add(const Duration(seconds: 31)),
      ),
      'Refresh location',
    );
    expect(
      ProviderAvailability.status(
        {'online': false},
        now,
        locationUpdatedAt: now,
      ),
      'Offline',
    );
  });
  test('accepted job stays busy through missing and expired GPS updates', () {
    final now = DateTime.utc(2026, 10, 11, 8);
    final busy = <String, dynamic>{'online': true, 'activeRequestId': 'job'};
    for (final updated in <DateTime?>[
      null,
      now.subtract(const Duration(minutes: 3)),
      now,
    ]) {
      expect(
        ProviderAvailability.status(busy, now, locationUpdatedAt: updated),
        'Busy',
      );
    }
    expect(
      ProviderAvailability.status(
        {...busy, 'online': false},
        now,
        locationUpdatedAt: now,
      ),
      'Offline',
    );
    expect(
      ProviderAvailability.status(
        {...busy, 'activeRequestId': null},
        now,
        locationUpdatedAt: now,
      ),
      'Online',
    );
    expect(
      ProviderAvailability.status({...busy, 'activeRequestId': null}, now),
      'Refresh location',
    );
  });
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
    expect(
      ProviderAvailability.status(data, night, locationUpdatedAt: night),
      'Online',
    );
    expect(
      ProviderAvailability.status(
        {...data, 'requestsPaused': true},
        night,
        locationUpdatedAt: night,
      ),
      'Paused',
    );
    expect(
      ProviderAvailability.status(
        {...data, 'requestsPaused': true, 'activeRequestId': 'job'},
        night,
        locationUpdatedAt: night,
      ),
      'Busy',
    );
    final midday = DateTime.utc(2026, 10, 6, 7);
    expect(
      ProviderAvailability.status(data, midday, locationUpdatedAt: midday),
      'Outside working hours',
    );
    expect(
      ProviderAvailability.status(
        data,
        midday,
        locationUpdatedAt: midday,
        overrideUntil: midday.add(const Duration(hours: 2)),
      ),
      'Online',
    );
  });
}
