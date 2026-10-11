import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/location_freshness.dart';

void main() {
  test(
    'location is fresh only within two minutes and tolerates minor clock skew',
    () {
      final now = DateTime.utc(2026, 10, 9, 12);
      expect(LocationFreshness.isFresh(null, now), isFalse);
      expect(
        LocationFreshness.isFresh(
          now.subtract(const Duration(seconds: 119)),
          now,
        ),
        isTrue,
      );
      expect(
        LocationFreshness.isFresh(
          now.subtract(const Duration(minutes: 2)),
          now,
        ),
        isFalse,
      );
      expect(
        LocationFreshness.isFresh(now.add(const Duration(minutes: 5)), now),
        isFalse,
      );
      expect(
        LocationFreshness.isFresh(now.add(const Duration(seconds: 10)), now),
        isTrue,
      );
      expect(
        LocationFreshness.label(now.subtract(const Duration(minutes: 4)), now),
        contains('4 minutes ago'),
      );
    },
  );
}
