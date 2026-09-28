import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class PhotoUploadService {
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
    final source = img.decodeImage(await photo.readAsBytes());
    if (source == null) {
      throw const FormatException('Unsupported image file.');
    }
    final resized = source.width > source.height
        ? img.copyResize(source, width: maxDimension)
        : img.copyResize(source, height: maxDimension);
    var encoded = img.encodeJpg(resized, quality: quality);
    if (encoded.length > maxBytes) {
      final smaller = source.width > source.height
          ? img.copyResize(source, width: (maxDimension * .72).round())
          : img.copyResize(source, height: (maxDimension * .72).round());
      encoded = img.encodeJpg(smaller, quality: 45);
    }
    if (encoded.length > maxBytes) {
      throw StateError(
        'Image is still too large. Please choose another photo.',
      );
    }
    return base64Encode(encoded);
  }
}
