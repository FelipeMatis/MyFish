import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:myfish/models/waypoint_model.dart';
import 'package:myfish/services/firestore_json.dart';

void main() {
  test('encodes waypoint dates and restores them from the local queue', () {
    final createdAt = DateTime.utc(2026, 11, 24, 10, 30);
    final updatedAt = createdAt.add(const Duration(minutes: 5));
    final waypoint = WaypointModel(
      id: 'waypoint-1',
      userId: 'user-1',
      name: 'Ponto de pesca',
      type: WaypointType.fishingSpot,
      latitude: -23.5,
      longitude: -46.6,
      isPublic: false,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    final json = encodeFirestoreJson(waypoint.toMap());
    final decoded = Map<String, dynamic>.from(jsonDecode(json) as Map);
    final restored = WaypointModel.fromMap(decoded, id: waypoint.id);

    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.name, waypoint.name);
  });
}
