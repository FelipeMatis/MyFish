import 'firestore_value.dart';

enum WaypointType { fishingSpot, structure, boatRamp, fishery, other }

class WaypointModel {
  /// Cria um modelo para um ponto salvo no mapa.
  const WaypointModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isPendingSync = false,
  });

  final String id;
  final String userId;
  final String name;
  final WaypointType type;
  final double latitude;
  final double longitude;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final bool isPendingSync;

  /// Retorna uma cópia com os campos selecionados atualizados.
  WaypointModel copyWith({String? id, bool? isPendingSync}) {
    return WaypointModel(
      id: id ?? this.id,
      userId: userId,
      name: name,
      type: type,
      latitude: latitude,
      longitude: longitude,
      isPublic: isPublic,
      createdAt: createdAt,
      updatedAt: updatedAt,
      description: description,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  /// Converte o ponto para um mapa compatível com o Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'type': type.name,
      'latitude': latitude,
      'longitude': longitude,
      'isPublic': isPublic,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'description': description,
    };
  }

  /// Cria um ponto a partir dos dados recebidos do Firestore.
  factory WaypointModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return WaypointModel(
      id: id,
      userId: map['userId'] as String,
      name: map['name'] as String,
      type: WaypointType.values.byName(map['type'] as String),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      isPublic: map['isPublic'] as bool? ?? false,
      createdAt: FirestoreValue.dateTime(map['createdAt'], 'createdAt'),
      updatedAt: FirestoreValue.dateTime(map['updatedAt'], 'updatedAt'),
      description: map['description'] as String?,
      isPendingSync: map['isPendingSync'] as bool? ?? false,
    );
  }
}
