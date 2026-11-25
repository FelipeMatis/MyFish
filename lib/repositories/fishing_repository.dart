import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/catch_model.dart';
import '../models/waypoint_model.dart';
import '../services/firestore_json.dart';
import '../services/local_database.dart';

class SaveResult {
  /// Cria o resultado de uma tentativa de gravação local ou remota.
  const SaveResult({required this.id, required this.isSynced, this.message});

  final String id;
  final bool isSynced;
  final String? message;
}

class FishingRepository {
  /// Cria o repositório com serviços reais ou dependências substitutas.
  FishingRepository({
    FirebaseFirestore? firestore,
    LocalDatabase? localDatabase,
    Connectivity? connectivity,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localDatabase = localDatabase ?? LocalDatabase.instance,
       _connectivity = connectivity ?? Connectivity(),
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final LocalDatabase _localDatabase;
  final Connectivity _connectivity;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _catches =>
      _firestore.collection('catches');

  CollectionReference<Map<String, dynamic>> get _waypoints =>
      _firestore.collection('waypoints');

  CollectionReference<Map<String, dynamic>> get _catchPhotos =>
      _firestore.collection('catchPhotos');

  /// Observa capturas do usuário combinando dados remotos e cache local.
  Stream<List<CatchModel>> watchUserCatches(String userId) {
    final remote = _catches
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
          final catches = snapshot.docs
              .map((doc) => CatchModel.fromMap(doc.data(), id: doc.id))
              .toList();
          if (!snapshot.metadata.isFromCache) {
            await _localDatabase.replaceCachedRecords(
              userId,
              'catches',
              catches
                  .map(
                    (capture) => PendingRecord(
                      entity: 'catches',
                      recordId: capture.id,
                      userId: userId,
                      operation: 'upsert',
                      updatedAt: DateTime.now().toUtc().toIso8601String(),
                      payload: encodeFirestoreJson(
                        capture.toMap()..remove('photoBase64'),
                      ),
                    ),
                  )
                  .toList(),
            );
          }
          return catches;
        });
    return _watchMerged(
      userId: userId,
      entity: 'catches',
      remote: remote,
      merge: (remoteRecords, cachedRecords, pendingRecords) {
        final records = {for (final item in remoteRecords) item.id: item};
        for (final cached in cachedRecords) {
          final data = jsonDecode(cached.payload!) as Map<String, dynamic>
            ..['photoBase64'] = cached.photoBase64;
          final capture = CatchModel.fromMap(data, id: cached.recordId);
          final remoteCapture = records[cached.recordId];
          if (remoteCapture == null) {
            records[cached.recordId] = capture;
          } else if (remoteCapture.photoBase64 == null &&
              capture.photoBase64 != null) {
            records[cached.recordId] = remoteCapture.copyWith(
              photoBase64: capture.photoBase64,
            );
          }
        }
        for (final pending in pendingRecords) {
          if (pending.operation == 'delete') {
            records.remove(pending.recordId);
            continue;
          }
          final data = jsonDecode(pending.payload!) as Map<String, dynamic>;
          data['photoBase64'] = pending.photoBase64;
          records[pending.recordId] = CatchModel.fromMap(
            data,
            id: pending.recordId,
          ).copyWith(isPendingSync: true);
        }
        final result = records.values.toList()
          ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
        return result;
      },
    );
  }

  /// Observa as capturas públicas disponíveis no Firestore.
  Stream<List<CatchModel>> watchPublicCatches() {
    return _catches.where('isPublic', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final catches = snapshot.docs
          .map((doc) => CatchModel.fromMap(doc.data(), id: doc.id))
          .toList();
      catches.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
      return catches;
    });
  }

  /// Observa pontos do usuário combinando dados remotos e cache local.
  Stream<List<WaypointModel>> watchUserWaypoints(String userId) {
    final remote = _waypoints
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .asyncMap((snapshot) async {
          final waypoints = snapshot.docs
              .map((doc) => WaypointModel.fromMap(doc.data(), id: doc.id))
              .toList();
          if (!snapshot.metadata.isFromCache) {
            await _localDatabase.replaceCachedRecords(
              userId,
              'waypoints',
              waypoints
                  .map(
                    (waypoint) => PendingRecord(
                      entity: 'waypoints',
                      recordId: waypoint.id,
                      userId: userId,
                      operation: 'upsert',
                      updatedAt: DateTime.now().toUtc().toIso8601String(),
                      payload: encodeFirestoreJson(waypoint.toMap()),
                    ),
                  )
                  .toList(),
            );
          }
          return waypoints;
        });
    return _watchMerged(
      userId: userId,
      entity: 'waypoints',
      remote: remote,
      merge: (remoteRecords, cachedRecords, pendingRecords) {
        final records = {for (final item in remoteRecords) item.id: item};
        for (final cached in cachedRecords) {
          final data = jsonDecode(cached.payload!) as Map<String, dynamic>;
          records.putIfAbsent(
            cached.recordId,
            () => WaypointModel.fromMap(data, id: cached.recordId),
          );
        }
        for (final pending in pendingRecords) {
          if (pending.operation == 'delete') {
            records.remove(pending.recordId);
            continue;
          }
          final data = jsonDecode(pending.payload!) as Map<String, dynamic>;
          records[pending.recordId] = WaypointModel.fromMap(
            data,
            id: pending.recordId,
          ).copyWith(isPendingSync: true);
        }
        return records.values.toList();
      },
    );
  }

  /// Observa os pontos públicos disponíveis no Firestore.
  Stream<List<WaypointModel>> watchPublicWaypoints() {
    return _waypoints
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => WaypointModel.fromMap(doc.data(), id: doc.id))
              .toList(),
        );
  }

  /// Combina atualizações remotas com cache e operações locais pendentes.
  Stream<List<T>> _watchMerged<T>({
    required String userId,
    required String entity,
    required Stream<List<T>> remote,
    required List<T> Function(List<T>, List<PendingRecord>, List<PendingRecord>)
    merge,
  }) {
    final controller = StreamController<List<T>>();
    StreamSubscription<List<T>>? remoteSubscription;
    StreamSubscription<void>? localSubscription;
    var remoteRecords = <T>[];
    var revision = 0;

    /// Emite uma lista atualizada após consultar cache e fila local.
    Future<void> emit() async {
      final currentRevision = ++revision;
      try {
        final pending = (await _localDatabase.pendingForUser(userId))
            .where((record) => record.entity == entity)
            .toList();
        final cached = await _localDatabase.cachedForUser(userId, entity);
        if (!controller.isClosed && currentRevision == revision) {
          controller.add(merge(remoteRecords, cached, pending));
        }
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller.onListen = () {
      localSubscription = _localDatabase.changes.listen((_) => emit());
      remoteSubscription = remote.listen(
        (records) {
          remoteRecords = records;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          controller.addError(error, stackTrace);
        },
      );
      emit();
    };
    controller.onCancel = () async {
      await remoteSubscription?.cancel();
      await localSubscription?.cancel();
    };
    return controller.stream;
  }

  /// Salva uma captura localmente e tenta sincronizá-la.
  Future<SaveResult> createCatch(CatchModel capture) async {
    final id = capture.id.isEmpty ? _uuid.v4() : capture.id;
    final localCapture = capture.copyWith(id: id, isPendingSync: true);
    await _queueCapture(localCapture, 'upsert');
    final message = await _syncPendingForUser(capture.userId);
    final pending = await _localDatabase.findPending('catches', id);
    return SaveResult(id: id, isSynced: pending == null, message: message);
  }

  /// Atualiza uma captura existente e sincroniza a alteração.
  Future<SaveResult> updateCatch(CatchModel capture) async {
    final localCapture = capture.copyWith(isPendingSync: true);
    await _queueCapture(localCapture, 'upsert');
    final message = await _syncPendingForUser(capture.userId);
    final pending = await _localDatabase.findPending('catches', capture.id);
    return SaveResult(
      id: capture.id,
      isSynced: pending == null,
      message: message,
    );
  }

  /// Registra a exclusão local e tenta removê-la do Firestore.
  Future<SaveResult> deleteCatch(String id, String userId) async {
    await _localDatabase.savePending(
      PendingRecord(
        entity: 'catches',
        recordId: id,
        userId: userId,
        operation: 'delete',
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    final message = await _syncPendingForUser(userId);
    final pending = await _localDatabase.findPending('catches', id);
    return SaveResult(id: id, isSynced: pending == null, message: message);
  }

  /// Carrega a foto da fila local, do cache ou do Firestore.
  Future<String?> loadCatchPhoto(String catchId) async {
    final pending = await _localDatabase.findPending('catches', catchId);
    if (pending?.operation == 'delete') return null;
    if (pending?.photoBase64 != null) {
      return pending!.photoBase64;
    }
    final cached = await _localDatabase.findCached('catches', catchId);
    try {
      final snapshot = await _catchPhotos.doc(catchId).get();
      final data = snapshot.data();
      final photoBase64 = data?['photoBase64'] as String?;
      final userId = data?['userId'] as String?;
      if (photoBase64 != null && userId != null) {
        await _localDatabase.updateCachedPhoto(userId, catchId, photoBase64);
      }
      return photoBase64 ?? cached?.photoBase64;
    } on FirebaseException {
      if (cached?.photoBase64 != null) return cached!.photoBase64;
      rethrow;
    }
  }

  /// Salva um ponto localmente e tenta sincronizá-lo com o Firestore.
  Future<SaveResult> createWaypoint(WaypointModel waypoint) async {
    final id = waypoint.id.isEmpty ? _uuid.v4() : waypoint.id;
    final localWaypoint = waypoint.copyWith(id: id, isPendingSync: true);
    await _queueWaypoint(localWaypoint, 'upsert');
    final pending = await _localDatabase.findPending('waypoints', id);
    if (pending == null) {
      throw StateError('O ponto foi enfileirado, mas não está no banco local.');
    }

    try {
      await _syncWaypoint(pending).timeout(const Duration(seconds: 12));
      await _localDatabase.removePending(
        'waypoints',
        id,
        updatedAt: pending.updatedAt,
      );
      return SaveResult(
        id: id,
        isSynced: true,
        message: 'Ponto salvo no Firestore.',
      );
    } on TimeoutException {
      return SaveResult(
        id: id,
        isSynced: false,
        message:
            'Ponto salvo neste dispositivo, mas a sincronização demorou. '
            'Ele será enviado quando a conexão estiver disponível.',
      );
    } on FirebaseException catch (error) {
      return SaveResult(
        id: id,
        isSynced: false,
        message: _firebaseSyncMessage(error),
      );
    }
  }

  /// Registra a exclusão local e tenta removê-la do Firestore.
  Future<SaveResult> deleteWaypoint(String id, String userId) async {
    await _localDatabase.savePending(
      PendingRecord(
        entity: 'waypoints',
        recordId: id,
        userId: userId,
        operation: 'delete',
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    final message = await _syncPendingForUser(userId);
    final pending = await _localDatabase.findPending('waypoints', id);
    return SaveResult(id: id, isSynced: pending == null, message: message);
  }

  /// Inicia a sincronização das operações pendentes do usuário.
  Future<String?> syncPendingForUser(String userId) {
    return _syncPendingForUser(userId);
  }

  /// Converte uma captura em uma operação persistente na fila local.
  Future<void> _queueCapture(CatchModel capture, String operation) {
    final data = capture.toMap()..remove('photoBase64');
    return _localDatabase.savePending(
      PendingRecord(
        entity: 'catches',
        recordId: capture.id,
        userId: capture.userId,
        operation: operation,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        payload: encodeFirestoreJson(data),
        photoBase64: capture.photoBase64,
      ),
    );
  }

  /// Converte um ponto em uma operação persistente na fila local.
  Future<void> _queueWaypoint(WaypointModel waypoint, String operation) {
    return _localDatabase.savePending(
      PendingRecord(
        entity: 'waypoints',
        recordId: waypoint.id,
        userId: waypoint.userId,
        operation: operation,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        payload: encodeFirestoreJson(waypoint.toMap()),
      ),
    );
  }

  /// Envia as operações pendentes do usuário ao Firestore em ordem.
  Future<String?> _syncPendingForUser(String userId) async {
    final pending = await _localDatabase.pendingForUser(userId);
    if (pending.isEmpty) return null;

    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.every((result) => result == ConnectivityResult.none)) {
      return 'Sem internet. Registro salvo localmente e aguardando sincronização.';
    }

    for (final record in pending) {
      try {
        await _syncRecord(record).timeout(const Duration(seconds: 12));
        await _localDatabase.removePending(
          record.entity,
          record.recordId,
          updatedAt: record.updatedAt,
        );
      } on TimeoutException {
        return 'Sincronização demorou. O registro permanece salvo neste dispositivo.';
      } on FirebaseException catch (error) {
        return _firebaseSyncMessage(error);
      }
    }
    return null;
  }

  /// Encaminha uma operação pendente ao sincronizador da entidade correta.
  Future<void> _syncRecord(PendingRecord record) {
    if (record.entity == 'catches') {
      return _syncCatch(record);
    }
    if (record.entity == 'waypoints') {
      return _syncWaypoint(record);
    }
    throw StateError(
      'Tipo de registro pendente desconhecido: ${record.entity}',
    );
  }

  /// Sincroniza uma captura e sua foto em uma operação Firestore.
  Future<void> _syncCatch(PendingRecord record) async {
    final captureReference = _catches.doc(record.recordId);
    final photoReference = _catchPhotos.doc(record.recordId);
    final batch = _firestore.batch();

    if (record.operation == 'delete') {
      batch.delete(captureReference);
      batch.delete(photoReference);
    } else {
      final data = jsonDecode(record.payload!) as Map<String, dynamic>;
      batch.set(captureReference, data);
      if (record.photoBase64 == null) {
        batch.delete(photoReference);
      } else {
        batch.set(photoReference, {
          'userId': record.userId,
          'isPublic': data['isPublic'] == true,
          'photoBase64': record.photoBase64,
        });
      }
    }
    await batch.commit();
  }

  /// Sincroniza um ponto ou sua exclusão com o Firestore.
  Future<void> _syncWaypoint(PendingRecord record) async {
    final reference = _waypoints.doc(record.recordId);
    if (record.operation == 'delete') {
      await reference.delete();
    } else {
      final data = jsonDecode(record.payload!) as Map<String, dynamic>;
      await reference.set(data);
    }
  }

  /// Traduz erros do Firebase em mensagens compreensíveis para o usuário.
  String _firebaseSyncMessage(FirebaseException error) {
    if (error.code == 'permission-denied') {
      return 'Registro salvo localmente, mas o Firebase negou o acesso. '
          'Confira as regras do Firestore.';
    }
    if (error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'network-request-failed') {
      return 'Sem conexão com o Firebase. Registro salvo localmente para sincronizar depois.';
    }
    return 'Registro salvo localmente. Falha de sincronização: '
        '${error.message ?? error.code}';
  }
}
