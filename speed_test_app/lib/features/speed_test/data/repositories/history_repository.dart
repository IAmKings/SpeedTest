import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/speed_result.dart';
import '../../../../core/constants/app_constants.dart';

/// Repository for managing speed test history in local database
class HistoryRepository {
  Database? _database;

  HistoryRepository();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableSpeedResults} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        download_speed REAL NOT NULL,
        upload_speed REAL NOT NULL,
        ping REAL NOT NULL,
        jitter REAL DEFAULT 0,
        server_info TEXT,
        network_type INTEGER DEFAULT 0,
        wifi_name TEXT,
        avg_signal_strength INTEGER
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for network info (version 2)
      await db.execute('''
        ALTER TABLE ${AppConstants.tableSpeedResults}
        ADD COLUMN network_type INTEGER DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE ${AppConstants.tableSpeedResults}
        ADD COLUMN wifi_name TEXT
      ''');
      await db.execute('''
        ALTER TABLE ${AppConstants.tableSpeedResults}
        ADD COLUMN avg_signal_strength INTEGER
      ''');
    }
    if (oldVersion < 3) {
      // Add jitter column (version 3)
      await db.execute('''
        ALTER TABLE ${AppConstants.tableSpeedResults}
        ADD COLUMN jitter REAL DEFAULT 0
      ''');
    }
  }

  /// Insert a new speed result
  Future<int> insertResult(SpeedResult result) async {
    final db = await database;
    return await db.insert(
      AppConstants.tableSpeedResults,
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all speed results ordered by timestamp descending
  Future<List<SpeedResult>> getAllResults() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableSpeedResults,
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => SpeedResult.fromMap(map)).toList();
  }

  /// Get the latest speed result
  Future<SpeedResult?> getLatestResult() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableSpeedResults,
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SpeedResult.fromMap(maps.first);
  }

  /// Delete a result by id
  Future<int> deleteResult(int id) async {
    final db = await database;
    return await db.delete(
      AppConstants.tableSpeedResults,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all history
  Future<int> clearAll() async {
    final db = await database;
    return await db.delete(AppConstants.tableSpeedResults);
  }

  /// Get average speeds from last N tests
  Future<Map<String, double>> getAverages({int count = 10}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        AVG(download_speed) as avg_download,
        AVG(upload_speed) as avg_upload,
        AVG(ping) as avg_ping
      FROM (
        SELECT * FROM ${AppConstants.tableSpeedResults}
        ORDER BY timestamp DESC
        LIMIT ?
      )
    ''', [count]);

    if (result.isEmpty) {
      return {'download': 0.0, 'upload': 0.0, 'ping': 0.0};
    }

    final row = result.first;
    return {
      'download': (row['avg_download'] as num?)?.toDouble() ?? 0.0,
      'upload': (row['avg_upload'] as num?)?.toDouble() ?? 0.0,
      'ping': (row['avg_ping'] as num?)?.toDouble() ?? 0.0,
    };
  }
}
