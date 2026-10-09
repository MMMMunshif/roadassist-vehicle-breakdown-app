import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:road_assist/src/services/vehicle_image_service.dart';
import 'package:road_assist/src/models/vehicle.dart';
import 'package:road_assist/src/models/request_draft.dart';

Map<String, dynamic> page(
  String title, {
  String license = 'CC BY-SA 4.0',
  String host = 'thumb.wikimedia.org',
}) => {
  'title': title,
  'imageinfo': [
    {
      'mime': 'image/jpeg',
      'thumburl': 'https://$host/photo.jpg',
      'descriptionurl': 'https://commons.wikimedia.org/wiki/File:Photo.jpg',
      'extmetadata': {
        'Artist': {'value': '<a href="test">Photographer</a>'},
        'LicenseShortName': {'value': license},
      },
    },
  ],
};
void main() {
  test(
    'matches named model with credit, prefers year and caches requests',
    () async {
      int calls = 0;
      final service = VehicleImageService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.queryParameters['origin'], '*');
          expect(
            request.url.queryParameters['gsrsearch'],
            contains('toyota aqua'),
          );
          return http.Response(
            jsonEncode({
              'query': {
                'pages': [
                  page('File:Toyota Aqua 2021.jpg'),
                  page('File:Toyota Aqua 2018.jpg'),
                ],
              },
            }),
            200,
          );
        }),
      );
      final image = await service.lookup('Toyota Aqua 2018');
      expect(image?.exactYear, true);
      expect(image?.credit, 'Photographer / CC BY-SA 4.0');
      expect((await service.lookup('Toyota Aqua 2018'))?.url, image?.url);
      expect(calls, 1);
    },
  );
  test(
    'rejects unrelated models, interiors, unapproved hosts and unknown licences',
    () async {
      final service = VehicleImageService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'query': {
                'pages': [
                  page('File:Toyota Corolla.jpg'),
                  page('File:Toyota Aqua interior.jpg'),
                  page('File:Toyota Aqua.jpg', host: 'example.com'),
                  page('File:Toyota Aqua.jpg', license: 'All rights reserved'),
                ],
              },
            }),
            200,
          ),
        ),
      );
      expect(await service.lookup('Toyota Aqua 2018'), isNull);
      expect(await service.lookup('SUV'), isNull);
    },
  );
  test('network failure leaves photo optional', () async {
    final service = VehicleImageService(
      client: MockClient((_) async => throw Exception('offline')),
    );
    expect(await service.lookup('Toyota Aqua 2018'), isNull);
  });
  test(
    'saved actual photo survives vehicle and request draft serialization',
    () {
      final vehicle = Vehicle.fromJson('v1', {
        'make': 'Toyota',
        'model': 'Aqua',
        'year': 2018,
        'vehicleType': 'Sedan / Hatchback',
        'registration': 'CAB-1234',
        'fuelType': 'Hybrid',
        'transmission': 'Automatic',
        'photoData': 'cGhvdG8=',
      });
      final draft = RequestDraft(
        issues: ['Flat Tyre'],
        vehicleType: vehicle.vehicleType,
        modelYear: vehicle.label,
        registration: vehicle.registration,
        description: '',
        vehicleSnapshot: vehicle.toJson(),
      );
      expect(
        RequestDraft.fromJson(draft.toJson()).vehicleSnapshot?['photoData'],
        'cGhvdG8=',
      );
      final legacy = vehicle.toJson()..remove('photoData');
      expect(Vehicle.fromJson('v1', legacy).photoData, '');
    },
  );
}
