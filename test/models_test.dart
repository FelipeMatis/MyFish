import 'package:myfish/models/catch_model.dart';
import 'package:myfish/models/user_model.dart';
import 'package:myfish/models/waypoint_model.dart';
import 'package:myfish/models/weather_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime.utc(2026, 11, 23, 12);

  test('UserModel maps user data and optional profile statistics', () {
    final user = UserModel(
      uid: 'user-1',
      displayName: 'Ana',
      email: 'ana@example.com',
      createdAt: date,
      totalCatches: 4,
      heaviestWeightKg: 3.5,
      longestLengthCm: 62,
      favoriteSpecies: 'Tucunaré',
    );

    final actual = UserModel.fromMap(user.toMap(), uid: user.uid);

    expect(actual.uid, user.uid);
    expect(actual.totalCatches, 4);
    expect(actual.heaviestWeightKg, 3.5);
    expect(actual.favoriteSpecies, 'Tucunaré');
  });

  test('CatchModel maps nested weather and capture details', () {
    final weather = WeatherModel(
      temperatureC: 25,
      pressureHpa: 1012,
      windSpeedMps: 3.2,
      windDirectionDegrees: 180,
      description: 'céu limpo',
      observedAt: date,
      conditionCode: '01d',
    );
    final capture = CatchModel(
      id: 'catch-1',
      userId: 'user-1',
      species: 'Tucunaré',
      capturedAt: date,
      weightKg: 2.4,
      lengthCm: 48,
      bait: 'Isca artificial',
      equipment: 'Vara e carretilha',
      modality: CatchModality.catchAndRelease,
      latitude: -23.5,
      longitude: -46.6,
      isPublic: true,
      weather: weather,
    );

    final actual = CatchModel.fromMap(capture.toMap(), id: capture.id);

    expect(actual.species, capture.species);
    expect(actual.modality, CatchModality.catchAndRelease);
    expect(actual.weather?.temperatureC, 25);
    expect(actual.isPublic, isTrue);
  });

  test('WaypointModel maps type, location, and privacy', () {
    final waypoint = WaypointModel(
      id: 'point-1',
      userId: 'user-1',
      name: 'Rampa',
      type: WaypointType.boatRamp,
      latitude: -23.5,
      longitude: -46.6,
      isPublic: false,
      createdAt: date,
      updatedAt: date,
    );

    final actual = WaypointModel.fromMap(waypoint.toMap(), id: waypoint.id);

    expect(actual.type, WaypointType.boatRamp);
    expect(actual.latitude, -23.5);
    expect(actual.isPublic, isFalse);
  });
}
