import 'package:cloud_firestore/cloud_firestore.dart';

abstract final class FirestoreValue {
  /// Converte uma data do Firestore ou JSON para `DateTime`.
  static DateTime dateTime(Object? value, String fieldName) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Invalid Firestore date for "$fieldName".');
  }
}
