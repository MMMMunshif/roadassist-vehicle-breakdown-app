import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:road_assist/src/services/photo_upload_service.dart';

void main() {
  test(
    'vehicle photos are resized and kept below the request size limit',
    () async {
      final random = Random(42);
      final source = img.Image(width: 1200, height: 900);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgba(
            x,
            y,
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
            255,
          );
        }
      }

      final input = XFile.fromData(
        Uint8List.fromList(img.encodePng(source)),
        mimeType: 'image/png',
        name: 'breakdown.png',
      );
      final result = await PhotoUploadService().prepareVehiclePhoto(input);
      final compressedBytes = base64Decode(result);
      final compressedImage = img.decodeJpg(compressedBytes);

      expect(compressedBytes.length, lessThanOrEqualTo(150 * 1024));
      expect(compressedImage, isNotNull);
      expect(compressedImage!.width, lessThanOrEqualTo(800));
      expect(compressedImage.height, lessThanOrEqualTo(800));
    },
  );

  test('unsupported image data is rejected', () async {
    final input = XFile.fromData(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      name: 'invalid.bin',
    );

    await expectLater(
      PhotoUploadService().prepareVehiclePhoto(input),
      throwsA(isA<FormatException>()),
    );
  });
}
