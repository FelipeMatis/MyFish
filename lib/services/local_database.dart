import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class PendingRecord {
  /// Cria uma operação local aguardando sincronização com o Firestore.
  const PendingRecord({
    required this.entity,
    required this.recordId,
    required this.userId,
    required this.operation,
    required this.updatedAt,
    this.payload,
    this.photoBase64,
  });

  final String entity;
  final String recordId;
  final String userId;
  final String operation;
  final String updatedAt;
  final String? payload;
  final String? photoBase64;

  /// Reconstrói uma operação pendente a partir de uma linha SQLite.
  factory PendingRecord.fromMap(Map<String, Object?> map) {
    return PendingRecord(
      entity: map['entity']! as String,
      recordId: map['recordId']! as String,
      userId: map['userId']! as String,
      operation: map['operation']! as String,
      updatedAt: map['updatedAt']! as String,
      payload: map['payload'] as String?,
      photoBase64: map['photoBase64'] as String?,
    );
  }

  /// Converte a operação para os campos armazenados no SQLite.
  Map<String, Object?> toMap() {
    return {
      'entity': entity,
      'recordId': recordId,
      'userId': userId,
      'operation': operation,
      'updatedAt': updatedAt,
      'payload': payload,
      'photoBase64': photoBase64,
    };
  }
}

class LocalDatabase {
  /// Cria o acesso ao banco padrão ou ao caminho fornecido para testes.
  LocalDatabase({this.databasePath});

  static final instance = LocalDatabase();

  final String? databasePath;
  final _changes = StreamController<void>.broadcast();
  Future<Database>? _databaseOpening;

  /// Notifica os observadores após alterações nos registros locais.
  Stream<void> get changes => _changes.stream;

  /// Abre o banco uma vez e reutiliza a conexão durante a sessão.
  Future<Database> get database {
    return _databaseOpening ??= _openDatabase();
  }

  /// Abre o banco e cria ou atualiza suas tabelas.
  Future<Database> _openDatabase() async {
    final dbPath =
        databasePath ??
        path.join(await getDatabasesPath(), 'myfish_offline.db');
    return openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_sync (
            entity TEXT NOT NULL,
            recordId TEXT NOT NULL,
            userId TEXT NOT NULL,
            operation TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            payload TEXT,
            photoBase64 TEXT,
            PRIMARY KEY (entity, recordId)
          )
        ''');
        await db.execute(
          'CREATE INDEX pending_sync_user ON pending_sync(userId, updatedAt)',
        );
        await _createCachedRecordsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createCachedRecordsTable(db);
      },
    );
  }

  /// Persiste uma alteração pendente e atualiza o cache local.
  Future<void> savePending(PendingRecord record) async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.insert(
        'pending_sync',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (record.operation == 'delete') {
        await transaction.delete(
          'cached_records',
          where: 'entity = ? AND recordId = ?',
          whereArgs: [record.entity, record.recordId],
        );
      } else {
        final existing = await transaction.query(
          'cached_records',
          columns: ['photoBase64'],
          where: 'entity = ? AND recordId = ?',
          whereArgs: [record.entity, record.recordId],
          limit: 1,
        );
        final photoBase64 =
            record.photoBase64 ??
            (existing.isEmpty
                ? null
                : existing.first['photoBase64'] as String?);
        await transaction.insert('cached_records', {
          ...record.toMap(),
          'photoBase64': photoBase64,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    _changes.add(null);
  }

  /// Lista os registros em cache de um usuário e tipo de entidade.
  Future<List<PendingRecord>> cachedForUser(
    String userId,
    String entity,
  ) async {
    final db = await database;
    final rows = await db.query(
      'cached_records',
      where: 'userId = ? AND entity = ?',
      whereArgs: [userId, entity],
    );
    return rows.map(PendingRecord.fromMap).toList();
  }

  /// Busca um registro em cache pelo tipo e identificador.
  Future<PendingRecord?> findCached(String entity, String recordId) async {
    final db = await database;
    final rows = await db.query(
      'cached_records',
      where: 'entity = ? AND recordId = ?',
      whereArgs: [entity, recordId],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingRecord.fromMap(rows.first);
  }

  /// Substitui o cache remoto sem perder as fotos já armazenadas localmente.
  Future<void> replaceCachedRecords(
    String userId,
    String entity,
    List<PendingRecord> records,
  ) async {
    final db = await database;
    await db.transaction((transaction) async {
      final oldRecords = await transaction.query(
        'cached_records',
        columns: ['recordId', 'photoBase64'],
        where: 'userId = ? AND entity = ?',
        whereArgs: [userId, entity],
      );
      final oldPhotos = {
        for (final record in oldRecords)
          record['recordId']! as String: record['photoBase64'] as String?,
      };
      await transaction.delete(
        'cached_records',
        where: 'userId = ? AND entity = ?',
        whereArgs: [userId, entity],
      );
      for (final record in records) {
        await transaction.insert('cached_records', {
          ...record.toMap(),
          'photoBase64': record.photoBase64 ?? oldPhotos[record.recordId],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    _changes.add(null);
  }

  /// Atualiza a foto em cache de uma captura.
  Future<void> updateCachedPhoto(
    String userId,
    String recordId,
    String photoBase64,
  ) async {
    final db = await database;
    await db.update(
      'cached_records',
      {'photoBase64': photoBase64},
      where: 'entity = ? AND recordId = ? AND userId = ?',
      whereArgs: ['catches', recordId, userId],
    );
    _changes.add(null);
  }

  /// Lista as operações pendentes de sincronização de um usuário.
  Future<List<PendingRecord>> pendingForUser(String userId) async {
    final db = await database;
    final rows = await db.query(
      'pending_sync',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt ASC',
    );
    return rows.map(PendingRecord.fromMap).toList();
  }

  /// Busca uma operação pendente pelo tipo e identificador do registro.
  Future<PendingRecord?> findPending(String entity, String recordId) async {
    final db = await database;
    final rows = await db.query(
      'pending_sync',
      where: 'entity = ? AND recordId = ?',
      whereArgs: [entity, recordId],
      limit: 1,
    );
    return rows.isEmpty ? null : PendingRecord.fromMap(rows.first);
  }

  /// Remove uma operação pendente, opcionalmente conferindo sua versão.
  Future<void> removePending(
    String entity,
    String recordId, {
    String? updatedAt,
  }) async {
    final db = await database;
    await db.delete(
      'pending_sync',
      where: updatedAt == null
          ? 'entity = ? AND recordId = ?'
          : 'entity = ? AND recordId = ? AND updatedAt = ?',
      whereArgs: updatedAt == null
          ? [entity, recordId]
          : [entity, recordId, updatedAt],
    );
    _changes.add(null);
  }

  /// Fecha a conexão SQLite aberta.
  Future<void> close() async {
    final opening = _databaseOpening;
    if (opening == null) return;
    final db = await opening;
    await db.close();
    _databaseOpening = null;
  }

  /// Cria a tabela que mantém o cache local de capturas e pontos.
  Future<void> _createCachedRecordsTable(DatabaseExecutor db) {
    return db.execute('''
      CREATE TABLE cached_records (
        entity TEXT NOT NULL,
        recordId TEXT NOT NULL,
        userId TEXT NOT NULL,
        operation TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        payload TEXT,
        photoBase64 TEXT,
        PRIMARY KEY (entity, recordId)
      )
    ''');
  }
}
