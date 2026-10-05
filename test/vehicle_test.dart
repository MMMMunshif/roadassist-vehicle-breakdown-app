import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:road_assist/src/models/vehicle.dart';
import 'package:road_assist/src/models/request_draft.dart';
import 'package:road_assist/src/services/request_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const vehicle = Vehicle(
    id: 'vehicle-1',
    make: 'Toyota',
    model: 'Aqua',
    year: 2017,
    vehicleType: 'Sedan / Hatchback',
    registration: 'CAB-1234',
    fuelType: 'Hybrid',
    transmission: 'Automatic',
  );
  RequestDraft draft() => RequestDraft(
    issues: ['Flat Tyre'],
    vehicleType: vehicle.vehicleType,
    modelYear: vehicle.label,
    registration: vehicle.registration,
    description: '',
    vehicleId: vehicle.id,
    vehicleSnapshot: vehicle.toJson(),
  );
  test(
    'vehicle snapshot survives draft serialization and location changes',
    () {
      final restored = RequestDraft.fromJson(
        draft().toJson(),
      ).copyWith(location: 'Colombo');
      expect(restored.vehicleId, vehicle.id);
      expect(restored.vehicleSnapshot, vehicle.toJson());
      expect(
        Vehicle.fromJson(vehicle.id, restored.vehicleSnapshot!).label,
        'Toyota Aqua 2017',
      );
    },
  );
  test('legacy drafts do not require vehicle references', () {
    final restored = RequestDraft.fromJson({'issue': 'Flat Tyre'});
    expect(restored.vehicleId, isNull);
    expect(restored.vehicleSnapshot, isNull);
  });
  test(
    'saved drafts and pending submission cannot leak between accounts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = RequestDraftStore(
        preferences: prefs,
        ownerId: 'driver-one',
      );
      final second = RequestDraftStore(
        preferences: prefs,
        ownerId: 'driver-two',
      );
      await first.save(draft());
      await first.setPendingSubmission(true);
      expect(await second.load(), isNull);
      expect(await second.hasPendingSubmission(), isFalse);
      await second.clear();
      expect((await first.load())?.vehicleId, vehicle.id);
      expect(await first.hasPendingSubmission(), isTrue);
    },
  );
}
