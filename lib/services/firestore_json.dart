import 'dart:convert';

/// Codifica mapas do Firestore e converte datas para texto ISO 8601.
String encodeFirestoreJson(Object? value) {
  return jsonEncode(
    value,
    toEncodable: (Object? value) {
      if (value is DateTime) return value.toIso8601String();
      throw UnsupportedError(
        'Cannot encode ${value.runtimeType} as Firestore JSON.',
      );
    },
  );
}
