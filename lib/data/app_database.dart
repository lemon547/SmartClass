import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'smart_class.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
        await _createV3(db);
        await _createV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
        if (oldVersion < 3) await _createV3(db);
        if (oldVersion < 4) await _createV4(db);
      },
    );
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS students (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        student_no TEXT,
        gender TEXT,
        phone TEXT,
        note TEXT,
        points INTEGER NOT NULL DEFAULT 0,
        seat_row INTEGER,
        seat_col INTEGER,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        remark TEXT,
        UNIQUE(student_id, date)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS point_records (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        delta INTEGER NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS duty (
        id TEXT PRIMARY KEY,
        weekday INTEGER NOT NULL,
        student_id TEXT NOT NULL,
        task TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV2(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE students ADD COLUMN group_name TEXT DEFAULT ""',
      );
    } catch (_) {}
    await db.execute('''
      CREATE TABLE IF NOT EXISTS class_notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS homework (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        date TEXT NOT NULL,
        done_ids TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rewards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cost INTEGER NOT NULL,
        stock INTEGER NOT NULL DEFAULT 99
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timetable (
        id TEXT PRIMARY KEY,
        weekday INTEGER NOT NULL,
        period INTEGER NOT NULL,
        subject TEXT,
        UNIQUE(weekday, period)
      )
    ''');
  }

  Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settlements (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        snapshot TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV4(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE students ADD COLUMN role TEXT DEFAULT ""',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE students ADD COLUMN birthday TEXT DEFAULT ""',
      );
    } catch (_) {}
    await db.execute('''
      CREATE TABLE IF NOT EXISTS countdowns (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        target_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fund_records (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }
}
