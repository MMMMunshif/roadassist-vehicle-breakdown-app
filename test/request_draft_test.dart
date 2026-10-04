import 'package:flutter_test/flutter_test.dart';
import 'package:road_assist/src/models/request_draft.dart';
import 'package:road_assist/src/services/request_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

RequestDraft sampleDraft() => RequestDraft(
  issues: ['Flat Tyre', 'Battery Jumpstart'],
  vehicleType: 'SUV',
  modelYear: 'Toyota RAV4 2020',
  registration: 'WP CAB-1234',
  description: 'Rear tyre is flat and the battery will not start.',
  notes: 'Vehicle is beside the main entrance.',
  priority: 'safety_risk',
  location: 'Pinned location (6.90000, 79.90000)',
  landmark: 'Opposite the main railway station',
  locationAccuracyMeters: 8.5,
  latitude: 6.9,
  longitude: 79.9,
  provider: 'City Rescue',
  preferredProviderId: 'provider-1',
  vehiclePhotoUrls: ['encoded-photo'],
  photoAnnotations: const [
    BreakdownPhotoAnnotation(
      photoIndex: 0,
      markerX: .25,
      markerY: .75,
      note: 'Damage on rear-left tyre',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'multiple issues preserve the driver report without inventing prices',
    () {
      final draft = sampleDraft();

      expect(draft.toJson().containsKey('estimatedCost'), isFalse);
      expect(draft.primaryIssue, 'Flat Tyre');
      expect(draft.issue, 'Flat Tyre + Battery Jumpstart');
    },
  );

  test('draft JSON preserves workflow and photo annotation data', () {
    final restored = RequestDraft.fromJson(sampleDraft().toJson());

    expect(restored.issues, ['Flat Tyre', 'Battery Jumpstart']);
    expect(restored.location, 'Pinned location (6.90000, 79.90000)');
    expect(restored.landmark, 'Opposite the main railway station');
    expect(restored.locationAccuracyMeters, 8.5);
    expect(restored.preferredProviderId, 'provider-1');
    expect(restored.priority, 'safety_risk');
    expect(restored.vehiclePhotoUrls, ['encoded-photo']);
    expect(restored.photoAnnotations.single.markerX, .25);
    expect(restored.photoAnnotations.single.note, 'Damage on rear-left tyre');
  });

  test('unsafe annotation coordinates are clamped when restored', () {
    final json = sampleDraft().toJson();
    json['photoAnnotations'] = [
      {'photoIndex': 0, 'markerX': -2, 'markerY': 5, 'note': 'Damage'},
    ];

    final annotation = RequestDraft.fromJson(json).photoAnnotations.single;
    expect(annotation.markerX, 0);
    expect(annotation.markerY, 1);
  });

  test('draft store saves, restores, timestamps and clears progress', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = RequestDraftStore(preferences: preferences);

    await store.save(sampleDraft());
    final restored = await store.load();

    expect(restored, isNotNull);
    expect(restored!.issues, ['Flat Tyre', 'Battery Jumpstart']);
    expect(await store.lastUpdated(), isNotNull);

    await store.clear();
    expect(await store.load(), isNull);
    expect(await store.lastUpdated(), isNull);
  });

  test('pending offline submission flag is stored and cleared', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = RequestDraftStore(preferences: preferences);

    expect(await store.hasPendingSubmission(), isFalse);
    await store.setPendingSubmission(true);
    expect(await store.hasPendingSubmission(), isTrue);

    await store.clear();
    expect(await store.hasPendingSubmission(), isFalse);
  });
}
