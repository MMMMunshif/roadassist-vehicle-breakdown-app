import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PhotoUploadService {
  Future<String> prepareIdentityPhoto(XFile photo) async {
    if (await photo.length() > 8 * 1024 * 1024)
      throw const FormatException('Photo exceeds 8 MB.');
    return _compress(
      photo,
      maxDimension: 1200,
      quality: 75,
      maxBytes: 110 * 1024,
    );
  }

  Future<String> prepareProfilePhoto(XFile photo) =>
      _compress(photo, maxDimension: 512, quality: 65, maxBytes: 180 * 1024);

  Future<String> prepareVehiclePhoto(XFile photo) =>
      _compress(photo, maxDimension: 800, quality: 55, maxBytes: 150 * 1024);

  Future<String> prepareChatPhoto(XFile photo) =>
      _compress(photo, maxDimension: 960, quality: 55, maxBytes: 180 * 1024);

  Future<String> _compress(
    XFile photo, {
    required int maxDimension,
    required int quality,
    required int maxBytes,
  }) async {
    final bytes = await photo.readAsBytes();
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on RangeError {
      throw const FormatException('Unsupported or corrupted image file.');
    } on FormatException {
      throw const FormatException('Unsupported or corrupted image file.');
    }
    if (decoded == null) {
      throw const FormatException('Unsupported image file.');
    }

    var prepared = img.bakeOrientation(decoded);
    if (prepared.width > maxDimension || prepared.height > maxDimension) {
      prepared = prepared.width >= prepared.height
          ? img.copyResize(prepared, width: maxDimension)
          : img.copyResize(prepared, height: maxDimension);
    }

    var currentQuality = quality;
    for (var attempt = 0; attempt < 7; attempt++) {
      final encoded = img.encodeJpg(prepared, quality: currentQuality);
      if (encoded.length <= maxBytes) return base64Encode(encoded);

      if (currentQuality > 35) {
        currentQuality = (currentQuality - 10).clamp(30, 100).toInt();
        continue;
      }

      final nextWidth = (prepared.width * .82).round();
      final nextHeight = (prepared.height * .82).round();
      if (nextWidth < 320 || nextHeight < 240) break;
      prepared = img.copyResize(prepared, width: nextWidth, height: nextHeight);
    }

    throw StateError(
      'Image is still too large after optimisation. Choose another photo.',
    );
  }
}
