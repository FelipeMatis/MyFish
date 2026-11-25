import 'dart:convert';
import 'dart:typed_data';

import 'package:myfish/services/photo_encoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('compresses a photo into a bounded JPEG that can be decoded', () {
    final source = image.Image(width: 1600, height: 1000);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgb(
          x,
          y,
          (x * 17 + y * 31) % 256,
          (x * 7 + y * 23) % 256,
          (x * 13 + y * 11) % 256,
        );
      }
    }

    final png = Uint8List.fromList(image.encodePng(source));
    final encoded = PhotoEncoder().toBase64(png);
    final jpegBytes = base64Decode(encoded);
    final decoded = image.decodeImage(jpegBytes);

    expect(
      jpegBytes.length,
      lessThanOrEqualTo(PhotoEncoder.maxEncodedImageBytes),
    );
    expect(decoded, isNotNull);
    expect(decoded!.width, lessThanOrEqualTo(1280));
  });
}
