import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:myfish/services/local_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'pending operations survive reopening and can be replaced/deleted',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'myfish-db-test-',
      );
      final databasePath = path.join(directory.path, 'pending.db');
      var database = LocalDatabase(databasePath: databasePath);
      const first = PendingRecord(
        entity: 'catches',
        recordId: 'capture-1',
        userId: 'user-1',
        operation: 'upsert',
        updatedAt: '2026-11-23T12:00:00Z',
        payload: '{"species":"Tucunaré"}',
        photoBase64: 'encoded-photo',
      );

      await database.savePending(first);
      expect(
        (await database.cachedForUser('user-1', 'catches')).single.photoBase64,
        'encoded-photo',
      );
      await database.close();

      database = LocalDatabase(databasePath: databasePath);
      final persisted = await database.pendingForUser('user-1');
      expect(persisted, hasLength(1));
      expect(persisted.single.payload, first.payload);
      expect(
        (await database.cachedForUser('user-1', 'catches')).single.payload,
        first.payload,
      );

      await database.replaceCachedRecords('user-1', 'catches', [
        const PendingRecord(
          entity: 'catches',
          recordId: 'capture-1',
          userId: 'user-1',
          operation: 'upsert',
          updatedAt: '2026-11-23T12:02:00Z',
          payload: '{"species":"Dourado"}',
        ),
      ]);
      final refreshed = (await database.cachedForUser(
        'user-1',
        'catches',
      )).single;
      expect(refreshed.payload, '{"species":"Dourado"}');
      expect(refreshed.photoBase64, 'encoded-photo');

      await database.savePending(
        const PendingRecord(
          entity: 'catches',
          recordId: 'capture-1',
          userId: 'user-1',
          operation: 'delete',
          updatedAt: '2026-11-23T12:01:00Z',
        ),
      );
      await database.removePending(
        'catches',
        'capture-1',
        updatedAt: first.updatedAt,
      );
      expect(
        (await database.pendingForUser('user-1')).single.operation,
        'delete',
      );
      expect(await database.cachedForUser('user-1', 'catches'), isEmpty);

      await database.removePending('catches', 'capture-1');
      expect(await database.pendingForUser('user-1'), isEmpty);
      await database.savePending(first);
      await database.removePending(
        'catches',
        'capture-1',
        updatedAt: first.updatedAt,
      );
      expect(await database.pendingForUser('user-1'), isEmpty);
      expect(await database.cachedForUser('user-1', 'catches'), hasLength(1));
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
