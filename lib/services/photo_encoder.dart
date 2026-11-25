import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

class PhotoEncoder {
  static const maxEncodedImageBytes = 580 * 1024;

  /// Comprime a imagem e retorna sua codificação Base64 dentro do limite.
  String toBase64(Uint8List bytes) {
    final decoded = image.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Não foi possível ler a imagem selecionada.');
    }

    var current = decoded.width > 1280
        ? image.copyResize(decoded, width: 1280)
        : decoded;

    for (var attempt = 0; attempt < 8; attempt++) {
      for (final quality in [78, 68, 58, 48]) {
        final jpeg = image.encodeJpg(current, quality: quality);
        if (jpeg.length <= maxEncodedImageBytes) {
          return base64Encode(jpeg);
        }
      }
      current = image.copyResize(
        current,
        width: (current.width * 0.78).round(),
      );
    }

    throw const FormatException(
      'A imagem não pôde ser reduzida o suficiente para o Firestore.',
    );
  }
}
