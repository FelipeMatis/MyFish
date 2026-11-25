import 'firestore_value.dart';
import 'weather_model.dart';

enum CatchModality { catchAndRelease, harvest }

class CatchModel {
  /// Cria um modelo imutável com os dados de uma captura.
  const CatchModel({
    required this.id,
    required this.userId,
    required this.species,
    required this.capturedAt,
    required this.bait,
    required this.equipment,
    required this.modality,
    required this.latitude,
    required this.longitude,
    required this.isPublic,
    this.weightKg,
    this.lengthCm,
    this.observations,
    this.photoBase64,
    this.weather,
    this.isPendingSync = false,
  });

  final String id;
  final String userId;
  final String species;
  final DateTime capturedAt;
  final double? weightKg;
  final double? lengthCm;
  final String bait;
  final String equipment;
  final CatchModality modality;
  final String? observations;
  final String? photoBase64;
  final double latitude;
  final double longitude;
  final WeatherModel? weather;
  final bool isPublic;
  final bool isPendingSync;

  /// Retorna uma cópia com os campos selecionados atualizados.
  CatchModel copyWith({String? id, String? photoBase64, bool? isPendingSync}) {
    return CatchModel(
      id: id ?? this.id,
      userId: userId,
      species: species,
      capturedAt: capturedAt,
      weightKg: weightKg,
      lengthCm: lengthCm,
      bait: bait,
      equipment: equipment,
      modality: modality,
      observations: observations,
      photoBase64: photoBase64 ?? this.photoBase64,
      latitude: latitude,
      longitude: longitude,
      weather: weather,
      isPublic: isPublic,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  /// Converte a captura para um mapa compatível com o Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'species': species,
      'capturedAt': capturedAt,
      'weightKg': weightKg,
      'lengthCm': lengthCm,
      'bait': bait,
      'equipment': equipment,
      'modality': modality.name,
      'observations': observations,
      'photoBase64': photoBase64,
      'latitude': latitude,
      'longitude': longitude,
      'weather': weather?.toMap(),
      'isPublic': isPublic,
    };
  }

  /// Cria uma captura a partir dos dados recebidos do Firestore.
  factory CatchModel.fromMap(Map<String, dynamic> map, {required String id}) {
    final weatherData = map['weather'];
    if (weatherData != null && weatherData is! Map) {
      throw const FormatException('Invalid Firestore value for "weather".');
    }

    return CatchModel(
      id: id,
      userId: map['userId'] as String,
      species: map['species'] as String,
      capturedAt: FirestoreValue.dateTime(map['capturedAt'], 'capturedAt'),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      lengthCm: (map['lengthCm'] as num?)?.toDouble(),
      bait: map['bait'] as String,
      equipment: map['equipment'] as String,
      modality: CatchModality.values.byName(map['modality'] as String),
      observations: map['observations'] as String?,
      photoBase64: (map['photoBase64'] ?? map['photoUrl']) as String?,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      weather: weatherData == null
          ? null
          : WeatherModel.fromMap(Map<String, dynamic>.from(weatherData)),
      isPublic: map['isPublic'] as bool? ?? false,
      isPendingSync: map['isPendingSync'] as bool? ?? false,
    );
  }
}
