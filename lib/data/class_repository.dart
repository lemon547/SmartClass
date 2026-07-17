import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:smart_class/data/app_database.dart';
import 'package:smart_class/models/models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class ClassRepository {
  final _uuid = const Uuid();
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await AppDatabase.instance.database;
  }

  ClassProfile loadProfile() {
    return ClassProfile(
      name: _prefs.getString('class_name') ?? '高一（1）班',
      grade: _prefs.getString('class_grade') ?? '高一',
      seatRows: _prefs.getInt('seat_rows') ?? 6,
      seatCols: _prefs.getInt('seat_cols') ?? 8,
    );
  }

  Future<void> saveProfile(ClassProfile profile) async {
    await _prefs.setString('class_name', profile.name);
    await _prefs.setString('class_grade', profile.grade);
    await _prefs.setInt('seat_rows', profile.seatRows);
    await _prefs.setInt('seat_cols', profile.seatCols);
  }

  Future<List<Student>> getStudents() async {
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('students', orderBy: 'student_no ASC, name ASC');
    return rows.map(Student.fromMap).toList();
  }

  Future<void> upsertStudent(Student student) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteStudent(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('students', where: 'id = ?', whereArgs: [id]);
    await db.delete('attendance', where: 'student_id = ?', whereArgs: [id]);
    await db.delete('point_records', where: 'student_id = ?', whereArgs: [id]);
    await db.delete('duty', where: 'student_id = ?', whereArgs: [id]);
  }

  Future<List<AttendanceRecord>> getAttendanceByDate(String date) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
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
      where: 'student_id = ? AND date = ?',
      whereArgs: [studentId, date],
      limit: 1,
    );
    final id = existing.isEmpty ? _uuid.v4() : existing.first['id']! as String;
    await db.insert(
      'attendance',
      AttendanceRecord(
        id: id,
        studentId: studentId,
        date: date,
        status: status,
        remark: remark,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PointRecord>> getPointRecords({int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
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
        PointRecord(
          id: _uuid.v4(),
          studentId: studentId,
          delta: delta,
          reason: reason,
          createdAt: DateTime.now(),
        ).toMap(),
      );
      await txn.rawUpdate(
        'UPDATE students SET points = points + ? WHERE id = ?',
        [delta, studentId],
      );
    });
  }

  Future<List<DutyAssignment>> getDuty() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('duty', orderBy: 'weekday ASC');
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
      where: 'weekday = ? AND student_id = ?',
      whereArgs: [weekday, studentId],
    );
    await db.insert(
      'duty',
      DutyAssignment(
        id: _uuid.v4(),
        weekday: weekday,
        studentId: studentId,
        task: task,
      ).toMap(),
    );
  }

  Future<void> removeDuty(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('duty', where: 'id = ?', whereArgs: [id]);
  }

  /// 值日整体后移一天（周一→周二…周日→周一），参考智慧校园「按周轮值」
  Future<void> rotateDutyForward() async {
    final list = await getDuty();
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('duty');
      for (final d in list) {
        final next = d.weekday == 7 ? 1 : d.weekday + 1;
        await txn.insert(
          'duty',
          DutyAssignment(
            id: _uuid.v4(),
            weekday: next,
            studentId: d.studentId,
            task: d.task,
          ).toMap(),
        );
      }
    });
  }

  Future<void> updateSeat({
    required String studentId,
    int? row,
    int? col,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'students',
      {'seat_row': row, 'seat_col': col},
      where: 'id = ?',
      whereArgs: [studentId],
    );
  }

  Future<List<String>> getAttendanceDates({int limit = 60}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM attendance ORDER BY date DESC LIMIT ?',
      [limit],
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

  List<String> loadPointReasons() =>
      loadPointPresets().map((e) => e.reason).toList();

  List<PointReasonPreset> loadPointPresets() {
    final raw = _prefs.getString('point_presets_json');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => PointReasonPreset.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((e) => e.reason.isNotEmpty)
            .toList();
      } catch (_) {}
    }
    final legacy = _prefs.getStringList('point_reasons');
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
      'point_presets_json',
      jsonEncode(presets.map((e) => e.toJson()).toList()),
    );
    await _prefs.setStringList(
      'point_reasons',
      presets.map((e) => e.reason).toList(),
    );
  }

  Future<PointRecord?> undoLastPoint() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final record = PointRecord.fromMap(rows.first);
    await db.transaction((txn) async {
      await txn.delete('point_records', where: 'id = ?', whereArgs: [record.id]);
      await txn.rawUpdate(
        'UPDATE students SET points = points - ? WHERE id = ?',
        [record.delta, record.studentId],
      );
    });
    return record;
  }

  Future<Map<String, int>> pointsDeltaSince(DateTime since) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      where: 'created_at >= ?',
      whereArgs: [since.toIso8601String()],
    );
    final map = <String, int>{};
    for (final row in rows) {
      final id = row['student_id']! as String;
      final delta = row['delta']! as int;
      map[id] = (map[id] ?? 0) + delta;
    }
    return map;
  }

  Future<List<Settlement>> getSettlements() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('settlements', orderBy: 'created_at DESC');
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
    await db.insert('settlements', settlement.toMap());
    await resetAllPoints();
    return settlement;
  }

  Future<void> deleteSettlement(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('settlements', where: 'id = ?', whereArgs: [id]);
  }

  List<Map<String, dynamic>> loadRollHistory() {
    final raw = _prefs.getStringList('roll_history') ?? [];
    return raw.map((e) {
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
    final list = _prefs.getStringList('roll_history') ?? [];
    list.insert(0, '$studentId|$name|${DateTime.now().toIso8601String()}');
    if (list.length > 100) {
      list.removeRange(100, list.length);
    }
    await _prefs.setStringList('roll_history', list);
  }

  Future<void> clearRollHistory() async {
    await _prefs.remove('roll_history');
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final students = await getStudents();
    final db = await AppDatabase.instance.database;
    final attendance = await db.query('attendance');
    final points = await db.query('point_records');
    final duty = await db.query('duty');
    final notes = await db.query('class_notes');
    final homework = await db.query('homework');
    final rewards = await db.query('rewards');
    final timetable = await db.query('timetable');
    final settlements = await db.query('settlements');
    final countdowns = await db.query('countdowns');
    final funds = await db.query('fund_records');
    return {
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': {
        'name': loadProfile().name,
        'grade': loadProfile().grade,
        'seatRows': loadProfile().seatRows,
        'seatCols': loadProfile().seatCols,
      },
      'students': students.map((e) => e.toMap()).toList(),
      'attendance': attendance,
      'point_records': points,
      'duty': duty,
      'class_notes': notes,
      'homework': homework,
      'rewards': rewards,
      'timetable': timetable,
      'settlements': settlements,
      'countdowns': countdowns,
      'fund_records': funds,
      'point_reasons': loadPointReasons(),
      'point_presets': loadPointPresets().map((e) => e.toJson()).toList(),
      'roll_history': _prefs.getStringList('roll_history') ?? [],
    };
  }

  Future<void> importBackup(Map<String, dynamic> data) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
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
      ]) {
        await txn.delete(t);
      }
    });

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

    Future<void> insertAll(String table, List? rows) async {
      for (final raw in rows ?? []) {
        await db.insert(
          table,
          Map<String, Object?>.from(raw as Map),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    final students = (data['students'] as List?) ?? [];
    for (final raw in students) {
      await upsertStudent(Student.fromMap(Map<String, Object?>.from(raw as Map)));
    }
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
    if (roll != null) await _prefs.setStringList('roll_history', roll);
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

  Future<List<AttendanceRecord>> getAttendanceByStudent(String studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'date DESC',
      limit: 60,
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<List<PointRecord>> getPointRecordsByStudent(String studentId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'point_records',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'created_at DESC',
      limit: 80,
    );
    return rows.map(PointRecord.fromMap).toList();
  }

  Future<void> resetAllPoints() async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update('students', {'points': 0});
      await txn.delete('point_records');
    });
  }

  Future<List<ClassNote>> getNotes() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('class_notes', orderBy: 'created_at DESC');
    return rows.map(ClassNote.fromMap).toList();
  }

  Future<void> upsertNote(ClassNote note) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'class_notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('class_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<HomeworkItem>> getHomework({String? date}) async {
    final db = await AppDatabase.instance.database;
    final rows = date == null
        ? await db.query('homework', orderBy: 'date DESC')
        : await db.query(
            'homework',
            where: 'date = ?',
            whereArgs: [date],
            orderBy: 'title ASC',
          );
    return rows.map(HomeworkItem.fromMap).toList();
  }

  Future<void> upsertHomework(HomeworkItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'homework',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHomework(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('homework', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RewardItem>> getRewards() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('rewards', orderBy: 'cost ASC');
    return rows.map(RewardItem.fromMap).toList();
  }

  Future<void> upsertReward(RewardItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'rewards',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReward(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('rewards', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> redeemReward({
    required String studentId,
    required RewardItem reward,
  }) async {
    if (reward.stock <= 0) return false;
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'students',
      where: 'id = ?',
      whereArgs: [studentId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final points = rows.first['points']! as int;
    if (points < reward.cost) return false;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE students SET points = points - ? WHERE id = ?',
        [reward.cost, studentId],
      );
      await txn.insert(
        'point_records',
        PointRecord(
          id: _uuid.v4(),
          studentId: studentId,
          delta: -reward.cost,
          reason: '兑换：${reward.name}',
          createdAt: DateTime.now(),
        ).toMap(),
      );
      await txn.update(
        'rewards',
        {'stock': reward.stock - 1},
        where: 'id = ?',
        whereArgs: [reward.id],
      );
    });
    return true;
  }

  Future<List<TimetableSlot>> getTimetable() async {
    final db = await AppDatabase.instance.database;
    final rows =
        await db.query('timetable', orderBy: 'weekday ASC, period ASC');
    return rows.map(TimetableSlot.fromMap).toList();
  }

  Future<void> upsertTimetableSlot(TimetableSlot slot) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'timetable',
      where: 'weekday = ? AND period = ?',
      whereArgs: [slot.weekday, slot.period],
    );
    await db.insert('timetable', slot.toMap());
  }

  Future<void> clearTimetableSlot(int weekday, int period) async {
    final db = await AppDatabase.instance.database;
    await db.delete(
      'timetable',
      where: 'weekday = ? AND period = ?',
      whereArgs: [weekday, period],
    );
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

  Future<List<CountdownItem>> getCountdowns() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('countdowns', orderBy: 'target_date ASC');
    return rows.map(CountdownItem.fromMap).toList();
  }

  Future<void> upsertCountdown(CountdownItem item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'countdowns',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCountdown(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('countdowns', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FundRecord>> getFundRecords() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('fund_records', orderBy: 'date DESC, created_at DESC');
    return rows.map(FundRecord.fromMap).toList();
  }

  Future<void> upsertFundRecord(FundRecord item) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'fund_records',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFundRecord(String id) async {
    final db = await AppDatabase.instance.database;
    await db.delete('fund_records', where: 'id = ?', whereArgs: [id]);
  }

  /// 排行榜文本（参考 SecScore 导出）
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
          birthday: '${((index % 12) + 1).toString().padLeft(2, '0')}-${((index % 28) + 1).toString().padLeft(2, '0')}',
          points: 80 + (index * 3) % 20,
          seatRow: row,
          seatCol: col,
          createdAt: DateTime.now(),
        ),
      );
      index++;
    }
    final rewards = [
      ('铅笔', 5, 50),
      ('本子', 10, 30),
      ('免作业券', 30, 10),
      ('小奖状', 50, 5),
    ];
    for (final (name, cost, stock) in rewards) {
      await upsertReward(
        RewardItem(id: _uuid.v4(), name: name, cost: cost, stock: stock),
      );
    }
  }
}
