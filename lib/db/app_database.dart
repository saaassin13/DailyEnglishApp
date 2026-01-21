import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite 数据库入口（单例）
///
/// 说明：
/// - 已替代 SharedPreferences，所有数据存储均使用 SQLite
/// - 使用版本号为后续升级/迁移预留空间
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const String dbName = 'daily_english.db';
  static const int dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, dbName);

    return openDatabase(
      dbPath,
      version: dbVersion,
      onConfigure: (db) async {
        // 预留：开启外键（后续若加 FK）
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createV1(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 预留：后续版本升级
      },
    );
  }

  Future<void> _createV1(Database db) async {
    // Settings（存储应用设置，如每日学习量、用户名等）
    await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT
)
''');

    // 每日学习会话（按天）
    await db.execute('''
CREATE TABLE IF NOT EXISTS daily_sessions (
  date TEXT PRIMARY KEY,              -- YYYY-MM-DD
  start_time TEXT,                    -- ISO8601
  end_time TEXT,                      -- ISO8601
  accumulated_seconds INTEGER NOT NULL DEFAULT 0
)
''');

    // 学习记录（逐条记录；对应 StudyRecord）
    await db.execute('''
CREATE TABLE IF NOT EXISTS study_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_date TEXT NOT NULL,         -- YYYY-MM-DD
  word TEXT NOT NULL,
  wordbook_id TEXT NOT NULL,
  status TEXT NOT NULL,               -- remembered / forgotten / unknown
  study_time TEXT NOT NULL,           -- ISO8601
  study_count INTEGER NOT NULL,
  next_review_date TEXT,              -- ISO8601
  review_count INTEGER NOT NULL DEFAULT 0,
  interval_days INTEGER NOT NULL DEFAULT 1
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_records_word ON study_records(wordbook_id, word, study_time)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_records_session ON study_records(session_date)',
    );

    // 每日完成状态（按词库）
    await db.execute('''
CREATE TABLE IF NOT EXISTS daily_completion (
  date TEXT NOT NULL,                 -- YYYY-MM-DD
  wordbook_id TEXT NOT NULL,
  status TEXT NOT NULL,               -- unlearned / completed
  PRIMARY KEY (date, wordbook_id)
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_completion_month ON daily_completion(date)',
    );

    // 全局每日完成状态
    await db.execute('''
CREATE TABLE IF NOT EXISTS global_daily_completion (
  date TEXT PRIMARY KEY,              -- YYYY-MM-DD
  status TEXT NOT NULL                -- unlearned / completed
)
''');

    // 签到记录
    await db.execute('''
CREATE TABLE IF NOT EXISTS checkins (
  date TEXT PRIMARY KEY,              -- YYYY-MM-DD
  check_in_time TEXT NOT NULL         -- ISO8601
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_checkins_month ON checkins(date)',
    );
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) {
      await db.close();
    }
  }
}


