import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:smart_class/data/app_database.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/lesson_archive_store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ClassRepository {
  final _uuid = const Uuid();
  late SharedPreferences _prefs;

  static const _legacyDefaultClassId = 'legacy-default-class';
  static const _currentClassPrefKey = 'current_class_id';

  static const _businessTables = [
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
    'timetable',
    'lesson_units',
    'lesson_files',
    'exam_files',
  ];

  String? _currentClassId;
  ManagedClass? _cachedCurrentClass;

  String get currentClassId {
    final id = _currentClassId;
    if (id == null || id.isEmpty) {
      throw StateError('No current class selected');
    }
    return id;
  }

  Map<String, Object?> _withClass(Map<String, Object?> m) => {
        ...m,
        'class_id': currentClassId,
      };

  String _scopedPrefKey(String base) => '${base}_$currentClassId';

  // ── Init & migration ──────────────────────────────────────────────────────

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await AppDatabase.instance.database;
    await ensureClassesMigrated();
    await ensureActiveSemester();
  }

  Future<void> ensureClassesMigrated() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'classes',
      orderBy: 'sort_order ASC, created_at ASC',
    );

    if (rows.isEmpty) {
      final id = _legacyDefaultClassId;
      final cls = ManagedClass(
        id: id,
        name: _prefs.getString('class_name') ?? '高一（1）班',
        grade: _prefs.getString('class_grade') ?? '高一',
        seatRows: _prefs.getInt('seat_rows') ?? 6,
        seatCols: _prefs.getInt('seat_cols') ?? 8,
        teacherRole: TeacherRole.homeroom,
        createdAt: DateTime.now(),
      );
      await db.insert(
        'classes',
        cls.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final t in _businessTables) {
        await db.rawUpdate(
          'UPDATE $t SET class_id = ? WHERE class_id IS NULL OR class_id = ?',
          [id, ''],
        );
      }
      await setCurrentClassId(id);
      await _migrateLegacyPrefsToCurrentClass();
    } else {
      final saved = _prefs.getString(_currentClassPrefKey);
      final valid = saved != null &&
          saved.isNotEmpty &&
          rows.any((r) => r['id'] == saved);
      if (valid) {
        _currentClassId = saved;
      } else {
        await setCurrentClassId(rows.first['id']! as String);
      }
    }
    await _refreshCurrentClassCache();
  }

  Future<void> _migrateLegacyPrefsToCurrentClass() async {
    final mappings = <String, String>{
      'point_presets_json': _scopedPrefKey('point_presets_json'),
      'point_reasons': _scopedPrefKey('point_reasons'),
      'class_roles': _scopedPrefKey('class_roles'),
      'exam_categories': _scopedPrefKey('exam_categories'),
      'roll_history': _scopedPrefKey('roll_history'),
    };
    for (final entry in mappings.entries) {
      if (_prefs.containsKey(entry.value)) continue;
      final legacy = entry.key == 'point_presets_json'
          ? _prefs.getString(entry.key)
          : _prefs.getStringList(entry.key);
      if (legacy == null) continue;
      if (legacy is String) {
        await _prefs.setString(entry.value, legacy);
      } else if (legacy is List<String>) {
        await _prefs.setStringList(entry.value, legacy);
      }
    }
  }

  Future<void> _refreshCurrentClassCache() async {
    if (_currentClassId == null || _currentClassId!.isEmpty) return;
    _cachedCurrentClass = await getClass(_currentClassId!);
    if (_cachedCurrentClass != null) {
      await _syncLegacyPrefsFromClass(_cachedCurrentClass!);
    }
  }

  Future<void> _syncLegacyPrefsFromClass(ManagedClass cls) async {
    await _prefs.setString('class_name', cls.name);
    await _prefs.setString('class_grade', cls.grade);
    await _prefs.setInt('seat_rows', cls.seatRows);
    await _prefs.setInt('seat_cols', cls.seatCols);
  }

  Future<void> _syncLegacyPrefsFromProfile(ClassProfile profile) async {
    await _prefs.setString('class_name', profile.name);
    await _prefs.setString('class_grade', profile.grade);
    await _prefs.setInt('seat_rows', profile.seatRows);
    await _prefs.setInt('seat_cols', profile.seatCols);
  }

  Future<void> setCurrentClassId(String id) async {
    _currentClassId = id;
    await _prefs.setString(_currentClassPrefKey, id);
    await _refreshCurrentClassCache();
  }

  // ── Class CRUD ────────────────────────────────────────────────────────────

  Future<List<ManagedClass>> getClasses() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'classes',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(ManagedClass.fromMap).toList();
  }

  Future<ManagedClass?> getClass(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'classes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ManagedClass.fromMap(rows.first);
  }

  Future<void> upsertClass(ManagedClass cls) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'classes',
      cls.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (cls.id == currentClassId) {
      _cachedCurrentClass = cls;
      await _syncLegacyPrefsFromClass(cls);
    }
  }

  Future<ManagedClass> createClass({
    required String name,
    String school = '',
    String grade = '',
    String groupName = '',
    int seatRows = 6,
    int seatCols = 8,
    TeacherRole teacherRole = TeacherRole.homeroom,
    String subject = '',
    Map<String, bool> featureFlags = const {},
  }) async {
    final list = await getClasses();
    final cls = ManagedClass(
      id: _uuid.v4(),
      name: name.trim(),
      school: school.trim(),
      grade: grade.trim(),
      groupName: groupName.trim(),
      seatRows: seatRows,
      seatCols: seatCols,
      teacherRole: teacherRole,
      subject: subject.trim(),
      featureFlags: featureFlags,
      sortOrder: list.length,
      createdAt: DateTime.now(),
    );
    await upsertClass(cls);
    return cls;
  }

  Future<void> deleteClass(String id) async {
    final classes = await getClasses();
    if (classes.length <= 1) {
      throw StateError('无法删除最后一个班级');
    }
    if (id == currentClassId) {
      final other = classes.firstWhere((c) => c.id != id);
      await setCurrentClassId(other.id);
    }
    final db = await AppDatabase.instance.database;
    await db.rawDelete(
      'DELETE FROM exam_scores WHERE exam_id IN (SELECT id FROM exams WHERE class_id = ?)',
      [id],
    );
    for (final t in _businessTables) {
      await db.delete(t, where: 'class_id = ?', whereArgs: [id]);
    }
    await db.delete('classes', where: 'id = ?', whereArgs: [id]);
    await LessonArchiveStore.deleteClassDir(id);
    await LocalFileArchive.deleteClassDir(
      root: LocalFileArchive.examRoot,
      classId: id,
    );
    await _prefs.remove('point_presets_json_$id');
    await _prefs.remove('point_reasons_$id');
    await _prefs.remove('class_roles_$id');
    await _prefs.remove('exam_categories_$id');
    await _prefs.remove('roll_history_$id');
  }

  // ── Profile (current class) ───────────────────────────────────────────────

  ClassProfile loadProfile() {
    if (_cachedCurrentClass != null) return _cachedCurrentClass!.asProfile;
    return ClassProfile(
      name: _prefs.getString('class_name') ?? '高一（1）班',
      grade: _prefs.getString('class_grade') ?? '高一',
      seatRows: _prefs.getInt('seat_rows') ?? 6,
      seatCols: _prefs.getInt('seat_cols') ?? 8,
    );
  }

  Future<void> saveProfile(ClassProfile profile) async {
    final existing = _cachedCurrentClass ?? await getClass(currentClassId);
    if (existing != null) {
      final updated = existing.copyWith(
        name: profile.name,
        grade: profile.grade,
        seatRows: profile.seatRows,
        seatCols: profile.seatCols,
      );
      await upsertClass(updated);
    }
    await _syncLegacyPrefsFromProfile(profile);
  }

  // ── Students ──────────────────────────────────────────────────────────────

  Future<List<Student>> getStudents() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'students',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'student_no ASC, name ASC',
    );
    return rows.map(Student.fromMap).toList();
  }

  Future<void> upsertStudent(Student student) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'students',
      _withClass(student.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteStudent(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'students',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
    await db.delete(
      'attendance',
      where: 'student_id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
    await db.delete(
      'point_records',
      where: 'student_id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
    await db.delete(
      'duty',
      where: 'student_id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Future<List<AttendanceRecord>> getAttendanceByDate(String date) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'attendance',
      where: 'date = ? AND class_id = ?',
      whereArgs: [date, currentClassId],
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<List<AttendanceRecord>> getAllAttendance() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'attendance',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'date DESC',
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<void> setAttendance({
    required String studentId,
    required String date,
    required AttendanceStatus status,
    String remark = '',
  }) async {
    final db = await AppDatabase.instance.database;
    final existing = await db.query(
      'attendance',
      where: 'student_id = ? AND date = ? AND class_id = ?',
      whereArgs: [studentId, date, currentClassId],
      limit: 1,
    );
    final id = existing.isEmpty ? _uuid.v4() : existing.first['id']! as String;
    await db.insert(
      'attendance',
      _withClass(
        AttendanceRecord(
          id: id,
          studentId: studentId,
          date: date,
          status: status,
          remark: remark,
        ).toMap(),
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<String>> getAttendanceDates({int limit = 60}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM attendance WHERE class_id = ? ORDER BY date DESC LIMIT ?',
      [currentClassId, limit],
    );
    return rows.map((e) => e['date']! as String).toList();
  }

  Future<Map<String, int>> attendanceSummary(String date) async {
    final rows = await getAttendanceByDate(date);
    final map = <String, int>{
      for (final s in AttendanceStatus.values) s.name: 0,
    };
    for (final r in rows) {
      map[r.status.name] = (map[r.status.name] ?? 0) + 1;
    }
    return map;
  }

  Future<List<AttendanceRecord>> getAttendanceByStudent(String studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'attendance',
      where: 'student_id = ? AND class_id = ?',
      whereArgs: [studentId, currentClassId],
      orderBy: 'date DESC',
      limit: 60,
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<Map<String, int>> weekAttendanceStats(List<String> dates) async {
    final result = <String, int>{
      for (final s in AttendanceStatus.values) s.name: 0,
    };
    for (final d in dates) {
      final rows = await getAttendanceByDate(d);
      for (final r in rows) {
        result[r.status.name] = (result[r.status.name] ?? 0) + 1;
      }
    }
    return result;
  }

  // ── Points ────────────────────────────────────────────────────────────────

  Future<List<PointRecord>> getPointRecords({int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(PointRecord.fromMap).toList();
  }

  Future<void> addPoints({
    required String studentId,
    required int delta,
    required String reason,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.insert(
        'point_records',
        _withClass(
          PointRecord(
            id: _uuid.v4(),
            studentId: studentId,
            delta: delta,
            reason: reason,
            createdAt: DateTime.now(),
          ).toMap(),
        ),
      );
      await txn.rawUpdate(
        'UPDATE students SET points = points + ? WHERE id = ? AND class_id = ?',
        [delta, studentId, currentClassId],
      );
    });
  }

  Future<List<PointRecord>> getPointRecordsByStudent(String studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      where: 'student_id = ? AND class_id = ?',
      whereArgs: [studentId, currentClassId],
      orderBy: 'created_at DESC',
      limit: 80,
    );
    return rows.map(PointRecord.fromMap).toList();
  }

  Future<PointRecord?> undoLastPoint() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final record = PointRecord.fromMap(rows.first);
    await db.transaction((txn) async {
      await txn.delete(
        'point_records',
        where: 'id = ? AND class_id = ?',
        whereArgs: [record.id, currentClassId],
      );
      await txn.rawUpdate(
        'UPDATE students SET points = points - ? WHERE id = ? AND class_id = ?',
        [record.delta, record.studentId, currentClassId],
      );
    });
    return record;
  }

  Future<Map<String, int>> pointsDeltaSince(DateTime since) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      where: 'created_at >= ? AND class_id = ?',
      whereArgs: [since.toIso8601String(), currentClassId],
    );
    final map = <String, int>{};
    for (final row in rows) {
      final id = row['student_id']! as String;
      final delta = row['delta']! as int;
      map[id] = (map[id] ?? 0) + delta;
    }
    return map;
  }

  Future<void> resetAllPoints() async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'students',
        {'points': 0},
        where: 'class_id = ?',
        whereArgs: [currentClassId],
      );
      await txn.delete(
        'point_records',
        where: 'class_id = ?',
        whereArgs: [currentClassId],
      );
    });
  }

  List<String> loadPointReasons() =>
      loadPointPresets().map((e) => e.reason).toList();

  List<PointReasonPreset> loadPointPresets() {
    final scopedKey = _scopedPrefKey('point_presets_json');
    var raw = _prefs.getString(scopedKey);
    raw ??= _prefs.getString('point_presets_json');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) =>
                PointReasonPreset.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((e) => e.reason.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    final legacyKey = _scopedPrefKey('point_reasons');
    var legacy = _prefs.getStringList(legacyKey);
    legacy ??= _prefs.getStringList('point_reasons');
    if (legacy != null && legacy.isNotEmpty) {
      return [
        for (final r in legacy)
          PointReasonPreset(
            reason: r,
            delta: const {
                  '迟到',
                  '未交作业',
                  '课堂违纪',
                }.contains(r)
                ? -1
                : 2,
          ),
      ];
    }
    return const [
      PointReasonPreset(reason: '课堂发言', delta: 2),
      PointReasonPreset(reason: '作业优秀', delta: 3),
      PointReasonPreset(reason: '帮助同学', delta: 2),
      PointReasonPreset(reason: '迟到', delta: -1),
      PointReasonPreset(reason: '未交作业', delta: -2),
      PointReasonPreset(reason: '课堂违纪', delta: -2),
    ];
  }

  Future<void> savePointReasons(List<String> reasons) async {
    await savePointPresets([
      for (final r in reasons) PointReasonPreset(reason: r, delta: 1),
    ]);
  }

  Future<void> savePointPresets(List<PointReasonPreset> presets) async {
    await _prefs.setString(
      _scopedPrefKey('point_presets_json'),
      jsonEncode(presets.map((e) => e.toJson()).toList()),
    );
    await _prefs.setStringList(
      _scopedPrefKey('point_reasons'),
      presets.map((e) => e.reason).toList(),
    );
  }

  Future<void> clearPointPresets() async {
    await _prefs.remove(_scopedPrefKey('point_presets_json'));
    await _prefs.remove(_scopedPrefKey('point_reasons'));
  }

  // ── Role presets ──────────────────────────────────────────────────────────

  static const defaultRolePresets = [
    '班长',
    '副班长',
    '学习委员',
    '纪律委员',
    '体育委员',
    '文艺委员',
    '生活委员',
    '组长',
  ];

  List<String> loadRolePresets() {
    final scopedKey = _scopedPrefKey('class_roles');
    var list = _prefs.getStringList(scopedKey);
    list ??= _prefs.getStringList('class_roles');
    if (list == null || list.isEmpty) {
      return List<String>.from(defaultRolePresets);
    }
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> saveRolePresets(List<String> roles) async {
    final cleaned = <String>[];
    final seen = <String>{};
    for (final r in roles) {
      final t = r.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      cleaned.add(t);
    }
    await _prefs.setStringList(_scopedPrefKey('class_roles'), cleaned);
  }

  // ── Exam categories ───────────────────────────────────────────────────────

  static const defaultExamCategories = [
    '期末考',
    '半期考',
    '月考',
    '周考',
    '单元测验',
  ];

  static const defaultExamSubjects = [
    '语文',
    '数学',
    '英语',
    '物理',
    '化学',
    '生物',
    '政治',
    '历史',
    '地理',
  ];

  List<String> loadExamCategories() {
    final scopedKey = _scopedPrefKey('exam_categories');
    var list = _prefs.getStringList(scopedKey);
    list ??= _prefs.getStringList('exam_categories');
    if (list == null || list.isEmpty) {
      return List<String>.from(defaultExamCategories);
    }
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  Future<void> saveExamCategories(List<String> categories) async {
    final cleaned = <String>[];
    final seen = <String>{};
    for (final c in categories) {
      final t = c.trim();
      if (t.isEmpty || seen.contains(t)) continue;
      seen.add(t);
      cleaned.add(t);
    }
    await _prefs.setStringList(_scopedPrefKey('exam_categories'), cleaned);
  }

  // ── Duty ──────────────────────────────────────────────────────────────────

  Future<List<DutyAssignment>> getDuty() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'duty',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'weekday ASC',
    );
    return rows.map(DutyAssignment.fromMap).toList();
  }

  Future<void> setDuty({
    required int weekday,
    required String studentId,
    String task = '值日',
  }) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'duty',
      where: 'weekday = ? AND student_id = ? AND class_id = ?',
      whereArgs: [weekday, studentId, currentClassId],
    );
    await db.insert(
      'duty',
      _withClass(
        DutyAssignment(
          id: _uuid.v4(),
          weekday: weekday,
          studentId: studentId,
          task: task,
        ).toMap(),
      ),
    );
  }

  Future<void> removeDuty(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'duty',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  Future<void> rotateDutyForward() async {
    final list = await getDuty();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete(
        'duty',
        where: 'class_id = ?',
        whereArgs: [currentClassId],
      );
      for (final d in list) {
        final next = d.weekday == 7 ? 1 : d.weekday + 1;
        await txn.insert(
          'duty',
          _withClass(
            DutyAssignment(
              id: _uuid.v4(),
              weekday: next,
              studentId: d.studentId,
              task: d.task,
            ).toMap(),
          ),
        );
      }
    });
  }

  // ── Seats ─────────────────────────────────────────────────────────────────

  Future<void> updateSeat({
    required String studentId,
    int? row,
    int? col,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'students',
      {'seat_row': row, 'seat_col': col},
      where: 'id = ? AND class_id = ?',
      whereArgs: [studentId, currentClassId],
    );
  }

  Future<void> autoArrangeSeats({
    required int rows,
    required int cols,
  }) async {
    final students = await getStudents();
    var i = 0;
    for (final s in students) {
      if (i >= rows * cols) {
        await updateSeat(studentId: s.id, row: null, col: null);
      } else {
        await updateSeat(studentId: s.id, row: i ~/ cols, col: i % cols);
      }
      i++;
    }
  }

  // ── Roll history ──────────────────────────────────────────────────────────

  List<Map<String, dynamic>> loadRollHistory() {
    final scopedKey = _scopedPrefKey('roll_history');
    var raw = _prefs.getStringList(scopedKey);
    raw ??= _prefs.getStringList('roll_history');
    return (raw ?? []).map((e) {
      final parts = e.split('|');
      if (parts.length < 3) return <String, dynamic>{};
      return {
        'id': parts[0],
        'name': parts[1],
        'at': parts[2],
      };
    }).where((e) => e.isNotEmpty).toList();
  }

  Future<void> addRollHistory({
    required String studentId,
    required String name,
  }) async {
    final key = _scopedPrefKey('roll_history');
    final list = _prefs.getStringList(key) ?? [];
    list.insert(0, '$studentId|$name|${DateTime.now().toIso8601String()}');
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    await _prefs.setStringList(key, list);
  }

  Future<void> clearRollHistory() async {
    await _prefs.remove(_scopedPrefKey('roll_history'));
  }

  // ── Settlements ───────────────────────────────────────────────────────────

  Future<List<Settlement>> getSettlements() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'settlements',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Settlement.fromMap).toList();
  }

  Future<Settlement> settleAndRestart({required String name}) async {
    final students = await getStudents();
    final ranked = [...students]..sort((a, b) => b.points.compareTo(a.points));
    final snapshot = jsonEncode([
      for (final s in ranked)
        {
          'id': s.id,
          'name': s.name,
          'points': s.points,
          'rank': rankTitle(s.points),
        },
    ]);
    final settlement = Settlement(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      snapshot: snapshot,
    );
    final db = await AppDatabase.instance.database;
    await db.insert('settlements', _withClass(settlement.toMap()));
    await resetAllPoints();
    return settlement;
  }

  Future<void> deleteSettlement(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'settlements',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  Future<List<ClassNote>> getNotes() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'class_notes',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ClassNote.fromMap).toList();
  }

  Future<void> upsertNote(ClassNote note) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'class_notes',
      _withClass(note.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'class_notes',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Homework ──────────────────────────────────────────────────────────────

  Future<List<HomeworkItem>> getHomework({String? date}) async {
    final db = await AppDatabase.instance.database;
    final rows = date == null
        ? await db.query(
            'homework',
            where: 'class_id = ?',
            whereArgs: [currentClassId],
            orderBy: 'date DESC',
          )
        : await db.query(
            'homework',
            where: 'date = ? AND class_id = ?',
            whereArgs: [date, currentClassId],
            orderBy: 'title ASC',
          );
    return rows.map(HomeworkItem.fromMap).toList();
  }

  Future<void> upsertHomework(HomeworkItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'homework',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHomework(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'homework',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Rewards ───────────────────────────────────────────────────────────────

  Future<List<RewardItem>> getRewards() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'rewards',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'cost ASC',
    );
    return rows.map(RewardItem.fromMap).toList();
  }

  Future<void> upsertReward(RewardItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'rewards',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReward(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'rewards',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  Future<bool> redeemReward({
    required String studentId,
    required RewardItem reward,
  }) async {
    if (reward.stock <= 0) return false;
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'students',
      where: 'id = ? AND class_id = ?',
      whereArgs: [studentId, currentClassId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final points = rows.first['points']! as int;
    if (points < reward.cost) return false;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE students SET points = points - ? WHERE id = ? AND class_id = ?',
        [reward.cost, studentId, currentClassId],
      );
      await txn.insert(
        'point_records',
        _withClass(
          PointRecord(
            id: _uuid.v4(),
            studentId: studentId,
            delta: -reward.cost,
            reason: '兑换：${reward.name}',
            createdAt: DateTime.now(),
          ).toMap(),
        ),
      );
      await txn.update(
        'rewards',
        {'stock': reward.stock - 1},
        where: 'id = ? AND class_id = ?',
        whereArgs: [reward.id, currentClassId],
      );
    });
    return true;
  }

  // ── Timetable ─────────────────────────────────────────────────────────────

  Future<List<TimetableSlot>> getTimetable() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'timetable',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'weekday ASC, period ASC',
    );
    return rows.map(TimetableSlot.fromMap).toList();
  }

  Future<void> upsertTimetableSlot(TimetableSlot slot) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'timetable',
      where: 'weekday = ? AND period = ? AND class_id = ?',
      whereArgs: [slot.weekday, slot.period, currentClassId],
    );
    await db.insert('timetable', _withClass(slot.toMap()));
  }

  Future<void> clearTimetableSlot(int weekday, int period) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'timetable',
      where: 'weekday = ? AND period = ? AND class_id = ?',
      whereArgs: [weekday, period, currentClassId],
    );
  }

  // ── Countdowns ────────────────────────────────────────────────────────────

  Future<List<CountdownItem>> getCountdowns() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'countdowns',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'target_date ASC',
    );
    return rows.map(CountdownItem.fromMap).toList();
  }

  Future<void> upsertCountdown(CountdownItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'countdowns',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCountdown(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'countdowns',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Fund records ──────────────────────────────────────────────────────────

  Future<List<FundRecord>> getFundRecords() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'fund_records',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(FundRecord.fromMap).toList();
  }

  Future<void> upsertFundRecord(FundRecord item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'fund_records',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFundRecord(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'fund_records',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Work logs ─────────────────────────────────────────────────────────────

  Future<List<WorkLog>> getWorkLogs() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'work_logs',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'date DESC, updated_at DESC',
    );
    return rows.map(WorkLog.fromMap).toList();
  }

  Future<void> upsertWorkLog(WorkLog item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'work_logs',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteWorkLog(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'work_logs',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  // ── Exams ─────────────────────────────────────────────────────────────────

  Future<List<Exam>> getExams() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'exams',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'exam_date DESC, updated_at DESC',
    );
    return rows.map(Exam.fromMap).toList();
  }

  Future<void> upsertExam(Exam item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'exams',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExam(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('exam_scores', where: 'exam_id = ?', whereArgs: [id]);
    await db.delete(
      'exam_files',
      where: 'exam_id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
    await db.delete(
      'exams',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
    await LocalFileArchive.deleteOwnerDir(
      root: LocalFileArchive.examRoot,
      classId: currentClassId,
      ownerId: id,
    );
  }

  Future<List<ExamFile>> getExamFiles({String? examId}) async {
    final db = await AppDatabase.instance.database;
    final rows = examId == null
        ? await db.query(
            'exam_files',
            where: 'class_id = ?',
            whereArgs: [currentClassId],
            orderBy: 'created_at DESC',
          )
        : await db.query(
            'exam_files',
            where: 'class_id = ? AND exam_id = ?',
            whereArgs: [currentClassId, examId],
            orderBy: 'created_at DESC',
          );
    return rows.map(ExamFile.fromMap).toList();
  }

  Future<void> upsertExamFile(ExamFile item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'exam_files',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExamFile(ExamFile item) async {
    final db = await AppDatabase.instance.database;
    await db.delete('exam_files', where: 'id = ?', whereArgs: [item.id]);
    await LocalFileArchive.deleteFile(
      root: LocalFileArchive.examRoot,
      classId: currentClassId,
      ownerId: item.examId,
      storedName: item.storedName,
    );
  }

  Future<ExamFile> importExamFile({
    required String examId,
    required String sourcePath,
    required String originalName,
    String note = '',
  }) async {
    final imported = await LocalFileArchive.importFile(
      root: LocalFileArchive.examRoot,
      classId: currentClassId,
      ownerId: examId,
      sourcePath: sourcePath,
      originalName: originalName,
    );
    final file = ExamFile(
      id: _uuid.v4(),
      examId: examId,
      fileName: originalName,
      storedName: imported.storedName,
      sizeBytes: imported.sizeBytes,
      note: note,
      createdAt: DateTime.now(),
    );
    await upsertExamFile(file);
    return file;
  }

  Future<String> examFileAbsolutePath(ExamFile item) =>
      LocalFileArchive.absolutePath(
        root: LocalFileArchive.examRoot,
        classId: currentClassId,
        ownerId: item.examId,
        storedName: item.storedName,
      );

  Future<List<ExamScore>> getExamScores(String examId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'exam_scores',
      where: 'exam_id = ?',
      whereArgs: [examId],
    );
    return rows.map(ExamScore.fromMap).toList();
  }

  Future<void> upsertExamScore(ExamScore item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'exam_scores',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteExamScore(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('exam_scores', where: 'id = ?', whereArgs: [id]);
  }

  // ── Semesters (per class) ─────────────────────────────────────────────────

  Future<List<Semester>> getSemesters() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'semesters',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy:
          "CASE status WHEN 'active' THEN 0 ELSE 1 END, archived_at DESC, created_at DESC",
    );
    return rows.map(Semester.fromMap).toList();
  }

  Future<Semester?> getSemester(String id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'semesters',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Semester.fromMap(rows.first);
  }

  Future<void> upsertSemester(Semester item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'semesters',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSemester(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'semesters',
      where: 'id = ? AND class_id = ?',
      whereArgs: [id, currentClassId],
    );
  }

  Future<Semester> ensureActiveSemester() async {
    final list = await getSemesters();
    for (final s in list) {
      if (s.isActive) return s;
    }
    final label = Semester.defaultLabel();
    final now = DateTime.now();
    final semester = Semester(
      id: _uuid.v4(),
      title: label.title,
      schoolYear: label.schoolYear,
      term: label.term,
      startDate: DateFormat('yyyy-MM-dd').format(now),
      status: SemesterStatus.active,
      createdAt: now,
    );
    await upsertSemester(semester);
    return semester;
  }

  Future<Map<String, dynamic>> _buildSemesterSnapshot() async {
    final students = await getStudents();
    final db = await AppDatabase.instance.database;
    final cid = currentClassId;
    final ranked = [...students]..sort((a, b) => b.points.compareTo(a.points));
    final avg = students.isEmpty
        ? 0.0
        : students.map((e) => e.points).reduce((a, b) => a + b) /
            students.length;
    return {
      'archivedAt': DateTime.now().toIso8601String(),
      'stats': {
        'studentCount': students.length,
        'avgPoints': avg,
        'topPoints': ranked.isEmpty ? 0 : ranked.first.points,
        'attendanceCount': (await db.query(
          'attendance',
          where: 'class_id = ?',
          whereArgs: [cid],
        ))
            .length,
        'examCount': (await db.query(
          'exams',
          where: 'class_id = ?',
          whereArgs: [cid],
        ))
            .length,
        'workLogCount': (await db.query(
          'work_logs',
          where: 'class_id = ?',
          whereArgs: [cid],
        ))
            .length,
        'pointRecordCount': (await db.query(
          'point_records',
          where: 'class_id = ?',
          whereArgs: [cid],
        ))
            .length,
      },
      'ranking': [
        for (var i = 0; i < ranked.length; i++)
          {
            'rank': i + 1,
            'id': ranked[i].id,
            'name': ranked[i].name,
            'studentNo': ranked[i].studentNo,
            'groupName': ranked[i].groupName,
            'role': ranked[i].role,
            'points': ranked[i].points,
          },
      ],
      'students': students.map((e) => e.toMap()).toList(),
      'attendance': await db.query(
        'attendance',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'point_records': await db.query(
        'point_records',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'class_notes': await db.query(
        'class_notes',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'homework': await db.query(
        'homework',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'settlements': await db.query(
        'settlements',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'countdowns': await db.query(
        'countdowns',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'fund_records': await db.query(
        'fund_records',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'work_logs': await db.query(
        'work_logs',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'exams': await db.query(
        'exams',
        where: 'class_id = ?',
        whereArgs: [cid],
      ),
      'exam_scores': await db.rawQuery(
        'SELECT es.* FROM exam_scores es INNER JOIN exams e ON es.exam_id = e.id WHERE e.class_id = ?',
        [cid],
      ),
      'roll_history': _prefs.getStringList(_scopedPrefKey('roll_history')) ?? [],
    };
  }

  Future<void> _resetForNewSemester() async {
    final db = await AppDatabase.instance.database;
    final cid = currentClassId;
    await db.transaction((txn) async {
      for (final t in [
        'attendance',
        'point_records',
        'class_notes',
        'homework',
        'settlements',
        'countdowns',
        'fund_records',
        'work_logs',
      ]) {
        await txn.delete(t, where: 'class_id = ?', whereArgs: [cid]);
      }
      await txn.rawDelete(
        'DELETE FROM exam_scores WHERE exam_id IN (SELECT id FROM exams WHERE class_id = ?)',
        [cid],
      );
      await txn.delete('exams', where: 'class_id = ?', whereArgs: [cid]);
      await txn.update(
        'students',
        {'points': 0},
        where: 'class_id = ?',
        whereArgs: [cid],
      );
    });
    await clearRollHistory();
  }

  Future<Semester> archiveAndStartNew({
    String archiveTitle = '',
    String newTitle = '',
    String endDate = '',
    String note = '',
  }) async {
    final active = await ensureActiveSemester();
    final snapshot = await _buildSemesterSnapshot();
    final now = DateTime.now();
    final end = endDate.trim().isEmpty
        ? DateFormat('yyyy-MM-dd').format(now)
        : endDate.trim();

    final archived = active.copyWith(
      title: archiveTitle.trim().isEmpty ? active.title : archiveTitle.trim(),
      endDate: end,
      status: SemesterStatus.archived,
      snapshot: jsonEncode(snapshot),
      note: note.trim(),
      archivedAt: now,
    );
    await upsertSemester(archived);
    await _resetForNewSemester();

    final label = Semester.defaultLabel(now);
    final next = Semester(
      id: _uuid.v4(),
      title: newTitle.trim().isEmpty ? label.title : newTitle.trim(),
      schoolYear: label.schoolYear,
      term: label.term,
      startDate: DateFormat('yyyy-MM-dd').format(now),
      status: SemesterStatus.active,
      createdAt: now,
    );
    await upsertSemester(next);
    return next;
  }

  Future<void> renameSemester(String id, String title) async {
    final s = await getSemester(id);
    if (s == null) return;
    await upsertSemester(s.copyWith(title: title.trim()));
  }

  // ── Lesson progress & files ───────────────────────────────────────────────

  Future<List<LessonUnit>> getLessonUnits() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'lesson_units',
      where: 'class_id = ?',
      whereArgs: [currentClassId],
      orderBy: 'sort_order ASC, planned_date ASC, updated_at DESC',
    );
    return rows.map(LessonUnit.fromMap).toList();
  }

  Future<void> upsertLessonUnit(LessonUnit item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'lesson_units',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLessonUnit(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('lesson_files', where: 'unit_id = ?', whereArgs: [id]);
    await db.delete('lesson_units', where: 'id = ?', whereArgs: [id]);
    await LessonArchiveStore.deleteUnitDir(
      classId: currentClassId,
      unitId: id,
    );
  }

  Future<List<LessonFile>> getLessonFiles({String? unitId}) async {
    final db = await AppDatabase.instance.database;
    final rows = unitId == null
        ? await db.query(
            'lesson_files',
            where: 'class_id = ?',
            whereArgs: [currentClassId],
            orderBy: 'created_at DESC',
          )
        : await db.query(
            'lesson_files',
            where: 'class_id = ? AND unit_id = ?',
            whereArgs: [currentClassId, unitId],
            orderBy: 'created_at DESC',
          );
    return rows.map(LessonFile.fromMap).toList();
  }

  Future<void> upsertLessonFile(LessonFile item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'lesson_files',
      _withClass(item.toMap()),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteLessonFile(LessonFile item) async {
    final db = await AppDatabase.instance.database;
    await db.delete('lesson_files', where: 'id = ?', whereArgs: [item.id]);
    await LessonArchiveStore.deleteFile(
      classId: currentClassId,
      unitId: item.unitId,
      storedName: item.storedName,
    );
  }

  Future<LessonFile> importLessonFile({
    required String unitId,
    required String sourcePath,
    required String originalName,
    String mimeHint = '',
  }) async {
    final imported = await LessonArchiveStore.importFile(
      classId: currentClassId,
      unitId: unitId,
      sourcePath: sourcePath,
      originalName: originalName,
    );
    final file = LessonFile(
      id: _uuid.v4(),
      unitId: unitId,
      fileName: originalName,
      storedName: imported.storedName,
      mimeHint: mimeHint,
      sizeBytes: imported.sizeBytes,
      createdAt: DateTime.now(),
    );
    await upsertLessonFile(file);
    return file;
  }

  Future<String> lessonFileAbsolutePath(LessonFile item) =>
      LessonArchiveStore.absolutePath(
        classId: currentClassId,
        unitId: item.unitId,
        storedName: item.storedName,
      );

  // ── Salary (global, no class_id) ──────────────────────────────────────────

  Future<List<SalaryRecord>> getSalaryRecords() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'salary_records',
      orderBy: 'year_month DESC, created_at DESC',
    );
    return rows.map(SalaryRecord.fromMap).toList();
  }

  Future<void> upsertSalaryRecord(SalaryRecord item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'salary_records',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSalaryRecord(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('salary_records', where: 'id = ?', whereArgs: [id]);
  }

  // ── Backup / restore ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _exportClassPrefs(String classId) async {
    return {
      'point_presets': _readPointPresetsForClass(classId)
          .map((e) => e.toJson())
          .toList(),
      'point_reasons': _readPointReasonsForClass(classId),
      'class_roles': _readRolePresetsForClass(classId),
      'exam_categories': _readExamCategoriesForClass(classId),
      'roll_history': _prefs.getStringList('roll_history_$classId') ?? [],
    };
  }

  List<PointReasonPreset> _readPointPresetsForClass(String classId) {
    final raw = _prefs.getString('point_presets_json_$classId') ??
        _prefs.getString('point_presets_json');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) =>
                PointReasonPreset.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((e) => e.reason.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    return const [];
  }

  List<String> _readPointReasonsForClass(String classId) {
    return _prefs.getStringList('point_reasons_$classId') ??
        _prefs.getStringList('point_reasons') ??
        [];
  }

  List<String> _readRolePresetsForClass(String classId) {
    return _prefs.getStringList('class_roles_$classId') ??
        _prefs.getStringList('class_roles') ??
        [];
  }

  List<String> _readExamCategoriesForClass(String classId) {
    return _prefs.getStringList('exam_categories_$classId') ??
        _prefs.getStringList('exam_categories') ??
        [];
  }

  Future<void> _importClassPrefs(String classId, Map<String, dynamic> prefs) async {
    final presetsRaw = prefs['point_presets'] as List?;
    if (presetsRaw != null && presetsRaw.isNotEmpty) {
      await _prefs.setString(
        'point_presets_json_$classId',
        jsonEncode(presetsRaw),
      );
    }
    final reasons = (prefs['point_reasons'] as List?)?.cast<String>();
    if (reasons != null) {
      await _prefs.setStringList('point_reasons_$classId', reasons);
    }
    final roles = (prefs['class_roles'] as List?)?.cast<String>();
    if (roles != null) {
      await _prefs.setStringList('class_roles_$classId', roles);
    }
    final examCats = (prefs['exam_categories'] as List?)?.cast<String>();
    if (examCats != null) {
      await _prefs.setStringList('exam_categories_$classId', examCats);
    }
    final roll = (prefs['roll_history'] as List?)?.cast<String>();
    if (roll != null) {
      await _prefs.setStringList('roll_history_$classId', roll);
    }
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final db = await AppDatabase.instance.database;
    final classes = await db.query('classes', orderBy: 'sort_order ASC');
    final classPrefs = <String, dynamic>{};
    for (final row in classes) {
      final id = row['id']! as String;
      classPrefs[id] = await _exportClassPrefs(id);
    }
    return {
      'version': 10,
      'exportedAt': DateTime.now().toIso8601String(),
      'current_class_id': _prefs.getString(_currentClassPrefKey),
      'classes': classes,
      'students': await db.query('students'),
      'attendance': await db.query('attendance'),
      'point_records': await db.query('point_records'),
      'duty': await db.query('duty'),
      'class_notes': await db.query('class_notes'),
      'homework': await db.query('homework'),
      'rewards': await db.query('rewards'),
      'timetable': await db.query('timetable'),
      'settlements': await db.query('settlements'),
      'countdowns': await db.query('countdowns'),
      'fund_records': await db.query('fund_records'),
      'work_logs': await db.query('work_logs'),
      'exams': await db.query('exams'),
      'exam_scores': await db.query('exam_scores'),
      'semesters': await db.query('semesters'),
      'lesson_units': await db.query('lesson_units'),
      'lesson_files': await db.query('lesson_files'),
      'exam_files': await db.query('exam_files'),
      'salary_records': await db.query('salary_records'),
      'class_prefs': classPrefs,
      'profile': {
        'name': loadProfile().name,
        'grade': loadProfile().grade,
        'seatRows': loadProfile().seatRows,
        'seatCols': loadProfile().seatCols,
      },
      'point_reasons': loadPointReasons(),
      'point_presets': loadPointPresets().map((e) => e.toJson()).toList(),
      'class_roles': loadRolePresets(),
      'exam_categories': loadExamCategories(),
      'roll_history': _prefs.getStringList(_scopedPrefKey('roll_history')) ?? [],
    };
  }

  Future<void> _wipeAllData(DatabaseExecutor db) async {
    for (final t in [
      'duty',
      'point_records',
      'attendance',
      'students',
      'class_notes',
      'homework',
      'rewards',
      'timetable',
      'settlements',
      'countdowns',
      'fund_records',
      'work_logs',
      'exam_scores',
      'exams',
      'exam_files',
      'semesters',
      'lesson_files',
      'lesson_units',
      'classes',
      'salary_records',
    ]) {
      await db.delete(t);
    }
  }

  Future<void> _wipeCurrentClassBusinessData() async {
    final db = await AppDatabase.instance.database;
    final cid = currentClassId;
    await db.rawDelete(
      'DELETE FROM exam_scores WHERE exam_id IN (SELECT id FROM exams WHERE class_id = ?)',
      [cid],
    );
    for (final t in _businessTables) {
      await db.delete(t, where: 'class_id = ?', whereArgs: [cid]);
    }
  }

  Future<void> importBackup(Map<String, dynamic> data) async {
    final db = await AppDatabase.instance.database;
    final classesRaw = data['classes'] as List?;

    if (classesRaw != null && classesRaw.isNotEmpty) {
      await db.transaction((txn) async {
        await _wipeAllData(txn);
      });

      Future<void> insertAll(String table, List? rows) async {
        for (final raw in rows ?? []) {
          await db.insert(
            table,
            Map<String, Object?>.from(raw as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      for (final raw in classesRaw) {
        await db.insert(
          'classes',
          Map<String, Object?>.from(raw as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await insertAll('students', data['students'] as List?);
      await insertAll('attendance', data['attendance'] as List?);
      await insertAll('point_records', data['point_records'] as List?);
      await insertAll('duty', data['duty'] as List?);
      await insertAll('class_notes', data['class_notes'] as List?);
      await insertAll('homework', data['homework'] as List?);
      await insertAll('rewards', data['rewards'] as List?);
      await insertAll('timetable', data['timetable'] as List?);
      await insertAll('settlements', data['settlements'] as List?);
      await insertAll('countdowns', data['countdowns'] as List?);
      await insertAll('fund_records', data['fund_records'] as List?);
      await insertAll('work_logs', data['work_logs'] as List?);
      await insertAll('exams', data['exams'] as List?);
      await insertAll('exam_scores', data['exam_scores'] as List?);
      await insertAll('semesters', data['semesters'] as List?);
      await insertAll('lesson_units', data['lesson_units'] as List?);
      await insertAll('lesson_files', data['lesson_files'] as List?);
      await insertAll('exam_files', data['exam_files'] as List?);
      await insertAll('salary_records', data['salary_records'] as List?);

      final savedId = data['current_class_id'] as String?;
      final allClasses = await getClasses();
      if (savedId != null &&
          savedId.isNotEmpty &&
          allClasses.any((c) => c.id == savedId)) {
        await setCurrentClassId(savedId);
      } else if (allClasses.isNotEmpty) {
        await setCurrentClassId(allClasses.first.id);
      }

      final classPrefs = data['class_prefs'] as Map<String, dynamic>?;
      if (classPrefs != null) {
        for (final entry in classPrefs.entries) {
          await _importClassPrefs(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    } else {
      await _wipeCurrentClassBusinessData();

      final profile = data['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        await saveProfile(
          ClassProfile(
            name: (profile['name'] as String?) ?? '高一（1）班',
            grade: (profile['grade'] as String?) ?? '高一',
            seatRows: (profile['seatRows'] as int?) ?? 6,
            seatCols: (profile['seatCols'] as int?) ?? 8,
          ),
        );
      }

      Future<void> insertScoped(String table, List? rows) async {
        for (final raw in rows ?? []) {
          await db.insert(
            table,
            _withClass(Map<String, Object?>.from(raw as Map)),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final students = (data['students'] as List?) ?? [];
      for (final raw in students) {
        await upsertStudent(
          Student.fromMap(Map<String, Object?>.from(raw as Map)),
        );
      }
      await insertScoped('attendance', data['attendance'] as List?);
      await insertScoped('point_records', data['point_records'] as List?);
      await insertScoped('duty', data['duty'] as List?);
      await insertScoped('class_notes', data['class_notes'] as List?);
      await insertScoped('homework', data['homework'] as List?);
      await insertScoped('rewards', data['rewards'] as List?);
      await insertScoped('timetable', data['timetable'] as List?);
      await insertScoped('settlements', data['settlements'] as List?);
      await insertScoped('countdowns', data['countdowns'] as List?);
      await insertScoped('fund_records', data['fund_records'] as List?);
      await insertScoped('work_logs', data['work_logs'] as List?);
      await insertScoped('exams', data['exams'] as List?);
      for (final raw in data['exam_scores'] as List? ?? []) {
        await db.insert(
          'exam_scores',
          Map<String, Object?>.from(raw as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await insertScoped('semesters', data['semesters'] as List?);
      await insertScoped('lesson_units', data['lesson_units'] as List?);
      await insertScoped('lesson_files', data['lesson_files'] as List?);
      await insertScoped('exam_files', data['exam_files'] as List?);

      final presetsRaw = data['point_presets'] as List?;
      if (presetsRaw != null && presetsRaw.isNotEmpty) {
        await savePointPresets([
          for (final e in presetsRaw)
            PointReasonPreset.fromJson(Map<String, dynamic>.from(e as Map)),
        ]);
      } else {
        final reasons = (data['point_reasons'] as List?)?.cast<String>();
        if (reasons != null) await savePointReasons(reasons);
      }
      final roll = (data['roll_history'] as List?)?.cast<String>();
      if (roll != null) {
        await _prefs.setStringList(_scopedPrefKey('roll_history'), roll);
      }
      final roles = (data['class_roles'] as List?)?.cast<String>();
      if (roles != null) await saveRolePresets(roles);
      final examCats = (data['exam_categories'] as List?)?.cast<String>();
      if (examCats != null) await saveExamCategories(examCats);
    }

    await ensureActiveSemester();
  }

  // ── Misc ──────────────────────────────────────────────────────────────────

  String exportRankingText(List<Student> ranked) {
    final buf = StringBuffer('名次,姓名,学号,小组,班委,积分,段位\n');
    for (var i = 0; i < ranked.length; i++) {
      final s = ranked[i];
      buf.writeln(
        '${i + 1},${s.name},${s.studentNo},${s.groupName},${s.role},${s.points},${rankTitle(s.points)}',
      );
    }
    return buf.toString();
  }

  Future<void> seedDemoStudents() async {
    await seedDemoData();
  }

  /// 为空的模块填充演示数据，便于试用（已有数据不覆盖）
  Future<void> seedDemoData() async {
    String ymd(DateTime t) =>
        '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var students = await getStudents();
    if (students.isEmpty) {
      final names = [
        ('张明', '01', '男', '一组'),
        ('李华', '02', '女', '一组'),
        ('王芳', '03', '女', '一组'),
        ('赵强', '04', '男', '二组'),
        ('陈静', '05', '女', '二组'),
        ('刘洋', '06', '男', '二组'),
        ('杨柳', '07', '女', '三组'),
        ('黄磊', '08', '男', '三组'),
        ('周倩', '09', '女', '三组'),
        ('吴昊', '10', '男', '四组'),
        ('徐婷', '11', '女', '四组'),
        ('孙杰', '12', '男', '四组'),
      ];
      var index = 0;
      for (final (name, no, gender, group) in names) {
        final row = index ~/ 8;
        final col = index % 8;
        await upsertStudent(
          Student(
            id: _uuid.v4(),
            name: name,
            studentNo: no,
            gender: gender,
            phone: '1380000${no.padLeft(4, '0')}',
            note: '',
            groupName: group,
            role: index == 0
                ? '班长'
                : (index == 1
                    ? '学习委员'
                    : (index == 3 ? '组长' : '')),
            birthday:
                '${((index % 12) + 1).toString().padLeft(2, '0')}-${((index % 28) + 1).toString().padLeft(2, '0')}',
            points: 80 + (index * 3) % 20,
            seatRow: row,
            seatCol: col,
            createdAt: now,
          ),
        );
        index++;
      }
      students = await getStudents();
    }

    if ((await getRewards()).isEmpty) {
      for (final (name, cost, stock) in [
        ('铅笔', 5, 50),
        ('本子', 10, 30),
        ('免作业券', 30, 10),
        ('小奖状', 50, 5),
      ]) {
        await upsertReward(
          RewardItem(id: _uuid.v4(), name: name, cost: cost, stock: stock),
        );
      }
    }

    if ((await getCountdowns()).isEmpty) {
      for (final (title, days) in [
        ('期中考试', 12),
        ('家长会', 5),
        ('国庆放假', 20),
        ('运动会', 28),
        ('期末考试', 55),
        ('上学期开学', -10),
      ]) {
        await upsertCountdown(
          CountdownItem(
            id: _uuid.v4(),
            title: title,
            targetDate: ymd(today.add(Duration(days: days))),
            createdAt: now,
          ),
        );
      }
    }

    if ((await getFundRecords()).isEmpty) {
      for (final (title, amount, daysAgo, note) in [
        ('班费收取', 500, 20, '每生 50 元 × 10'),
        ('购买扫把拖把', -68, 15, '超市采购'),
        ('班级活动零食', -120, 7, '主题班会'),
        ('废品回收', 35, 3, '废纸箱'),
      ]) {
        await upsertFundRecord(
          FundRecord(
            id: _uuid.v4(),
            title: title,
            amount: amount,
            date: ymd(today.subtract(Duration(days: daysAgo))),
            note: note,
            createdAt: now,
          ),
        );
      }
    }

    if ((await getWorkLogs()).isEmpty) {
      final sid = students.isNotEmpty ? students.first.id : '';
      final samples = <(WorkLogCategory, String, String, int)>[
        (
          WorkLogCategory.classMeeting,
          '诚信考试主题班会',
          '组织观看案例视频，小组讨论并签订诚信承诺。',
          2
        ),
        (
          WorkLogCategory.safetyEdu,
          '防溺水安全教育',
          '强调假期水域安全，发放致家长一封信。',
          5
        ),
        (
          WorkLogCategory.studentTalk,
          '与班长谈值日落实',
          '沟通值日检查表执行情况，约定本周复查。',
          1
        ),
        (
          WorkLogCategory.parentComm,
          '电话沟通作业习惯',
          '与家长沟通晚间作业安排，家长表示配合督促。',
          3
        ),
      ];
      for (final (cat, title, content, daysAgo) in samples) {
        await upsertWorkLog(
          WorkLog(
            id: _uuid.v4(),
            category: cat,
            title: title,
            content: content,
            date: ymd(today.subtract(Duration(days: daysAgo))),
            studentIds: cat == WorkLogCategory.studentTalk ? sid : '',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    if ((await getNotes()).isEmpty) {
      await upsertNote(
        ClassNote(
          id: _uuid.v4(),
          title: '本周关注',
          content: '① 周三教研；② 周五校服检查；③ 学困生作业面批。',
          createdAt: now,
        ),
      );
      await upsertNote(
        ClassNote(
          id: _uuid.v4(),
          title: '家长会要点草稿',
          content: '学情概述、下阶段目标、家校配合事项。',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      );
    }

    final todayStr = ymd(today);
    final hw = await getHomework(date: todayStr);
    if (hw.isEmpty) {
      await upsertHomework(
        HomeworkItem(
          id: _uuid.v4(),
          title: '语文：背诵第 3 课生字',
          date: todayStr,
        ),
      );
      await upsertHomework(
        HomeworkItem(
          id: _uuid.v4(),
          title: '数学：练习册 P12–13',
          date: todayStr,
        ),
      );
    }

    if ((await getTimetable()).isEmpty) {
      const subjects = [
        '语文',
        '数学',
        '英语',
        '物理',
        '化学',
        '体育',
        '班会',
      ];
      var i = 0;
      for (var weekday = 1; weekday <= 5; weekday++) {
        for (var period = 1; period <= 4; period++) {
          await upsertTimetableSlot(
            TimetableSlot(
              id: _uuid.v4(),
              weekday: weekday,
              period: period,
              subject: subjects[i % subjects.length],
            ),
          );
          i++;
        }
      }
    }

    if ((await getExams()).isEmpty) {
      final examId = _uuid.v4();
      await upsertExam(
        Exam(
          id: examId,
          title: '三月月考',
          category: '月考',
          examDate: ymd(today.subtract(const Duration(days: 8))),
          subjects: const ['语文', '数学', '英语'],
          fullScore: 100,
          passScore: 60,
          note: '演示考试，可导入成绩或手动录入',
          createdAt: now,
          updatedAt: now,
        ),
      );
      // 给前几名学生写一点分数
      for (var i = 0; i < students.length && i < 8; i++) {
        final s = students[i];
        await upsertExamScore(
          ExamScore(
            id: _uuid.v4(),
            examId: examId,
            studentId: s.id,
            scores: {
              '语文': 72.0 + i * 2,
              '数学': 68.0 + i * 3,
              '英语': 75.0 + i,
            },
          ),
        );
      }
    }

    if ((await getSalaryRecords()).isEmpty) {
      final ym =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await upsertSalaryRecord(
        SalaryRecord(
          id: _uuid.v4(),
          yearMonth: ym,
          title: '基本工资',
          baseAmount: 6800,
          allowance: 800,
          deduction: 200,
          netAmount: 7400,
          paidAt: ymd(today.subtract(const Duration(days: 2))),
          note: '演示数据',
          createdAt: now,
        ),
      );
    }
  }
}
