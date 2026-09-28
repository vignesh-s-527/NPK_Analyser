import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local-only data store. Bump schema version and add a migration case on change.
class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  late Database db;
  Future<void> initialize() async {
    final root = await getDatabasesPath();
    db = await openDatabase(p.join(root, 'npk_farmer.db'),
        version: 4,
        onCreate: (d, _) async {
          await d.execute(
              'CREATE TABLE profile(id INTEGER PRIMARY KEY CHECK(id=1), name TEXT, language TEXT NOT NULL DEFAULT \'en\', tutorial_done INTEGER NOT NULL DEFAULT 0)');
          await d.insert(
              'profile', {'id': 1, 'language': 'en', 'tutorial_done': 0});
          await d.execute(
              'CREATE TABLE farms(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, location TEXT NOT NULL DEFAULT \'\', lat REAL, lon REAL)');
          await d.execute(
              'CREATE TABLE fields(id INTEGER PRIMARY KEY AUTOINCREMENT, farm_id INTEGER NOT NULL REFERENCES farms(id) ON DELETE CASCADE, name TEXT NOT NULL, area TEXT NOT NULL DEFAULT \'\')');
          await d.execute(
              'CREATE TABLE photos(id INTEGER PRIMARY KEY AUTOINCREMENT, owner_type TEXT NOT NULL, owner_id INTEGER NOT NULL, path TEXT NOT NULL)');
          await d.execute(
              'CREATE TABLE devices(id TEXT PRIMARY KEY, name TEXT NOT NULL)');
          await d.execute(
              'CREATE TABLE tests(id INTEGER PRIMARY KEY AUTOINCREMENT, field_id INTEGER NOT NULL REFERENCES fields(id) ON DELETE CASCADE, tested_at TEXT NOT NULL, n REAL NOT NULL, p REAL NOT NULL, k REAL NOT NULL, unit TEXT NOT NULL, note TEXT NOT NULL DEFAULT \'\', favorite INTEGER NOT NULL DEFAULT 0, source TEXT NOT NULL DEFAULT \'manual\', backend_reading_id TEXT, sync_status TEXT NOT NULL DEFAULT \'local\')');
          await d.execute(
              'CREATE TABLE crops(id INTEGER PRIMARY KEY AUTOINCREMENT, farm_id INTEGER NOT NULL REFERENCES farms(id) ON DELETE CASCADE, crop TEXT NOT NULL, UNIQUE(farm_id,crop))');
          await d.execute(
              'CREATE TABLE chat_messages(id INTEGER PRIMARY KEY AUTOINCREMENT, role TEXT NOT NULL CHECK(role IN (\'farmer\', \'assistant\')), content TEXT NOT NULL, sources TEXT NOT NULL DEFAULT \'[]\', created_at TEXT NOT NULL, answer_type TEXT, provider_status TEXT, insufficient_information INTEGER NOT NULL DEFAULT 0)');
        },
        onUpgrade: (d, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await d.execute(
                "ALTER TABLE tests ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'");
            await d.execute(
                'ALTER TABLE tests ADD COLUMN backend_reading_id TEXT');
            await d.execute(
                "ALTER TABLE tests ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'local'");
          }
          if (oldVersion < 3) {
            await d.execute(
                'CREATE TABLE chat_messages(id INTEGER PRIMARY KEY AUTOINCREMENT, role TEXT NOT NULL CHECK(role IN (\'farmer\', \'assistant\')), content TEXT NOT NULL, sources TEXT NOT NULL DEFAULT \'[]\', created_at TEXT NOT NULL)');
          }
          if (oldVersion < 4) {
            await d.execute(
                'ALTER TABLE chat_messages ADD COLUMN answer_type TEXT');
            await d.execute(
                'ALTER TABLE chat_messages ADD COLUMN provider_status TEXT');
            await d.execute(
                'ALTER TABLE chat_messages ADD COLUMN insufficient_information INTEGER NOT NULL DEFAULT 0');
          }
        },
        onConfigure: (d) async => d.execute('PRAGMA foreign_keys=ON'));
  }

  Future<Map<String, Object?>?> profile() async {
    final rows = await db.query('profile', where: 'id=1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> setLanguage(String language) async =>
      db.update('profile', {'language': language}, where: 'id=1');
  Future<void> setProfileName(String? name) async =>
      db.update('profile', {'name': name}, where: 'id=1');
  Future<void> markTutorialDone() async =>
      db.update('profile', {'tutorial_done': 1}, where: 'id=1');
  Future<List<Map<String, Object?>>> farms() =>
      db.query('farms', orderBy: 'id DESC');
  Future<List<Map<String, Object?>>> fields(int farmId) => db.query('fields',
      where: 'farm_id=?', whereArgs: [farmId], orderBy: 'id DESC');
  Future<int> saveFarm(
      {int? id,
      required String name,
      required String location,
      double? lat,
      double? lon}) async {
    final values = {'name': name, 'location': location, 'lat': lat, 'lon': lon};
    if (id == null) return db.insert('farms', values);
    await db.update('farms', values, where: 'id=?', whereArgs: [id]);
    return id;
  }

  Future<int> saveField(
      {int? id,
      required int farmId,
      required String name,
      required String area}) async {
    final values = {'farm_id': farmId, 'name': name, 'area': area};
    if (id == null) return db.insert('fields', values);
    await db.update('fields', values, where: 'id=?', whereArgs: [id]);
    return id;
  }

  Future<void> deleteFarm(int id) async => db.transaction((txn) async {
        final fieldRows = await txn.query('fields',
            columns: ['id'], where: 'farm_id=?', whereArgs: [id]);
        for (final row in fieldRows) {
          await txn.delete('photos',
              where: 'owner_type=? AND owner_id=?',
              whereArgs: ['field', row['id']]);
        }
        await txn.delete('photos',
            where: 'owner_type=? AND owner_id=?', whereArgs: ['farm', id]);
        await txn.delete('crops', where: 'farm_id=?', whereArgs: [id]);
        await txn.delete('farms', where: 'id=?', whereArgs: [id]);
      });
  Future<void> deleteField(int id) async => db.transaction((txn) async {
        await txn.delete('photos',
            where: 'owner_type=? AND owner_id=?', whereArgs: ['field', id]);
        await txn.delete('fields', where: 'id=?', whereArgs: [id]);
      });
  Future<List<Map<String, Object?>>> photos(String type, int ownerId) =>
      db.query('photos',
          where: 'owner_type=? AND owner_id=?', whereArgs: [type, ownerId]);
  Future<int> addPhoto(String type, int ownerId, String path) => db.insert(
      'photos', {'owner_type': type, 'owner_id': ownerId, 'path': path});
  Future<void> deletePhoto(int id) async =>
      db.delete('photos', where: 'id=?', whereArgs: [id]);
  Future<void> saveDevice(String id, String name) async =>
      db.insert('devices', {'id': id, 'name': name},
          conflictAlgorithm: ConflictAlgorithm.replace);
  Future<List<Map<String, Object?>>> devices() =>
      db.query('devices', orderBy: 'name');
  Future<void> deleteDevice(String id) async =>
      db.delete('devices', where: 'id=?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> crops(int farmId) => db.query('crops',
      where: 'farm_id=?', whereArgs: [farmId], orderBy: 'crop');
  Future<void> addCrop(int farmId, String crop) async =>
      db.insert('crops', {'farm_id': farmId, 'crop': crop},
          conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<void> removeCrop(int id) async =>
      db.delete('crops', where: 'id=?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> allPhotos() => db.query('photos');
  Future<void> clearFarmerData() async => db.transaction((txn) async {
        await txn.delete('tests');
        await txn.delete('crops');
        await txn.delete('fields');
        await txn.delete('farms');
        await txn.delete('devices');
        await txn.delete('photos');
        await txn.delete('chat_messages');
      });
  Future<int> addChatMessage(
          {required String role,
          required String content,
          List<String> sources = const [],
          String? answerType,
          String? providerStatus,
          bool insufficientInformation = false}) =>
      db.insert('chat_messages', {
        'role': role,
        'content': content,
        'sources': jsonEncode(sources),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'answer_type': answerType,
        'provider_status': providerStatus,
        'insufficient_information': insufficientInformation ? 1 : 0,
      });
  Future<List<Map<String, Object?>>> chatMessages({int limit = 100}) => db
      .query('chat_messages', orderBy: 'id DESC', limit: limit)
      .then((rows) => rows.reversed.toList());
  Future<List<Map<String, Object?>>> testHistory(int fieldId) =>
      db.query('tests',
          where: 'field_id=?', whereArgs: [fieldId], orderBy: 'tested_at ASC');
  Future<
      List<
          Map<String, Object?>>> latestTests({int limit = 3}) => db.rawQuery(
      'SELECT tests.*, fields.name AS field_name FROM tests INNER JOIN fields ON fields.id=tests.field_id ORDER BY tested_at DESC LIMIT ?',
      [limit]);
  Future<int> saveTest(
          {required int fieldId,
          required double n,
          required double p,
          required double k,
          required String unit,
          DateTime? testedAt,
          String source = 'manual',
          String note = '',
          bool favorite = false}) =>
      db.insert('tests', {
        'field_id': fieldId,
        'tested_at': (testedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'n': n,
        'p': p,
        'k': k,
        'unit': unit,
        'source': source,
        'sync_status': 'local',
        'note': note,
        'favorite': favorite ? 1 : 0
      });
  Future<void> markTestSynced(int id, String backendReadingId) async =>
      db.update('tests',
          {'backend_reading_id': backendReadingId, 'sync_status': 'synced'},
          where: 'id=?', whereArgs: [id]);
  Future<void> updateTest(int id,
          {required String note, required bool favorite}) async =>
      db.update('tests', {'note': note, 'favorite': favorite ? 1 : 0},
          where: 'id=?', whereArgs: [id]);
  Future<void> deleteTest(int id) async =>
      db.delete('tests', where: 'id=?', whereArgs: [id]);
}
