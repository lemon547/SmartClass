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
      version: 19,
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
        await _createV3(db);
        await _createV4(db);
        await _createV5(db);
        await _createV6(db);
        await _createV7(db);
        await _createV8(db);
        await _createV9(db);
        await _createV10(db);
        await _createV11(db);
        await _createV12(db);
        await _createV13(db);
        await _createV14(db);
        await _createV15(db);
        await _createV16(db);
        await _createV17(db);
        await _createV18(db);
        await _createV19(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
        if (oldVersion < 3) await _createV3(db);
        if (oldVersion < 4) await _createV4(db);
        if (oldVersion < 5) await _createV5(db);
        if (oldVersion < 6) await _createV6(db);
        if (oldVersion < 7) await _createV7(db);
        if (oldVersion < 8) await _createV8(db);
        if (oldVersion < 9) await _createV9(db);
        if (oldVersion < 10) await _createV10(db);
        if (oldVersion < 11) await _createV11(db);
        if (oldVersion < 12) await _createV12(db);
        if (oldVersion < 13) await _createV13(db);
        if (oldVersion < 14) await _createV14(db);
        if (oldVersion < 15) await _createV15(db);
        if (oldVersion < 16) await _createV16(db);
        if (oldVersion < 17) await _createV17(db);
        if (oldVersion < 18) await _createV18(db);
        if (oldVersion < 19) await _createV19(db);
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

  Future<void> _createV5(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_logs (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT,
        date TEXT NOT NULL,
        student_ids TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createV6(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exams (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        exam_date TEXT NOT NULL,
        subjects TEXT NOT NULL,
        full_score REAL NOT NULL DEFAULT 100,
        pass_score REAL NOT NULL DEFAULT 60,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_scores (
        id TEXT PRIMARY KEY,
        exam_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        scores TEXT NOT NULL,
        remark TEXT,
        UNIQUE(exam_id, student_id)
      )
    ''');
  }

  Future<void> _createV7(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE students ADD COLUMN address TEXT DEFAULT ""',
      );
    } catch (_) {}
  }

  Future<void> _createV8(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS semesters (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        school_year TEXT,
        term TEXT,
        start_date TEXT,
        end_date TEXT,
        status TEXT NOT NULL,
        snapshot TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        archived_at TEXT
      )
    ''');
  }

  /// 多班级 + 工资；业务表增加 class_id（数据回填在 Repository.init）
  Future<void> _createV9(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        grade TEXT,
        group_name TEXT,
        seat_rows INTEGER NOT NULL DEFAULT 6,
        seat_cols INTEGER NOT NULL DEFAULT 8,
        teacher_role TEXT NOT NULL DEFAULT 'homeroom',
        feature_flags TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS salary_records (
        id TEXT PRIMARY KEY,
        year_month TEXT NOT NULL,
        title TEXT,
        base_amount REAL NOT NULL DEFAULT 0,
        allowance REAL NOT NULL DEFAULT 0,
        deduction REAL NOT NULL DEFAULT 0,
        net_amount REAL NOT NULL DEFAULT 0,
        paid_at TEXT,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    const tables = [
      'students',
      'attendance',
      'point_records',
      'duty',
      'class_notes',
      'homework',
      'rewards',
      'settlements',
      'countdowns',
      'fund_records',
      'work_logs',
      'exams',
      'semesters',
    ];
    for (final t in tables) {
      try {
        await db.execute('ALTER TABLE $t ADD COLUMN class_id TEXT');
      } catch (_) {}
    }

    // timetable：UNIQUE 需含 class_id，重建表
    await db.execute('ALTER TABLE timetable RENAME TO timetable_old_v9');
    await db.execute('''
      CREATE TABLE timetable (
        id TEXT PRIMARY KEY,
        class_id TEXT,
        weekday INTEGER NOT NULL,
        period INTEGER NOT NULL,
        subject TEXT,
        UNIQUE(class_id, weekday, period)
      )
    ''');
    await db.execute('''
      INSERT INTO timetable (id, class_id, weekday, period, subject)
      SELECT id, '', weekday, period, subject FROM timetable_old_v9
    ''');
    await db.execute('DROP TABLE timetable_old_v9');
  }

  /// 授课进度 + 课件附件元数据
  Future<void> _createV10(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_units (
        id TEXT PRIMARY KEY,
        class_id TEXT,
        subject TEXT,
        title TEXT NOT NULL,
        chapter TEXT,
        progress_note TEXT,
        status TEXT NOT NULL,
        planned_date TEXT,
        taught_date TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_files (
        id TEXT PRIMARY KEY,
        class_id TEXT,
        unit_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        stored_name TEXT NOT NULL,
        mime_hint TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 考试相关资料 / 试卷附件
  Future<void> _createV11(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS exam_files (
        id TEXT PRIMARY KEY,
        class_id TEXT,
        exam_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        stored_name TEXT NOT NULL,
        mime_hint TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 班级任教科目（语文 / 数学…）
  Future<void> _createV12(Database db) async {
    try {
      await db.execute('ALTER TABLE classes ADD COLUMN subject TEXT');
    } catch (_) {}
  }

  /// 班级所属学校（档案按学校检索）
  Future<void> _createV13(Database db) async {
    try {
      await db.execute('ALTER TABLE classes ADD COLUMN school TEXT');
    } catch (_) {}
  }

  /// 课程表节次配置 + 本人授课科目
  Future<void> _createV14(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS timetable_periods (
        class_id TEXT NOT NULL,
        period INTEGER NOT NULL,
        label TEXT NOT NULL DEFAULT '',
        start_time TEXT NOT NULL DEFAULT '',
        end_time TEXT NOT NULL DEFAULT '',
        PRIMARY KEY (class_id, period)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teaching_subjects (
        class_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (class_id, subject)
      )
    ''');
  }

  /// 教师个人待办（不按班级隔离）
  Future<void> _createV15(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 日常：请假 / 违纪
  Future<void> _createV16(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS leave_records (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT '',
        pickup TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS discipline_records (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        action TEXT NOT NULL DEFAULT '',
        points_delta INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 工作留痕：照片 / 语音 / 视频附件
  Future<void> _createV17(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS work_log_attachments (
        id TEXT PRIMARY KEY,
        class_id TEXT,
        work_log_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        file_name TEXT NOT NULL,
        stored_name TEXT NOT NULL,
        mime_hint TEXT,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 成绩：折算/年级/官方单科排名（导入字段）
  Future<void> _createV18(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE exam_scores ADD COLUMN converted_rank INTEGER',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE exam_scores ADD COLUMN grade_rank INTEGER',
      );
    } catch (_) {}
    try {
      await db.execute(
        'ALTER TABLE exam_scores ADD COLUMN subject_ranks TEXT DEFAULT ""',
      );
    } catch (_) {}
  }

  /// 请假闭环扩列 + 学生荣誉 + 职称材料
  Future<void> _createV19(Database db) async {
    for (final sql in [
      "ALTER TABLE leave_records ADD COLUMN start_at TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE leave_records ADD COLUMN end_at TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE leave_records ADD COLUMN status TEXT NOT NULL DEFAULT 'active'",
      "ALTER TABLE leave_records ADD COLUMN returned_at TEXT",
      "ALTER TABLE leave_records ADD COLUMN proof_stored_name TEXT NOT NULL DEFAULT ''",
      "ALTER TABLE leave_records ADD COLUMN proof_original_name TEXT NOT NULL DEFAULT ''",
    ]) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
    // 回填旧请假起止时间
    final rows = await db.query('leave_records');
    for (final row in rows) {
      final startAt = (row['start_at'] as String?) ?? '';
      if (startAt.isNotEmpty) continue;
      final date = (row['date'] as String?) ?? '';
      if (date.isEmpty) continue;
      await db.update(
        'leave_records',
        {
          'start_at': '${date}T00:00:00.000',
          'end_at': '${date}T23:59:59.000',
          'status': (row['status'] as String?)?.isNotEmpty == true
              ? row['status']
              : 'active',
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_honors (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        title TEXT NOT NULL,
        date TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS title_materials (
        id TEXT PRIMARY KEY,
        year INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT '其他',
        title TEXT NOT NULL,
        stored_name TEXT NOT NULL,
        original_name TEXT NOT NULL,
        mime_hint TEXT NOT NULL DEFAULT '',
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }
}
