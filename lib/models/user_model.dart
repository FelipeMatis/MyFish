import 'firestore_value.dart';

class UserModel {
  /// Cria um modelo com os dados do perfil do pescador.
  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.photoUrl,
    this.totalCatches = 0,
    this.heaviestWeightKg,
    this.longestLengthCm,
    this.favoriteSpecies,
  });

  final String uid;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final String? photoUrl;
  final int totalCatches;
  final double? heaviestWeightKg;
  final double? longestLengthCm;
  final String? favoriteSpecies;

  /// Converte os dados do perfil para um mapa do Firestore.
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'createdAt': createdAt,
      'photoUrl': photoUrl,
      'totalCatches': totalCatches,
      'heaviestWeightKg': heaviestWeightKg,
      'longestLengthCm': longestLengthCm,
      'favoriteSpecies': favoriteSpecies,
    };
  }

  /// Reconstrói o perfil a partir de um mapa do Firestore.
  factory UserModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    return UserModel(
      uid: uid,
      displayName: map['displayName'] as String,
      email: map['email'] as String,
      createdAt: FirestoreValue.dateTime(map['createdAt'], 'createdAt'),
      photoUrl: map['photoUrl'] as String?,
      totalCatches: (map['totalCatches'] as num?)?.toInt() ?? 0,
      heaviestWeightKg: (map['heaviestWeightKg'] as num?)?.toDouble(),
      longestLengthCm: (map['longestLengthCm'] as num?)?.toDouble(),
      favoriteSpecies: map['favoriteSpecies'] as String?,
    );
  }
}
