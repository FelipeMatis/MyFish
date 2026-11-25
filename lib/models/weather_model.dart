import 'firestore_value.dart';

class WeatherModel {
  /// Cria um modelo com as condições do tempo registradas.
  const WeatherModel({
    required this.temperatureC,
    required this.pressureHpa,
    required this.windSpeedMps,
    required this.windDirectionDegrees,
    required this.description,
    required this.observedAt,
    this.conditionCode,
  });

  final double temperatureC;
  final double pressureHpa;
  final double windSpeedMps;
  final double windDirectionDegrees;
  final String description;
  final DateTime observedAt;
  final String? conditionCode;

  /// Converte as condições do tempo para um mapa do Firestore.
  Map<String, dynamic> toMap() {
    return {
      'temperatureC': temperatureC,
      'pressureHpa': pressureHpa,
      'windSpeedMps': windSpeedMps,
      'windDirectionDegrees': windDirectionDegrees,
      'description': description,
      'observedAt': observedAt,
      'conditionCode': conditionCode,
    };
  }

  /// Reconstrói as condições do tempo a partir de um mapa.
  factory WeatherModel.fromMap(Map<String, dynamic> map) {
    return WeatherModel(
      temperatureC: (map['temperatureC'] as num).toDouble(),
      pressureHpa: (map['pressureHpa'] as num).toDouble(),
      windSpeedMps: (map['windSpeedMps'] as num).toDouble(),
      windDirectionDegrees: (map['windDirectionDegrees'] as num).toDouble(),
      description: map['description'] as String,
      observedAt: FirestoreValue.dateTime(map['observedAt'], 'observedAt'),
      conditionCode: map['conditionCode'] as String?,
    );
  }
}
