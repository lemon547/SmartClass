import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/models/models.dart';
import 'package:uuid/uuid.dart';

class ClassController extends ChangeNotifier {
  ClassController(this._repo);

  final ClassRepository _repo;
  final _uuid = const Uuid();

  ClassProfile profile = const ClassProfile();
  List<Student> students = [];
  List<AttendanceRecord> selectedAttendance = [];
  List<PointRecord> pointRecords = [];
  List<DutyAssignment> dutyList = [];
  List<PointReasonPreset> pointPresets = [];
  List<Settlement> settlements = [];
  List<CountdownItem> countdowns = [];
  List<FundRecord> fundRecords = [];
  List<Map<String, dynamic>> rollHistory = [];
  List<ClassNote> notes = [];
  List<HomeworkItem> homework = [];
  List<RewardItem> rewards = [];
  List<TimetableSlot> timetable = [];
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool loading = true;
  String? error;

  /// today | week | month | total
  String rankPeriod = 'total';
  Map<String, int> periodDeltas = {};

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  List<String> get pointReasons =>
      pointPresets.map((e) => e.reason).toList();

  Student? studentById(String id) {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  Map<String, AttendanceStatus> get attendanceMap => {
        for (final r in selectedAttendance) r.studentId: r.status,
      };

  List<Student> get rankedByPoints {
    final list = [...students];
    if (rankPeriod == 'total') {
      list.sort((a, b) => b.points.compareTo(a.points));
    } else {
      list.sort((a, b) {
        final da = periodDeltas[a.id] ?? 0;
        final db = periodDeltas[b.id] ?? 0;
        return db.compareTo(da);
      });
    }
    return list;
  }

  int scoreForRank(Student s) =>
      rankPeriod == 'total' ? s.points : (periodDeltas[s.id] ?? 0);

  List<String> get groupNames {
    final set = <String>{};
    for (final s in students) {
      if (s.groupName.trim().isNotEmpty) set.add(s.groupName.trim());
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Student> studentsInGroup(String group) =>
      students.where((s) => s.groupName == group).toList();

  List<Student> searchStudents(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return students;
    return students.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.studentNo.toLowerCase().contains(q) ||
          s.phone.contains(q) ||
          s.note.toLowerCase().contains(q) ||
          s.groupName.toLowerCase().contains(q);
    }).toList();
  }

  int countStatus(AttendanceStatus status) =>
      selectedAttendance.where((e) => e.status == status).length;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = _repo.loadProfile();
      students = await _repo.getStudents();
      selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
      pointRecords = await _repo.getPointRecords(limit: 100);
      dutyList = await _repo.getDuty();
      pointPresets = _repo.loadPointPresets();
      settlements = await _repo.getSettlements();
      countdowns = await _repo.getCountdowns();
      fundRecords = await _repo.getFundRecords();
      rollHistory = _repo.loadRollHistory();
      notes = await _repo.getNotes();
      homework = await _repo.getHomework(date: selectedDate);
      rewards = await _repo.getRewards();
      timetable = await _repo.getTimetable();
      await _refreshPeriodDeltas();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setSelectedDate(DateTime date) async {
    selectedDate = DateFormat('yyyy-MM-dd').format(date);
    selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
    homework = await _repo.getHomework(date: selectedDate);
    notifyListeners();
  }

  Future<void> updateProfile(ClassProfile next) async {
    profile = next;
    await _repo.saveProfile(next);
    notifyListeners();
  }

  Future<void> seedDemo() async {
    if (students.isNotEmpty) return;
    await _repo.seedDemoStudents();
    await load();
  }

  Future<void> saveStudent({
    String? id,
    required String name,
    String studentNo = '',
    String gender = '未知',
    String phone = '',
    String note = '',
    String groupName = '',
    String role = '',
    String birthday = '',
  }) async {
    final existing = id == null ? null : studentById(id);
    final student = Student(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      studentNo: studentNo.trim(),
      gender: gender,
      phone: phone.trim(),
      note: note.trim(),
      groupName: groupName.trim(),
      role: role.trim(),
      birthday: birthday.trim(),
      points: existing?.points ?? 0,
      seatRow: existing?.seatRow,
      seatCol: existing?.seatCol,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await _repo.upsertStudent(student);
    await load();
  }

  Future<void> batchAddStudents(List<String> names) async {
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      await _repo.upsertStudent(
        Student(id: _uuid.v4(), name: name, createdAt: DateTime.now()),
      );
    }
    await load();
  }

  Future<void> removeStudent(String id) async {
    await _repo.deleteStudent(id);
    await load();
  }

  Future<void> markAttendance(
    String studentId,
    AttendanceStatus status, {
    String remark = '',
  }) async {
    await _repo.setAttendance(
      studentId: studentId,
      date: selectedDate,
      status: status,
      remark: remark,
    );
    selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
    notifyListeners();
  }

  Future<void> markAllPresent() async {
    for (final s in students) {
      await _repo.setAttendance(
        studentId: s.id,
        date: selectedDate,
        status: AttendanceStatus.present,
      );
    }
    selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
    notifyListeners();
  }

  Future<void> adjustPoints({
    required String studentId,
    required int delta,
    required String reason,
  }) async {
    await _repo.addPoints(
      studentId: studentId,
      delta: delta,
      reason: reason.trim().isEmpty ? (delta >= 0 ? '表扬' : '提醒') : reason,
    );
    students = await _repo.getStudents();
    pointRecords = await _repo.getPointRecords(limit: 100);
    await _refreshPeriodDeltas();
    notifyListeners();
  }

  Future<void> resetAllPoints() async {
    await _repo.resetAllPoints();
    await load();
  }

  Future<void> savePointReasons(List<String> reasons) async {
    pointPresets = [
      for (final r in reasons) PointReasonPreset(reason: r, delta: 1),
    ];
    await _repo.savePointPresets(pointPresets);
    notifyListeners();
  }

  Future<void> savePointPresets(List<PointReasonPreset> presets) async {
    pointPresets = presets;
    await _repo.savePointPresets(presets);
    notifyListeners();
  }

  Future<void> setRankPeriod(String period) async {
    rankPeriod = period;
    await _refreshPeriodDeltas();
    notifyListeners();
  }

  Future<void> _refreshPeriodDeltas() async {
    if (rankPeriod == 'total') {
      periodDeltas = {};
      return;
    }
    final now = DateTime.now();
    late DateTime since;
    if (rankPeriod == 'today') {
      since = DateTime(now.year, now.month, now.day);
    } else if (rankPeriod == 'week') {
      since = now.subtract(Duration(days: now.weekday - 1));
      since = DateTime(since.year, since.month, since.day);
    } else {
      since = DateTime(now.year, now.month, 1);
    }
    periodDeltas = await _repo.pointsDeltaSince(since);
  }

  Future<PointRecord?> undoLastPoint() async {
    final record = await _repo.undoLastPoint();
    if (record != null) await load();
    return record;
  }

  Future<void> settleAndRestart(String name) async {
    await _repo.settleAndRestart(name: name.trim().isEmpty ? '阶段结算' : name.trim());
    await load();
  }

  Future<void> deleteSettlement(String id) async {
    await _repo.deleteSettlement(id);
    settlements = await _repo.getSettlements();
    notifyListeners();
  }

  Future<void> recordRollCall(Student student) async {
    await _repo.addRollHistory(studentId: student.id, name: student.name);
    rollHistory = _repo.loadRollHistory();
    notifyListeners();
  }

  Future<void> clearRollHistory() async {
    await _repo.clearRollHistory();
    rollHistory = [];
    notifyListeners();
  }

  Future<void> assignDuty({
    required int weekday,
    required String studentId,
    String task = '值日',
  }) async {
    await _repo.setDuty(weekday: weekday, studentId: studentId, task: task);
    dutyList = await _repo.getDuty();
    notifyListeners();
  }

  Future<void> removeDuty(String id) async {
    await _repo.removeDuty(id);
    dutyList = await _repo.getDuty();
    notifyListeners();
  }

  Future<void> rotateDutyForward() async {
    await _repo.rotateDutyForward();
    dutyList = await _repo.getDuty();
    notifyListeners();
  }

  List<Student> get todayBirthdays =>
      students.where((s) => s.isBirthdayToday).toList();

  List<Student> get upcomingBirthdays {
    final list = students
        .where((s) => s.daysUntilBirthday != null)
        .toList()
      ..sort((a, b) =>
          (a.daysUntilBirthday ?? 999).compareTo(b.daysUntilBirthday ?? 999));
    return list.take(8).toList();
  }

  CountdownItem? get nearestCountdown {
    if (countdowns.isEmpty) return null;
    final sorted = [...countdowns]
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return sorted.first;
  }

  int get fundBalance =>
      fundRecords.fold(0, (sum, e) => sum + e.amount);

  Future<void> saveCountdown({
    String? id,
    required String title,
    required String targetDate,
  }) async {
    await _repo.upsertCountdown(
      CountdownItem(
        id: id ?? _uuid.v4(),
        title: title.trim(),
        targetDate: targetDate,
        createdAt: DateTime.now(),
      ),
    );
    countdowns = await _repo.getCountdowns();
    notifyListeners();
  }

  Future<void> deleteCountdown(String id) async {
    await _repo.deleteCountdown(id);
    countdowns = await _repo.getCountdowns();
    notifyListeners();
  }

  Future<void> saveFundRecord({
    String? id,
    required String title,
    required int amount,
    required String date,
    String note = '',
  }) async {
    await _repo.upsertFundRecord(
      FundRecord(
        id: id ?? _uuid.v4(),
        title: title.trim(),
        amount: amount,
        date: date,
        note: note.trim(),
        createdAt: DateTime.now(),
      ),
    );
    fundRecords = await _repo.getFundRecords();
    notifyListeners();
  }

  Future<void> deleteFundRecord(String id) async {
    await _repo.deleteFundRecord(id);
    fundRecords = await _repo.getFundRecords();
    notifyListeners();
  }

  Future<String> exportRankingFile() async {
    final text = _repo.exportRankingText(rankedByPoints);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        dir.path,
        '积分排行_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      ),
    );
    await file.writeAsString(text, encoding: utf8);
    return file.path;
  }

  Future<void> placeStudent(String studentId, int row, int col) async {
    for (final s in students) {
      if (s.seatRow == row && s.seatCol == col && s.id != studentId) {
        await _repo.updateSeat(studentId: s.id, row: null, col: null);
      }
    }
    await _repo.updateSeat(studentId: studentId, row: row, col: col);
    students = await _repo.getStudents();
    notifyListeners();
  }

  Future<void> clearSeat(String studentId) async {
    await _repo.updateSeat(studentId: studentId, row: null, col: null);
    students = await _repo.getStudents();
    notifyListeners();
  }

  Future<void> autoArrangeSeats() async {
    await _repo.autoArrangeSeats(
      rows: profile.seatRows,
      cols: profile.seatCols,
    );
    students = await _repo.getStudents();
    notifyListeners();
  }

  Future<List<AttendanceRecord>> attendanceOf(String studentId) =>
      _repo.getAttendanceByStudent(studentId);

  Future<List<PointRecord>> pointsOf(String studentId) =>
      _repo.getPointRecordsByStudent(studentId);

  Future<void> saveNote({String? id, required String title, required String content}) async {
    await _repo.upsertNote(
      ClassNote(
        id: id ?? _uuid.v4(),
        title: title.trim(),
        content: content.trim(),
        createdAt: DateTime.now(),
      ),
    );
    notes = await _repo.getNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _repo.deleteNote(id);
    notes = await _repo.getNotes();
    notifyListeners();
  }

  Future<void> saveHomework(String title) async {
    await _repo.upsertHomework(
      HomeworkItem(
        id: _uuid.v4(),
        title: title.trim(),
        date: selectedDate,
      ),
    );
    homework = await _repo.getHomework(date: selectedDate);
    notifyListeners();
  }

  Future<void> toggleHomeworkDone(HomeworkItem item, String studentId) async {
    final set = item.doneSet;
    if (set.contains(studentId)) {
      set.remove(studentId);
    } else {
      set.add(studentId);
    }
    await _repo.upsertHomework(
      HomeworkItem(
        id: item.id,
        title: item.title,
        date: item.date,
        doneIds: set.join(','),
      ),
    );
    homework = await _repo.getHomework(date: selectedDate);
    notifyListeners();
  }

  Future<void> deleteHomework(String id) async {
    await _repo.deleteHomework(id);
    homework = await _repo.getHomework(date: selectedDate);
    notifyListeners();
  }

  Future<void> saveReward({
    String? id,
    required String name,
    required int cost,
    int stock = 99,
  }) async {
    await _repo.upsertReward(
      RewardItem(
        id: id ?? _uuid.v4(),
        name: name.trim(),
        cost: cost,
        stock: stock,
      ),
    );
    rewards = await _repo.getRewards();
    notifyListeners();
  }

  Future<void> deleteReward(String id) async {
    await _repo.deleteReward(id);
    rewards = await _repo.getRewards();
    notifyListeners();
  }

  Future<bool> redeemReward(String studentId, RewardItem reward) async {
    final ok = await _repo.redeemReward(studentId: studentId, reward: reward);
    if (ok) await load();
    return ok;
  }

  Future<void> setTimetableSlot({
    required int weekday,
    required int period,
    required String subject,
  }) async {
    if (subject.trim().isEmpty) {
      await _repo.clearTimetableSlot(weekday, period);
    } else {
      await _repo.upsertTimetableSlot(
        TimetableSlot(
          id: _uuid.v4(),
          weekday: weekday,
          period: period,
          subject: subject.trim(),
        ),
      );
    }
    timetable = await _repo.getTimetable();
    notifyListeners();
  }

  String? subjectAt(int weekday, int period) {
    for (final s in timetable) {
      if (s.weekday == weekday && s.period == period) return s.subject;
    }
    return null;
  }

  Future<Map<String, int>> weekStats() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dates = [
      for (var i = 0; i < 7; i++)
        DateFormat('yyyy-MM-dd').format(monday.add(Duration(days: i))),
    ];
    return _repo.weekAttendanceStats(dates);
  }

  Future<String> exportBackupFile() async {
    final data = await _repo.exportBackup();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        dir.path,
        '班主任助手备份_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
      ),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      encoding: utf8,
    );
    return file.path;
  }

  Future<void> importBackupJson(String raw) async {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    await _repo.importBackup(data);
    selectedDate = todayKey;
    await load();
  }
}
