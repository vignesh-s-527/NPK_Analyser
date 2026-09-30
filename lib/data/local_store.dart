import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/domain.dart';

/// Local-only data store. Bump schema version and add a migration case on change.
class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  late Database db;
  Future<void> initialize() async {
    final root = await getDatabasesPath();
    db = await openDatabase(p.join(root, 'npk_farmer.db'),
        version: 7,
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
          await _createFarmingTables(d);
          await _createNotificationTables(d);
          await d.execute(
              'ALTER TABLE farming_tasks ADD COLUMN field_id INTEGER REFERENCES fields(id) ON DELETE SET NULL');
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
          if (oldVersion < 5) await _createFarmingTables(d);
          if (oldVersion < 6) await _createNotificationTables(d);
          if (oldVersion < 7)
            await d.execute(
                'ALTER TABLE farming_tasks ADD COLUMN field_id INTEGER REFERENCES fields(id) ON DELETE SET NULL');
        },
        onConfigure: (d) async => d.execute('PRAGMA foreign_keys=ON'));
  }

  Future<void> _createFarmingTables(DatabaseExecutor d) async {
    await d.execute(
        'CREATE TABLE farming_tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, farm_id INTEGER NOT NULL REFERENCES farms(id) ON DELETE CASCADE, type TEXT NOT NULL, title TEXT NOT NULL, due_at TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0)');
    await d.execute(
        'CREATE TABLE terrace_progress(id INTEGER PRIMARY KEY CHECK(id=1), space TEXT NOT NULL DEFAULT \'small\', sunlight TEXT NOT NULL DEFAULT \'unknown\', experience TEXT NOT NULL DEFAULT \'beginner\', budget TEXT NOT NULL DEFAULT \'low\', checklist TEXT NOT NULL DEFAULT \'[]\')');
    await d.execute('CREATE TABLE saved_crops(crop TEXT PRIMARY KEY)');
    await d.insert('terrace_progress', {'id': 1});
  }

  Future<void> _createNotificationTables(DatabaseExecutor d) async {
    await d.execute(
        'CREATE TABLE notification_preferences(category TEXT PRIMARY KEY, enabled INTEGER NOT NULL DEFAULT 1)');
    await d.execute(
        'CREATE TABLE notification_history(id INTEGER PRIMARY KEY AUTOINCREMENT, notification_id INTEGER NOT NULL, category TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL, scheduled_for TEXT NOT NULL, related_farm_id INTEGER, related_task_id INTEGER, is_read INTEGER NOT NULL DEFAULT 0, is_scheduled INTEGER NOT NULL DEFAULT 0)');
    for (final category in const [
      'watering',
      'fertilizer',
      'planting',
      'harvesting',
      'calendar_tasks',
      'appointments'
    ]) {
      await d.insert(
          'notification_preferences', {'category': category, 'enabled': 1});
    }
  }

  Future<Map<String, bool>> notificationPreferences() async {
    final rows = await db.query('notification_preferences');
    return {
      for (final row in rows) row['category'] as String: row['enabled'] == 1
    };
  }

  Future<void> setNotificationPreference(String category, bool enabled) async =>
      db.insert('notification_preferences',
          {'category': category, 'enabled': enabled ? 1 : 0},
          conflictAlgorithm: ConflictAlgorithm.replace);
  Future<int> addNotification(
          {required int notificationId,
          required String category,
          required String title,
          required String body,
          required DateTime scheduledFor,
          int? farmId,
          int? taskId}) =>
      db.insert('notification_history', {
        'notification_id': notificationId,
        'category': category,
        'title': title,
        'body': body,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'related_farm_id': farmId,
        'related_task_id': taskId,
        'is_scheduled': 0
      });
  Future<void> markReminderScheduled(int historyId) async {
    await db.update('notification_history', {'is_scheduled': 1},
        where: 'id=?', whereArgs: [historyId]);
  }

  Future<List<Map<String, Object?>>> notificationHistory() =>
      db.query('notification_history', orderBy: 'created_at DESC');
  Future<void> markNotificationRead(int id) async {
    await db.update('notification_history', {'is_read': 1},
        where: 'id=?', whereArgs: [id]);
  }

  Future<void> markAllNotificationsRead() async {
    await db.update('notification_history', {'is_read': 1});
  }

  Future<void> clearNotificationHistory() async {
    await db.delete('notification_history');
  }

  Future<void> markReminderCancelled(int notificationId) async {
    await db.update('notification_history', {'is_scheduled': 0},
        where: 'notification_id=?', whereArgs: [notificationId]);
  }

  Future<List<CalendarEvent>> calendarTasks(int farmId) async {
    final rows = await db.query('farming_tasks',
        where: 'farm_id=?', whereArgs: [farmId], orderBy: 'due_at');
    return rows
        .map((r) => CalendarEvent(r['type'] as String, r['title'] as String,
            DateTime.parse(r['due_at'] as String),
            id: r['id'] as int,
            farmId: r['farm_id'] as int,
            fieldId: r['field_id'] as int?,
            completed: r['completed'] == 1))
        .toList();
  }

  Future<int> saveCalendarTask(int farmId, CalendarEvent task) async {
    final values = {
      'farm_id': farmId,
      'type': task.type,
      'title': task.title,
      'due_at': task.date.toUtc().toIso8601String(),
      'completed': task.completed ? 1 : 0,
      'field_id': task.fieldId,
    };
    if (task.id == null) {
      return db.insert('farming_tasks', values);
    } else {
      await db
          .update('farming_tasks', values, where: 'id=?', whereArgs: [task.id]);
      return task.id!;
    }
  }

  Future<void> completeCalendarTask(int id, bool completed) async {
    await db.update('farming_tasks', {'completed': completed ? 1 : 0},
        where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteCalendarTask(int id) async {
    await db.delete('farming_tasks', where: 'id=?', whereArgs: [id]);
  }

  Future<Map<String, Object?>> terraceProgress() async =>
      (await db.query('terrace_progress', where: 'id=1')).first;
  Future<void> saveTerraceProgress(
          {required String space,
          required String sunlight,
          required String experience,
          required String budget,
          required List<String> checklist}) async =>
      db.update(
          'terrace_progress',
          {
            'space': space,
            'sunlight': sunlight,
            'experience': experience,
            'budget': budget,
            'checklist': jsonEncode(checklist)
          },
          where: 'id=1');
  Future<List<String>> savedCrops() async =>
      (await db.query('saved_crops', orderBy: 'crop'))
          .map((r) => r['crop'] as String)
          .toList();
  Future<void> setCropSaved(String crop, bool saved) async {
    if (saved) {
      await db.insert('saved_crops', {'crop': crop},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('saved_crops', where: 'crop=?', whereArgs: [crop]);
    }
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
        await txn.delete('farming_tasks');
        await txn.delete('saved_crops');
        await txn.delete('notification_history');
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
