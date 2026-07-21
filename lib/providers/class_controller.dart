import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/batch_excels.dart';
import 'package:smart_class/services/ai_timetable_import.dart';
import 'package:smart_class/services/exam_score_excel.dart';
import 'package:smart_class/services/excel_batch_helper.dart';
import 'package:smart_class/services/semester_report_excel.dart';
import 'package:smart_class/services/student_roster_excel.dart';
import 'package:smart_class/services/work_log_export_pack.dart';
import 'package:uuid/uuid.dart';

class StudentImportResult {
  const StudentImportResult({
    required this.added,
    required this.updated,
    this.warnings = const [],
  });

  final int added;
  final int updated;
  final List<String> warnings;

  int get total => added + updated;
}

class ExamScoreImportResult {
  const ExamScoreImportResult({
    required this.matched,
    required this.skipped,
    this.warnings = const [],
  });

  final int matched;
  final int skipped;
  final List<String> warnings;
}

enum ExamScoreMatchStatus {
  matchedByNo,
  matchedByName,
  ambiguousName,
  unmatched,
}

class ExamScoreMatchPreview {
  const ExamScoreMatchPreview({
    required this.row,
    required this.status,
    this.student,
  });

  final ExamScoreRow row;
  final Student? student;
  final ExamScoreMatchStatus status;

  bool get isMatched =>
      status == ExamScoreMatchStatus.matchedByNo ||
      status == ExamScoreMatchStatus.matchedByName;
}

enum TimetableMatchStatus {
  ok,
  classNotFound,
  noCurrentClass,
}

class TimetableMatchPreview {
  const TimetableMatchPreview({
    required this.row,
    required this.status,
    this.matchedClass,
  });

  final AiTimetableSlotRow row;
  final ManagedClass? matchedClass;
  final TimetableMatchStatus status;

  bool get isOk => status == TimetableMatchStatus.ok && matchedClass != null;
}

class ClassController extends ChangeNotifier {
  ClassController(this._repo);

  final ClassRepository _repo;
  final _uuid = const Uuid();

  ClassProfile profile = const ClassProfile();
  List<ManagedClass> classes = [];
  ManagedClass? currentClass;
  List<Student> students = [];
  List<AttendanceRecord> selectedAttendance = [];
  List<PointRecord> pointRecords = [];
  List<DutyAssignment> dutyList = [];
  List<PointReasonPreset> pointPresets = [];
  List<String> rolePresets = [];
  List<Settlement> settlements = [];
  List<CountdownItem> countdowns = [];
  List<FundRecord> fundRecords = [];
  List<WorkLog> workLogs = [];
  Map<String, List<WorkLogAttachment>> workLogAttachmentsByLog = {};
  List<LeaveRecord> leaveRecords = [];
  List<DisciplineRecord> disciplineRecords = [];
  List<(Student, int)> deductionAlerts = [];
  bool deductionReminderEnabled = true;
  int deductionReminderThreshold = 10;
  List<LessonUnit> lessonUnits = [];
  Map<String, List<LessonFile>> lessonFilesByUnit = {};
  Map<String, List<ExamFile>> examFilesByExam = {};
  List<Exam> exams = [];
  /// examId -> scores
  Map<String, List<ExamScore>> examScoresByExam = {};
  List<String> examCategories = [];
  List<Semester> semesters = [];
  Semester? activeSemester;
  List<Map<String, dynamic>> rollHistory = [];
  List<ClassNote> notes = [];
  List<HomeworkItem> homework = [];
  List<RewardItem> rewards = [];
  List<TimetableSlot> timetable = [];
  List<TimetablePeriod> timetablePeriods = TimetablePeriod.defaults();
  List<String> teachingSubjects = [];
  List<SalaryRecord> salaryRecords = [];
  List<TeacherTodo> todos = [];
  /// 跨班级的今日授课（「我的授课」）
  List<TodayTeachingLesson> allTodayLessons = [];
  /// 当前班今日全部课程（「本班课表」）
  List<TodayTeachingLesson> todayClassLessons = [];
  /// 本周我的授课（教师课表 · 我的）
  List<TodayTeachingLesson> weekMyLessons = [];
  /// 本周当前班全部课程（教师课表 · 班级）
  List<TodayTeachingLesson> weekClassLessons = [];
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool loading = true;
  /// 首屏必需数据已就绪（可离开启动页）
  bool essentialReady = false;
  String? error;

  /// today | week | month | total
  String rankPeriod = 'total';
  Map<String, int> periodDeltas = {};

  String get todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  TeacherRole get teacherRole =>
      currentClass?.teacherRole ?? TeacherRole.homeroom;

  bool get isHomeroom => teacherRole == TeacherRole.homeroom;

  bool isFeatureVisible(String featureId) {
    final cls = currentClass;
    if (cls == null) return true;
    return isFeatureVisibleFor(cls, featureId);
  }

  bool isFeatureVisibleFor(ManagedClass cls, String featureId) {
    return ClassFeatures.isVisible(
      featureId: featureId,
      role: cls.teacherRole,
      overrides: cls.featureFlags,
    );
  }

  int lessonCountForClass(String classId) =>
      lessonUnits.where((u) => u.classId == classId).length;

  int lessonFileCountForClass(String classId) {
    var n = 0;
    for (final u in lessonUnits) {
      if (u.classId != classId) continue;
      n += lessonFilesByUnit[u.id]?.length ?? 0;
    }
    return n;
  }

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

  Map<String, String> get attendanceRemarkMap => {
        for (final r in selectedAttendance)
          if (r.remark.trim().isNotEmpty) r.studentId: r.remark.trim(),
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

  List<Student> get ungroupedStudents =>
      students.where((s) => s.groupName.trim().isEmpty).toList();

  /// 创建或更新小组成员。返回错误文案，成功时返回 null。
  Future<String?> saveGroupMembers({
    String? previousName,
    required String name,
    required List<String> studentIds,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '请填写小组名称';

    final prev = previousName?.trim() ?? '';
    if (prev != trimmed && groupNames.contains(trimmed)) {
      return '小组名称已存在';
    }

    final selected = studentIds.toSet();
    for (final s in students) {
      final inPrev = prev.isNotEmpty && s.groupName == prev;
      final shouldAssign = selected.contains(s.id);
      if (inPrev && !shouldAssign) {
        await _repo.upsertStudent(s.copyWith(groupName: ''));
      } else if (shouldAssign) {
        await _repo.upsertStudent(s.copyWith(groupName: trimmed));
      }
    }
    await load();
    return null;
  }

  Future<void> deleteGroup(String name) async {
    final trimmed = name.trim();
    for (final s in students.where((s) => s.groupName == trimmed)) {
      await _repo.upsertStudent(s.copyWith(groupName: ''));
    }
    await load();
  }

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
    essentialReady = false;
    error = null;
    notifyListeners();
    try {
      await _refreshClasses();
      profile = _repo.loadProfile();
      students = await _repo.getStudents();
      selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
      pointPresets = _repo.loadPointPresets();
      rolePresets = _repo.loadRolePresets();
      countdowns = await _repo.getCountdowns();
      timetable = await _repo.getTimetable();
      await _repo.ensureTimetablePeriods();
      timetablePeriods = await _repo.getTimetablePeriods();
      teachingSubjects = await _repo.getTeachingSubjects();
      dutyList = await _repo.getDuty();
      homework = await _repo.getHomework(date: selectedDate);
      activeSemester = await _repo.ensureActiveSemester();

      // 各模块为空时自动补演示数据（已有数据不覆盖）
      await _repo.seedDemoData();
      students = await _repo.getStudents();
      countdowns = await _repo.getCountdowns();
      timetable = await _repo.getTimetable();
      await _repo.ensureTimetablePeriods();
      timetablePeriods = await _repo.getTimetablePeriods();
      teachingSubjects = await _repo.getTeachingSubjects();
      dutyList = await _repo.getDuty();
      homework = await _repo.getHomework(date: selectedDate);
      selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
      todos = await _repo.getTodos();
      await _refreshScheduleCaches();

      essentialReady = true;
      loading = false;
      notifyListeners();

      await _loadDeferred();
    } catch (e) {
      error = e.toString();
      loading = false;
      essentialReady = true;
      notifyListeners();
    }
  }

  Future<void> _refreshClasses() async {
    classes = await _repo.getClasses();
    final id = _repo.currentClassId;
    currentClass = null;
    for (final c in classes) {
      if (c.id == id) {
        currentClass = c;
        break;
      }
    }
    currentClass ??= classes.isEmpty ? null : classes.first;
  }

  Future<void> switchClass(String id) async {
    if (currentClass?.id == id) return;
    await _repo.setCurrentClassId(id);
    examScoresByExam = {};
    await load();
  }

  /// AI 只读取数：临时切到指定班加载内存数据，结束后恢复，不打扰界面选班。
  Future<T> withClassContext<T>(
    String classId,
    Future<T> Function() action,
  ) async {
    final prev = currentClass?.id;
    if (prev == classId || classId.isEmpty) {
      return action();
    }
    _suppressAiNotify = true;
    try {
      await _repo.setCurrentClassId(classId);
      examScoresByExam = {};
      await load();
      return await action();
    } finally {
      if (prev != null && prev.isNotEmpty) {
        await _repo.setCurrentClassId(prev);
        examScoresByExam = {};
        await load();
      }
      _suppressAiNotify = false;
      notifyListeners();
    }
  }

  bool _suppressAiNotify = false;

  @override
  void notifyListeners() {
    if (_suppressAiNotify) return;
    super.notifyListeners();
  }

  Future<ManagedClass> createManagedClass({
    required String name,
    String school = '',
    String grade = '',
    String groupName = '',
    TeacherRole teacherRole = TeacherRole.homeroom,
    String subject = '',
    int seatRows = 6,
    int seatCols = 8,
    Map<String, bool> featureFlags = const {},
    bool switchTo = true,
  }) async {
    final created = await _repo.createClass(
      name: name,
      school: school,
      grade: grade,
      groupName: groupName,
      teacherRole: teacherRole,
      subject: subject,
      seatRows: seatRows,
      seatCols: seatCols,
      featureFlags: featureFlags,
    );
    if (switchTo) {
      await switchClass(created.id);
    } else {
      await _refreshClasses();
      notifyListeners();
    }
    return created;
  }

  Future<void> updateManagedClass(ManagedClass next) async {
    await _repo.upsertClass(next);
    await _refreshClasses();
    if (currentClass?.id == next.id) {
      profile = next.asProfile;
    }
    notifyListeners();
  }

  Future<void> setFeatureFlag(String featureId, bool visible) async {
    final cls = currentClass;
    if (cls == null) return;
    final flags = Map<String, bool>.from(cls.featureFlags);
    flags[featureId] = visible;
    await updateManagedClass(cls.copyWith(featureFlags: flags));
  }

  Future<void> deleteManagedClass(String id) async {
    await _repo.deleteClass(id);
    examScoresByExam = {};
    await load();
  }

  Future<void> refreshSalary() async {
    salaryRecords = await _repo.getSalaryRecords();
    notifyListeners();
  }

  Future<void> upsertSalary(SalaryRecord record) async {
    await _repo.upsertSalaryRecord(record);
    await refreshSalary();
  }

  Future<void> deleteSalary(String id) async {
    await _repo.deleteSalaryRecord(id);
    await refreshSalary();
  }

  Future<void> _loadDeferred() async {
    try {
      pointRecords = await _repo.getPointRecords(limit: 80);
      settlements = await _repo.getSettlements();
      fundRecords = await _repo.getFundRecords();
      workLogs = await _repo.getWorkLogs();
      await _reloadWorkLogAttachments();
      leaveRecords = await _repo.getLeaveRecords();
      disciplineRecords = await _repo.getDisciplineRecords();
      deductionReminderEnabled = _repo.deductionReminderEnabled;
      deductionReminderThreshold = _repo.deductionReminderThreshold;
      deductionAlerts = await _repo.studentsOverDeductionThreshold();
      lessonUnits = await _repo.getAllLessonUnits();
      await _repo.seedDemoLessonsIfEmpty();
      lessonUnits = await _repo.getAllLessonUnits();
      final allLessonFiles = await _repo.getAllLessonFiles();
      lessonFilesByUnit = {};
      for (final f in allLessonFiles) {
        lessonFilesByUnit.putIfAbsent(f.unitId, () => []).add(f);
      }
      exams = await _repo.getExams();
      examCategories = _repo.loadExamCategories();
      examScoresByExam = {}; // 成绩明细按需加载
      final allExamFiles = await _repo.getExamFiles();
      examFilesByExam = {};
      for (final f in allExamFiles) {
        examFilesByExam.putIfAbsent(f.examId, () => []).add(f);
      }
      semesters = await _repo.getSemesters();
      activeSemester = null;
      for (final s in semesters) {
        if (s.isActive) {
          activeSemester = s;
          break;
        }
      }
      activeSemester ??= await _repo.ensureActiveSemester();
      rollHistory = _repo.loadRollHistory();
      notes = await _repo.getNotes();
      rewards = await _repo.getRewards();
      salaryRecords = await _repo.getSalaryRecords();
      await _refreshPeriodDeltas();
      notifyListeners();
    } catch (_) {
      // 延迟加载失败不阻断主流程
    }
  }

  /// 打开某次考试时再拉成绩，避免启动时全量查询
  Future<void> ensureExamScores(String examId) async {
    if (examScoresByExam.containsKey(examId)) return;
    examScoresByExam[examId] = await _repo.getExamScores(examId);
    notifyListeners();
  }

  Future<void> ensureAllExamScores() async {
    var changed = false;
    for (final e in exams) {
      if (!examScoresByExam.containsKey(e.id)) {
        examScoresByExam[e.id] = await _repo.getExamScores(e.id);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> _refreshSemesters() async {
    semesters = await _repo.getSemesters();
    activeSemester = null;
    for (final s in semesters) {
      if (s.isActive) {
        activeSemester = s;
        break;
      }
    }
  }

  Future<void> renameActiveSemester(String title) async {
    final active = activeSemester ?? await _repo.ensureActiveSemester();
    await _repo.renameSemester(active.id, title);
    await _refreshSemesters();
    notifyListeners();
  }

  /// 结束本学期并存档，开启新学期（保留花名册，清空积分/考勤/成绩等）
  Future<Semester> archiveSemesterAndStartNew({
    String archiveTitle = '',
    String newTitle = '',
    String note = '',
  }) async {
    final next = await _repo.archiveAndStartNew(
      archiveTitle: archiveTitle,
      newTitle: newTitle,
      note: note,
    );
    await load();
    return next;
  }

  Future<void> deleteArchivedSemester(String id) async {
    final s = await _repo.getSemester(id);
    if (s == null || s.isActive) return;
    await _repo.deleteSemester(id);
    await _refreshSemesters();
    notifyListeners();
  }

  Semester? semesterById(String id) {
    for (final s in semesters) {
      if (s.id == id) return s;
    }
    return null;
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
    await _refreshClasses();
    notifyListeners();
  }

  Future<void> seedDemo() async {
    await _repo.seedDemoData();
    await load();
  }

  Future<void> saveStudent({
    String? id,
    required String name,
    String studentNo = '',
    String gender = '',
    String phone = '',
    String note = '',
    String groupName = '',
    String role = '',
    String birthday = '',
    String address = '',
  }) async {
    final existing = id == null ? null : studentById(id);
    final genderNorm = gender.trim() == '未知' ? '' : gender.trim();
    final student = Student(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      studentNo: studentNo.trim(),
      gender: genderNorm,
      phone: phone.trim(),
      note: note.trim(),
      groupName: groupName.trim(),
      role: Student.joinRoles(Student.splitRoles(role)),
      birthday: birthday.trim(),
      address: address.trim(),
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

  Future<void> addRolePreset(String role) async {
    final t = role.trim();
    if (t.isEmpty) return;
    if (rolePresets.contains(t)) return;
    rolePresets = [...rolePresets, t];
    await _repo.saveRolePresets(rolePresets);
    notifyListeners();
  }

  /// 导出学生档案示例 Excel（WPS / Excel 可打开）。
  Future<String> exportStudentTemplateFile() async {
    final bytes = StudentRosterExcel.buildTemplateBytes();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '学生档案导入示例.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 从 Excel / CSV 导入学生档案。有学号则更新同号学生，否则新增。
  Future<StudentImportResult> importStudentsFromBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final parsed = StudentRosterExcel.parseBytes(bytes, fileName: fileName);
    return importStudentRosterRows(
      parsed.rows,
      extraWarnings: parsed.warnings,
    );
  }

  /// 将已解析的学生行写入当前班级（学号匹配则更新）。
  Future<StudentImportResult> importStudentRosterRows(
    List<StudentRosterRow> rows, {
    List<String> extraWarnings = const [],
  }) async {
    if (rows.isEmpty) {
      return StudentImportResult(
        added: 0,
        updated: 0,
        warnings: extraWarnings.isEmpty
            ? const ['没有可导入的数据']
            : extraWarnings,
      );
    }

    var added = 0;
    var updated = 0;
    final byNo = <String, Student>{
      for (final s in students)
        if (s.studentNo.trim().isNotEmpty) s.studentNo.trim(): s,
    };

    for (final row in rows) {
      final name = row.name.trim();
      if (name.isEmpty) continue;
      final no = row.studentNo.trim();
      final existing = no.isNotEmpty ? byNo[no] : null;
      if (existing != null) {
        await _repo.upsertStudent(
          existing.copyWith(
            name: name,
            studentNo: no,
            gender: row.gender,
            phone: row.phone,
            note: row.note,
            groupName: row.groupName,
            role: row.role,
            birthday: row.birthday,
            address: row.address,
          ),
        );
        updated++;
      } else {
        final student = Student(
          id: _uuid.v4(),
          name: name,
          studentNo: no,
          gender: row.gender,
          phone: row.phone,
          note: row.note,
          groupName: row.groupName,
          role: row.role,
          birthday: row.birthday,
          address: row.address,
          createdAt: DateTime.now(),
        );
        await _repo.upsertStudent(student);
        if (no.isNotEmpty) byNo[no] = student;
        added++;
      }
    }

    await load();
    return StudentImportResult(
      added: added,
      updated: updated,
      warnings: extraWarnings,
    );
  }

  Student? _matchStudent({String studentNo = '', String name = ''}) {
    final no = studentNo.trim();
    if (no.isNotEmpty) {
      for (final s in students) {
        if (s.studentNo.trim() == no) return s;
      }
    }
    final n = name.trim();
    if (n.isNotEmpty) {
      Student? hit;
      for (final s in students) {
        if (s.name.trim() == n) {
          if (hit != null) return null; // 重名不匹配
          hit = s;
        }
      }
      return hit;
    }
    return null;
  }

  Future<String> _writeExcelTemplate(String fileName, Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> exportAttendanceFile() async {
    final date = selectedDate;
    final classTitle = currentClass?.displayTitle ?? profile.displayTitle;
    final remarks = <String, String>{
      for (final r in selectedAttendance)
        if (r.remark.trim().isNotEmpty) r.studentId: r.remark.trim(),
    };
    final bytes = AttendanceBatchExcel.export(
      classTitle: classTitle,
      date: date,
      students: students,
      statusByStudent: attendanceMap,
      remarkByStudent: remarks,
    );
    final safeDate = date.replaceAll('-', '');
    final fileName = '考勤_${classTitle}_$safeDate.xlsx'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return _writeExcelTemplate(fileName, bytes);
  }

  Future<String> exportDutyTemplateFile() =>
      _writeExcelTemplate('值日导入示例.xlsx', DutyBatchExcel.template());

  Future<BatchImportResult> importDutyFromBytes(Uint8List bytes) async {
    final parsed = DutyBatchExcel.parse(bytes);
    var imported = 0;
    var skipped = 0;
    final warnings = [...parsed.warnings];
    for (final row in parsed.rows) {
      final s = _matchStudent(studentNo: row.studentNo, name: row.name);
      if (s == null) {
        skipped++;
        warnings.add('未找到学生：${row.studentNo} ${row.name}');
        continue;
      }
      await _repo.setDuty(
        weekday: row.weekday,
        studentId: s.id,
        task: row.task,
      );
      imported++;
    }
    dutyList = await _repo.getDuty();
    notifyListeners();
    return BatchImportResult(
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<String> exportFundTemplateFile() =>
      _writeExcelTemplate('班费导入示例.xlsx', FundBatchExcel.template());

  Future<BatchImportResult> importFundFromBytes(Uint8List bytes) async {
    final parsed = FundBatchExcel.parse(bytes);
    var imported = 0;
    for (final row in parsed.rows) {
      await _repo.upsertFundRecord(
        FundRecord(
          id: _uuid.v4(),
          title: row.title,
          amount: row.amount,
          date: row.date,
          note: row.note,
          createdAt: DateTime.now(),
        ),
      );
      imported++;
    }
    fundRecords = await _repo.getFundRecords();
    notifyListeners();
    return BatchImportResult(imported: imported, warnings: parsed.warnings);
  }

  Future<String> exportRewardTemplateFile() =>
      _writeExcelTemplate('奖品导入示例.xlsx', RewardBatchExcel.template());

  Future<BatchImportResult> importRewardFromBytes(Uint8List bytes) async {
    final parsed = RewardBatchExcel.parse(bytes);
    var imported = 0;
    for (final row in parsed.rows) {
      await _repo.upsertReward(
        RewardItem(
          id: _uuid.v4(),
          name: row.name,
          cost: row.cost,
          stock: row.stock,
        ),
      );
      imported++;
    }
    rewards = await _repo.getRewards();
    notifyListeners();
    return BatchImportResult(imported: imported, warnings: parsed.warnings);
  }

  Future<String> exportWorkLogTemplateFile() =>
      _writeExcelTemplate('工作留痕导入示例.xlsx', WorkLogBatchExcel.template());

  Future<BatchImportResult> importWorkLogFromBytes(Uint8List bytes) async {
    final parsed = WorkLogBatchExcel.parse(bytes);
    var imported = 0;
    final now = DateTime.now();
    for (final row in parsed.rows) {
      await _repo.upsertWorkLog(
        WorkLog(
          id: _uuid.v4(),
          category: row.category,
          title: row.title,
          content: row.content,
          date: row.date,
          createdAt: now,
          updatedAt: now,
        ),
      );
      imported++;
    }
    workLogs = await _repo.getWorkLogs();
    await _reloadWorkLogAttachments();
    notifyListeners();
    return BatchImportResult(imported: imported, warnings: parsed.warnings);
  }

  Future<String> exportLessonTemplateFile() =>
      _writeExcelTemplate('授课进度导入示例.xlsx', LessonBatchExcel.template());

  Future<BatchImportResult> importLessonFromBytes(Uint8List bytes) async {
    final parsed = LessonBatchExcel.parse(bytes);
    var imported = 0;
    final now = DateTime.now();
    var order = lessonUnits.length;
    for (final row in parsed.rows) {
      await _repo.upsertLessonUnit(
        LessonUnit(
          id: _uuid.v4(),
          subject: row.subject,
          title: row.title,
          chapter: row.chapter,
          progressNote: row.note,
          status: row.status,
          plannedDate: row.plannedDate,
          taughtDate: row.taughtDate,
          sortOrder: order++,
          createdAt: now,
          updatedAt: now,
        ),
      );
      imported++;
    }
    await _refreshLessons();
    notifyListeners();
    return BatchImportResult(imported: imported, warnings: parsed.warnings);
  }

  Future<String> exportCountdownTemplateFile() =>
      _writeExcelTemplate('倒数日导入示例.xlsx', CountdownBatchExcel.template());

  Future<BatchImportResult> importCountdownFromBytes(Uint8List bytes) async {
    final parsed = CountdownBatchExcel.parse(bytes);
    var imported = 0;
    for (final row in parsed.rows) {
      await _repo.upsertCountdown(
        CountdownItem(
          id: _uuid.v4(),
          title: row.title,
          targetDate: row.targetDate,
          createdAt: DateTime.now(),
        ),
      );
      imported++;
    }
    countdowns = await _repo.getCountdowns();
    notifyListeners();
    return BatchImportResult(imported: imported, warnings: parsed.warnings);
  }

  Future<String> exportSalaryTemplateFile() =>
      _writeExcelTemplate('工资导入示例.xlsx', SalaryBatchExcel.template());

  Future<BatchImportResult> importSalaryFromBytes(Uint8List bytes) async {
    final parsed = SalaryBatchExcel.parse(bytes);
    var imported = 0;
    for (final row in parsed.rows) {
      final net = SalaryRecord.computeNet(
        base: row.base,
        allowance: row.allowance,
        deduction: row.deduction,
      );
      await _repo.upsertSalaryRecord(
        SalaryRecord(
          id: _uuid.v4(),
          yearMonth: row.yearMonth,
          title: row.title,
          baseAmount: row.base,
          allowance: row.allowance,
          deduction: row.deduction,
          netAmount: net,
          note: row.note,
          createdAt: DateTime.now(),
        ),
      );
      imported++;
    }
    await refreshSalary();
    return BatchImportResult(imported: imported, warnings: parsed.warnings);
  }

  Future<String> exportPointTemplateFile() =>
      _writeExcelTemplate('积分导入示例.xlsx', PointBatchExcel.template());

  Future<BatchImportResult> importPointsFromBytes(Uint8List bytes) async {
    final parsed = PointBatchExcel.parse(bytes);
    var imported = 0;
    var skipped = 0;
    final warnings = [...parsed.warnings];
    for (final row in parsed.rows) {
      final s = _matchStudent(studentNo: row.studentNo, name: row.name);
      if (s == null) {
        skipped++;
        warnings.add('未找到学生：${row.studentNo} ${row.name}');
        continue;
      }
      await _repo.addPoints(
        studentId: s.id,
        delta: row.delta,
        reason: row.reason,
      );
      imported++;
    }
    await load();
    return BatchImportResult(
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  Future<String> exportTeacherTimetableTemplateFile() =>
      _writeExcelTemplate('教师课表导入示例.xlsx', TeacherTimetableExcel.template());

  Future<BatchImportResult> importTeacherTimetableFromBytes(
    Uint8List bytes,
  ) async {
    final parsed = TeacherTimetableExcel.parse(bytes);
    return importAiTimetableRows(
      parsed.rows
          .map(
            (r) => AiTimetableSlotRow(
              weekday: r.weekday,
              period: r.period,
              subject: r.subject,
              className: r.className,
            ),
          )
          .toList(),
      markAsMine: true,
      extraWarnings: parsed.warnings,
    );
  }

  /// AI / 标准模板共用的课表行写入。
  /// [markAsMine] true：跨班写入并标记本人授课；false：写入当前班级格子。
  Future<BatchImportResult> importAiTimetableRows(
    List<AiTimetableSlotRow> rows, {
    bool markAsMine = false,
    String? fallbackClassId,
    List<String> extraWarnings = const [],
  }) async {
    if (rows.isEmpty) {
      return BatchImportResult(
        imported: 0,
        skipped: 0,
        warnings: extraWarnings.isEmpty
            ? const ['没有可导入的数据']
            : extraWarnings,
      );
    }

    var imported = 0;
    var skipped = 0;
    final warnings = [...extraWarnings];
    final currentId = fallbackClassId ?? currentClass?.id;

    for (final row in rows) {
      final sub = row.subject.trim();
      if (sub.isEmpty) {
        skipped++;
        continue;
      }
      if (row.weekday < 1 ||
          row.weekday > 7 ||
          row.period < 1 ||
          row.period > 20) {
        skipped++;
        warnings.add('无效节次：周${row.weekday} 第${row.period}节');
        continue;
      }

      String? classId;
      if (row.className.trim().isNotEmpty) {
        final cls = matchClassByName(row.className);
        if (cls == null) {
          skipped++;
          warnings.add('未找到班级：${row.className}');
          continue;
        }
        classId = cls.id;
      } else {
        classId = currentId;
      }
      if (classId == null) {
        skipped++;
        warnings.add('未指定班级，且当前未选班级');
        continue;
      }

      if (markAsMine) {
        await addMyTeachingLesson(
          classId: classId,
          weekday: row.weekday,
          period: row.period,
          subject: sub,
        );
      } else {
        await _repo.upsertTimetableSlotForClass(
          classId,
          TimetableSlot(
            id: _uuid.v4(),
            weekday: row.weekday,
            period: row.period,
            subject: sub,
          ),
        );
      }
      imported++;
    }

    if (currentClass != null) {
      timetable = await _repo.getTimetable();
      teachingSubjects = await _repo.getTeachingSubjects();
    }
    await _refreshScheduleCaches();
    notifyListeners();

    return BatchImportResult(
      imported: imported,
      skipped: skipped,
      warnings: warnings,
    );
  }

  List<TimetableMatchPreview> previewTimetableRows(
    List<AiTimetableSlotRow> rows, {
    String? fallbackClassId,
  }) {
    final currentId = fallbackClassId ?? currentClass?.id;
    ManagedClass? classById(String? id) {
      if (id == null) return null;
      for (final c in classes) {
        if (c.id == id) return c;
      }
      return null;
    }

    final out = <TimetableMatchPreview>[];
    for (final row in rows) {
      ManagedClass? cls;
      var status = TimetableMatchStatus.ok;
      if (row.className.trim().isNotEmpty) {
        cls = matchClassByName(row.className);
        if (cls == null) status = TimetableMatchStatus.classNotFound;
      } else {
        cls = classById(currentId);
        if (cls == null) status = TimetableMatchStatus.noCurrentClass;
      }
      out.add(
        TimetableMatchPreview(row: row, matchedClass: cls, status: status),
      );
    }
    return out;
  }

  ManagedClass? matchClassByName(String raw) {
    final q = raw.trim().replaceAll(' ', '').replaceAll('·', '');
    if (q.isEmpty) return null;
    for (final c in classes) {
      final title = c.displayTitle.replaceAll(' ', '').replaceAll('·', '');
      final name = c.name.trim().replaceAll(' ', '');
      if (title == q || name == q || title.contains(q) || q.contains(name)) {
        return c;
      }
    }
    return null;
  }

  Future<void> removeStudent(String id) async {
    await _repo.deleteStudent(id);
    await load();
  }

  Future<void> markAttendance(
    String studentId,
    AttendanceStatus status, {
    String? remark,
  }) async {
    var nextRemark = remark;
    if (nextRemark == null) {
      for (final r in selectedAttendance) {
        if (r.studentId == studentId) {
          nextRemark = r.remark;
          break;
        }
      }
    }
    await _repo.setAttendance(
      studentId: studentId,
      date: selectedDate,
      status: status,
      remark: (nextRemark ?? '').trim(),
    );
    selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
    notifyListeners();
  }

  Future<void> setAttendanceRemark(String studentId, String remark) async {
    final status = attendanceMap[studentId] ?? AttendanceStatus.present;
    await markAttendance(studentId, status, remark: remark.trim());
  }

  Future<void> markAllPresent() async {
    final keep = {
      for (final r in selectedAttendance) r.studentId: r.remark,
    };
    for (final s in students) {
      await _repo.setAttendance(
        studentId: s.id,
        date: selectedDate,
        status: AttendanceStatus.present,
        remark: keep[s.id] ?? '',
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

  Future<void> upsertPointPreset({
    String? previousReason,
    required PointReasonPreset preset,
  }) async {
    final next = [...pointPresets];
    if (previousReason != null) {
      next.removeWhere((p) => p.reason == previousReason);
    } else {
      next.removeWhere((p) => p.reason == preset.reason);
    }
    next.add(preset);
    next.sort((a, b) {
      if (a.delta >= 0 && b.delta < 0) return -1;
      if (a.delta < 0 && b.delta >= 0) return 1;
      return a.reason.compareTo(b.reason);
    });
    await savePointPresets(next);
  }

  Future<void> deletePointPreset(String reason) async {
    await savePointPresets([
      for (final p in pointPresets)
        if (p.reason != reason) p,
    ]);
  }

  Future<void> resetPointPresets() async {
    await _repo.clearPointPresets();
    pointPresets = _repo.loadPointPresets();
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
    final upcoming = upcomingCountdowns;
    return upcoming.isEmpty ? null : upcoming.first;
  }

  /// 未过期的倒数日，按剩余天数升序
  List<CountdownItem> get upcomingCountdowns {
    final list = countdowns.where((c) => c.daysLeft >= 0).toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return list;
  }

  Future<void> saveCountdown({
    String? id,
    required String title,
    required String targetDate,
  }) async {
    DateTime createdAt = DateTime.now();
    if (id != null) {
      for (final c in countdowns) {
        if (c.id == id) {
          createdAt = c.createdAt;
          break;
        }
      }
    }
    await _repo.upsertCountdown(
      CountdownItem(
        id: id ?? _uuid.v4(),
        title: title.trim(),
        targetDate: targetDate,
        createdAt: createdAt,
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

  int get fundBalance =>
      fundRecords.fold(0, (sum, e) => sum + e.amount);

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

  /// 导出当前班本学期汇总 Excel（概况 / 学生 / 考勤 / 成绩 / 积分 / 留痕）
  Future<String> exportClassSemesterReportFile() async {
    await ensureAllExamScores();
    final attendance = await _repo.getAllAttendance();
    final points = await _repo.getPointRecords(limit: 20000);
    final bytes = SemesterReportExcel.buildClassReport(
      classTitle: profile.displayTitle,
      semesterTitle: activeSemester?.title ?? '当前学期',
      students: students,
      attendance: attendance,
      pointRecords: points,
      exams: exams,
      scoresByExam: examScoresByExam,
      workLogs: workLogs,
      fundRecords: fundRecords,
    );
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safeName = profile.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return _writeExcelTemplate('班级学期汇总_${safeName}_$stamp.xlsx', bytes);
  }

  /// 导出某学生本学期个人汇总 Excel
  Future<String> exportStudentSemesterReportFile(String studentId) async {
    final s = studentById(studentId);
    if (s == null) throw StateError('学生不存在');
    await ensureAllExamScores();
    final attendance = await _repo.getAttendanceByStudent(studentId);
    final points = await _repo.getPointRecordsByStudent(studentId);
    final related = workLogs.where((w) {
      return w.studentIdList.contains(studentId) ||
          w.title.contains(s.name) ||
          w.content.contains(s.name);
    }).toList();
    final bytes = SemesterReportExcel.buildStudentReport(
      classTitle: profile.displayTitle,
      semesterTitle: activeSemester?.title ?? '当前学期',
      student: s,
      attendance: attendance,
      pointRecords: points,
      exams: exams,
      scoresByExam: examScoresByExam,
      relatedWorkLogs: related,
    );
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final safe = s.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return _writeExcelTemplate('学生学期汇总_${safe}_$stamp.xlsx', bytes);
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

  List<WorkLog> workLogsOf(WorkLogCategory? category) {
    if (category == null) return workLogs;
    return workLogs.where((e) => e.category == category).toList();
  }

  int workLogCount(WorkLogCategory category) =>
      workLogs.where((e) => e.category == category).length;

  List<LessonFile> filesOfLesson(String unitId) =>
      lessonFilesByUnit[unitId] ?? const [];

  Future<void> _refreshLessons() async {
    lessonUnits = await _repo.getAllLessonUnits();
    final all = await _repo.getAllLessonFiles();
    lessonFilesByUnit = {};
    for (final f in all) {
      lessonFilesByUnit.putIfAbsent(f.unitId, () => []).add(f);
    }
  }

  String? classIdOfLesson(String unitId) {
    for (final u in lessonUnits) {
      if (u.id == unitId) {
        return u.classId.isNotEmpty ? u.classId : currentClass?.id;
      }
    }
    return currentClass?.id;
  }

  String classTitleOf(String classId) {
    for (final c in classes) {
      if (c.id == classId) return c.displayTitle;
    }
    return '未知班级';
  }

  Future<void> saveLessonUnit(LessonUnit unit, {String? classId}) async {
    await _repo.upsertLessonUnit(unit, classId: classId);
    await _refreshLessons();
    notifyListeners();
  }

  Future<void> deleteLessonUnit(String id) async {
    await _repo.deleteLessonUnit(id);
    await _refreshLessons();
    notifyListeners();
  }

  Future<LessonFile?> attachLessonFile({
    required String unitId,
    required String sourcePath,
    required String originalName,
    String? classId,
  }) async {
    final file = await _repo.importLessonFile(
      unitId: unitId,
      sourcePath: sourcePath,
      originalName: originalName,
      classId: classId ?? classIdOfLesson(unitId),
    );
    await _refreshLessons();
    notifyListeners();
    return file;
  }

  Future<void> deleteLessonFile(LessonFile file) async {
    await _repo.deleteLessonFile(
      file,
      classId: classIdOfLesson(file.unitId),
    );
    await _refreshLessons();
    notifyListeners();
  }

  Future<String> lessonFilePath(LessonFile file, {String? classId}) =>
      _repo.lessonFileAbsolutePath(
        file,
        classId: classId ?? classIdOfLesson(file.unitId),
      );

  Future<void> _reloadWorkLogAttachments() async {
    final all = await _repo.getAllWorkLogAttachments();
    workLogAttachmentsByLog = {};
    for (final a in all) {
      workLogAttachmentsByLog.putIfAbsent(a.workLogId, () => []).add(a);
    }
  }

  List<WorkLogAttachment> attachmentsOfWorkLog(String workLogId) =>
      workLogAttachmentsByLog[workLogId] ?? const [];

  Future<void> saveWorkLog({
    String? id,
    required WorkLogCategory category,
    required String title,
    required String content,
    required String date,
    List<String> studentIds = const [],
  }) async {
    DateTime createdAt = DateTime.now();
    if (id != null) {
      for (final w in workLogs) {
        if (w.id == id) {
          createdAt = w.createdAt;
          break;
        }
      }
    }
    await _repo.upsertWorkLog(
      WorkLog(
        id: id ?? _uuid.v4(),
        category: category,
        title: title.trim(),
        content: content.trim(),
        date: date,
        studentIds: studentIds.join(','),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    workLogs = await _repo.getWorkLogs();
    await _reloadWorkLogAttachments();
    notifyListeners();
  }

  Future<WorkLogAttachment?> attachWorkLogMedia({
    required String workLogId,
    required WorkLogMediaKind kind,
    required String sourcePath,
    required String originalName,
  }) async {
    final item = await _repo.importWorkLogAttachment(
      workLogId: workLogId,
      kind: kind,
      sourcePath: sourcePath,
      originalName: originalName,
    );
    await _reloadWorkLogAttachments();
    notifyListeners();
    return item;
  }

  Future<void> deleteWorkLogAttachment(WorkLogAttachment item) async {
    await _repo.deleteWorkLogAttachment(item);
    await _reloadWorkLogAttachments();
    notifyListeners();
  }

  Future<String> workLogAttachmentPath(WorkLogAttachment item) =>
      _repo.workLogAttachmentAbsolutePath(item);

  Future<void> deleteWorkLog(String id) async {
    await _repo.deleteWorkLog(id);
    workLogs = await _repo.getWorkLogs();
    await _reloadWorkLogAttachments();
    notifyListeners();
  }

  int get todayLeaveCount {
    final now = DateTime.now();
    return leaveRecords.where((e) {
      if (!e.isActive) return false;
      return !now.isBefore(e.startAt) && !now.isAfter(e.endAt);
    }).length;
  }

  int get activeLeaveCount =>
      leaveRecords.where((e) => e.isActive).length;

  int get overdueLeaveCount =>
      leaveRecords.where((e) => e.isOverdue).length;

  List<LeaveRecord> get overdueLeaves =>
      leaveRecords.where((e) => e.isOverdue).toList();

  int get todayDisciplineCount {
    final d = todayKey;
    return disciplineRecords.where((e) => e.date == d).length;
  }

  int get todayPointsDelta {
    final d = todayKey;
    var sum = 0;
    for (final r in pointRecords) {
      final key = DateFormat('yyyy-MM-dd').format(r.createdAt);
      if (key == d) sum += r.delta;
    }
    return sum;
  }

  int talkLogCountFor(String studentId) {
    var n = 0;
    for (final w in workLogs) {
      if (w.category != WorkLogCategory.studentTalk) continue;
      if (w.studentIdList.contains(studentId)) n++;
    }
    return n;
  }

  Future<void> refreshDailyOps() async {
    leaveRecords = await _repo.getLeaveRecords();
    disciplineRecords = await _repo.getDisciplineRecords();
    deductionReminderEnabled = _repo.deductionReminderEnabled;
    deductionReminderThreshold = _repo.deductionReminderThreshold;
    deductionAlerts = await _repo.studentsOverDeductionThreshold();
    pointRecords = await _repo.getPointRecords(limit: 100);
    notifyListeners();
  }

  Future<void> setDeductionReminder({
    bool? enabled,
    int? threshold,
  }) async {
    if (enabled != null) {
      await _repo.setDeductionReminderEnabled(enabled);
      deductionReminderEnabled = enabled;
    }
    if (threshold != null) {
      final t = threshold.clamp(1, 999);
      await _repo.setDeductionReminderThreshold(t);
      deductionReminderThreshold = t;
    }
    try {
      deductionAlerts = await _repo.studentsOverDeductionThreshold();
    } catch (_) {
      deductionAlerts = [];
    }
    notifyListeners();
  }

  Future<void> saveLeaveRecord({
    required String studentId,
    required String date,
    String reason = '',
    String pickup = '',
    DateTime? startAt,
    DateTime? endAt,
    String? id,
    String proofStoredName = '',
    String proofOriginalName = '',
    LeaveStatus status = LeaveStatus.active,
    DateTime? returnedAt,
  }) async {
    final start = startAt ?? DateTime.parse('${date}T00:00:00');
    final end = endAt ?? DateTime.parse('${date}T23:59:59');
    final leaveId = id ?? _uuid.v4();
    await _repo.upsertLeaveRecord(
      LeaveRecord(
        id: leaveId,
        studentId: studentId,
        date: date,
        reason: reason.trim(),
        pickup: pickup.trim(),
        createdAt: DateTime.now(),
        startAt: start,
        endAt: end,
        status: status,
        returnedAt: returnedAt,
        proofStoredName: proofStoredName,
        proofOriginalName: proofOriginalName,
      ),
    );
    await _repo.setAttendance(
      studentId: studentId,
      date: date,
      status: AttendanceStatus.leave,
      remark: reason.trim(),
    );
    if (selectedDate == date) {
      selectedAttendance = await _repo.getAttendanceByDate(selectedDate);
    }
    await refreshDailyOps();
  }

  Future<void> returnLeave(String leaveId) async {
    LeaveRecord? found;
    for (final e in leaveRecords) {
      if (e.id == leaveId) {
        found = e;
        break;
      }
    }
    if (found == null) return;
    await _repo.upsertLeaveRecord(
      found.copyWith(
        status: LeaveStatus.returned,
        returnedAt: DateTime.now(),
      ),
    );
    await refreshDailyOps();
  }

  Future<void> deleteLeave(String leaveId) async {
    await _repo.deleteLeaveRecord(leaveId);
    await refreshDailyOps();
  }

  Future<({String storedName, String originalName})> importLeaveProof({
    required String leaveId,
    required String sourcePath,
    required String originalName,
  }) async {
    final r = await _repo.importLeaveProof(
      leaveId: leaveId,
      sourcePath: sourcePath,
      originalName: originalName,
    );
    return (storedName: r.storedName, originalName: r.originalName);
  }

  Future<String> leaveProofPath(LeaveRecord item) =>
      _repo.leaveProofAbsolutePath(item);

  // ── Student honors ────────────────────────────────────────────────────────

  Future<List<StudentHonor>> honorsOf(String studentId) =>
      _repo.getStudentHonors(studentId: studentId);

  Future<void> saveStudentHonor(StudentHonor honor) async {
    await _repo.upsertStudentHonor(honor);
    notifyListeners();
  }

  Future<void> deleteStudentHonor(String id) async {
    await _repo.deleteStudentHonor(id);
    notifyListeners();
  }

  // ── Title materials ───────────────────────────────────────────────────────

  List<TitleMaterial> titleMaterials = [];

  Future<void> refreshTitleMaterials() async {
    titleMaterials = await _repo.getTitleMaterials();
    notifyListeners();
  }

  Future<TitleMaterial> importTitleMaterial({
    required int year,
    required String category,
    required String title,
    required String sourcePath,
    required String originalName,
  }) async {
    final item = await _repo.importTitleMaterial(
      year: year,
      category: category,
      title: title,
      sourcePath: sourcePath,
      originalName: originalName,
    );
    await refreshTitleMaterials();
    return item;
  }

  Future<void> updateTitleMaterial(TitleMaterial item) async {
    await _repo.upsertTitleMaterial(item);
    await refreshTitleMaterials();
  }

  Future<void> deleteTitleMaterial(String id) async {
    await _repo.deleteTitleMaterial(id);
    await refreshTitleMaterials();
  }

  Future<String> titleMaterialPath(TitleMaterial item) =>
      _repo.titleMaterialAbsolutePath(item);

  Future<void> applySmartSeats(Map<String, (int, int)> seats) async {
    await _repo.applySeatMap(seats);
    students = await _repo.getStudents();
    notifyListeners();
  }

  Future<void> swapStudentSeats(String aId, String bId) async {
    await _repo.swapSeats(aId, bId);
    students = await _repo.getStudents();
    notifyListeners();
  }

  Future<void> saveDisciplineRecord({
    required String studentId,
    required String date,
    required String title,
    String action = '',
    int pointsDelta = 0,
  }) async {
    final t = title.trim();
    if (t.isEmpty) return;
    await _repo.upsertDisciplineRecord(
      DisciplineRecord(
        id: _uuid.v4(),
        studentId: studentId,
        date: date,
        title: t,
        action: action.trim(),
        pointsDelta: pointsDelta,
        createdAt: DateTime.now(),
      ),
    );
    if (pointsDelta != 0) {
      await _repo.addPoints(
        studentId: studentId,
        delta: pointsDelta,
        reason: t,
      );
      students = await _repo.getStudents();
      await _refreshPeriodDeltas();
    }
    await refreshDailyOps();
  }

  /// 导出工作留痕纯 Excel（不含附件列）。
  Future<String> exportWorkLogsExcelFile() async {
    final bytes = WorkLogBatchExcel.exportRows(workLogs);
    final title = currentClass?.displayTitle ?? '班级';
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '工作留痕_${safe}_$stamp.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 导出工作留痕 ZIP：纯 Excel + 附件原文件（按记录分子文件夹）。
  Future<String> exportWorkLogsReportFile() async {
    final bytes = await WorkLogExportPack.buildZip(
      logs: workLogs,
      attachmentsByLog: workLogAttachmentsByLog,
      absolutePathOf: _repo.workLogAttachmentAbsolutePath,
    );
    final title = currentClass?.displayTitle ?? '班级';
    final safe = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '工作留痕_${safe}_$stamp.zip'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  List<Exam> examsOf(String? category) {
    if (category == null || category.isEmpty) return exams;
    return exams.where((e) => e.category == category).toList();
  }

  List<ExamScore> scoresOfExam(String examId) =>
      examScoresByExam[examId] ?? const [];

  Exam? examById(String id) {
    for (final e in exams) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> addExamCategory(String category) async {
    final t = category.trim();
    if (t.isEmpty) return;
    if (examCategories.contains(t)) return;
    examCategories = [...examCategories, t];
    await _repo.saveExamCategories(examCategories);
    notifyListeners();
  }

  /// 保存考试元数据，返回考试 id（新建引导录入用）
  Future<String> saveExam({
    String? id,
    required String title,
    required String category,
    required String examDate,
    required List<String> subjects,
    double fullScore = 100,
    double passScore = 60,
    String note = '',
  }) async {
    final now = DateTime.now();
    DateTime createdAt = now;
    if (id != null) {
      final old = examById(id);
      if (old != null) createdAt = old.createdAt;
    }
    final cat = category.trim().isEmpty ? '月考' : category.trim();
    await addExamCategory(cat);
    final exam = Exam(
      id: id ?? _uuid.v4(),
      title: title.trim(),
      category: cat,
      examDate: examDate,
      subjects: [
        for (final s in subjects)
          if (s.trim().isNotEmpty) s.trim(),
      ],
      fullScore: fullScore,
      passScore: passScore,
      note: note.trim(),
      createdAt: createdAt,
      updatedAt: now,
    );
    await _repo.upsertExam(exam);
    exams = await _repo.getExams();
    examScoresByExam.putIfAbsent(exam.id, () => const []);
    notifyListeners();
    return exam.id;
  }

  Future<void> deleteExam(String id) async {
    await _repo.deleteExam(id);
    exams = await _repo.getExams();
    examScoresByExam.remove(id);
    examFilesByExam.remove(id);
    notifyListeners();
  }

  List<ExamFile> filesOfExam(String examId) =>
      examFilesByExam[examId] ?? const [];

  Future<void> _refreshExamFiles([String? examId]) async {
    if (examId != null) {
      examFilesByExam[examId] = await _repo.getExamFiles(examId: examId);
    } else {
      final all = await _repo.getExamFiles();
      examFilesByExam = {};
      for (final f in all) {
        examFilesByExam.putIfAbsent(f.examId, () => []).add(f);
      }
    }
  }

  Future<void> attachExamFile({
    required String examId,
    required String sourcePath,
    required String originalName,
  }) async {
    await _repo.importExamFile(
      examId: examId,
      sourcePath: sourcePath,
      originalName: originalName,
    );
    await _refreshExamFiles(examId);
    notifyListeners();
  }

  Future<void> deleteExamFile(ExamFile file) async {
    await _repo.deleteExamFile(file);
    await _refreshExamFiles(file.examId);
    notifyListeners();
  }

  Future<String> examFilePath(ExamFile file) =>
      _repo.examFileAbsolutePath(file);

  Future<void> saveExamScore({
    required String examId,
    required String studentId,
    required Map<String, double> scores,
    String remark = '',
    String? id,
    int? convertedRank,
    int? gradeRank,
    Map<String, int>? subjectRanks,
    bool mergeRanksFromExisting = true,
  }) async {
    ExamScore? existing;
    for (final s in scoresOfExam(examId)) {
      if (s.studentId == studentId || (id != null && s.id == id)) {
        existing = s;
        break;
      }
    }
    final existingId = id ?? existing?.id;
    await _repo.upsertExamScore(
      ExamScore(
        id: existingId ?? _uuid.v4(),
        examId: examId,
        studentId: studentId,
        scores: scores,
        remark: remark.trim(),
        convertedRank: convertedRank ??
            (mergeRanksFromExisting ? existing?.convertedRank : null),
        gradeRank: gradeRank ??
            (mergeRanksFromExisting ? existing?.gradeRank : null),
        subjectRanks: subjectRanks ??
            (mergeRanksFromExisting
                ? (existing?.subjectRanks ?? const {})
                : const {}),
      ),
    );
    examScoresByExam[examId] = await _repo.getExamScores(examId);
    notifyListeners();
  }

  /// dense rank：同分同名次，下一档名次连续（例：1,1,2）
  static Map<String, int> denseRanksByValue(
    Iterable<(String id, double value)> items,
  ) {
    final sorted = [...items]..sort((a, b) => b.$2.compareTo(a.$2));
    final out = <String, int>{};
    var rank = 0;
    double? prev;
    var distinct = 0;
    for (final (id, value) in sorted) {
      if (prev == null || value != prev) {
        distinct++;
        rank = distinct;
        prev = value;
      }
      out[id] = rank;
    }
    return out;
  }

  /// 班内总分排名 studentId -> rank
  Map<String, int> classRankByTotal(String examId) {
    final items = <(String, double)>[
      for (final s in scoresOfExam(examId))
        if (s.scores.isNotEmpty) (s.studentId, s.total),
    ];
    return denseRanksByValue(items);
  }

  /// 班内单科排名
  Map<String, int> classRankBySubject(String examId, String subject) {
    final list = <(String, double)>[];
    for (final s in scoresOfExam(examId)) {
      final v = s.scoreOf(subject);
      if (v != null) list.add((s.studentId, v));
    }
    return denseRanksByValue(list);
  }

  Future<String> exportExamFilledFile(String examId) async {
    final exam = examById(examId);
    if (exam == null) throw StateError('考试不存在');
    final classTitle = currentClass?.displayTitle ?? profile.displayTitle;
    final ranks = classRankByTotal(examId);
    final bytes = ExamScoreExcel.buildFilledBytes(
      exam: exam,
      classTitle: classTitle,
      students: students,
      scores: scoresOfExam(examId),
      classRanksByStudentId: ranks,
    );
    final dir = await getApplicationDocumentsDirectory();
    final safeClass = classTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final safeTitle = exam.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(dir.path, '${safeClass}_$safeTitle.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> deleteExamScore({
    required String examId,
    required String scoreId,
  }) async {
    await _repo.deleteExamScore(scoreId);
    examScoresByExam[examId] = await _repo.getExamScores(examId);
    notifyListeners();
  }

  /// 某学生已加载成绩中的历次考试（需先 ensureExamScores / ensureAllExamScores）
  List<(Exam, ExamScore)> examScoresOfStudent(String studentId) {
    final out = <(Exam, ExamScore)>[];
    for (final e in exams) {
      for (final s in scoresOfExam(e.id)) {
        if (s.studentId == studentId) {
          out.add((e, s));
          break;
        }
      }
    }
    return out;
  }

  Future<String> exportExamTemplateFile(String examId) async {
    final exam = examById(examId);
    if (exam == null) throw StateError('考试不存在');
    final bytes = ExamScoreExcel.buildTemplateBytes(
      exam: exam,
      students: students,
    );
    final dir = await getApplicationDocumentsDirectory();
    final safe = exam.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File(p.join(dir.path, '成绩模板_$safe.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<ExamScoreImportResult> importExamScoresFromBytes(
    String examId,
    Uint8List bytes, {
    String? fileName,
  }) async {
    final exam = examById(examId);
    if (exam == null) {
      return const ExamScoreImportResult(
        matched: 0,
        skipped: 0,
        warnings: ['考试不存在'],
      );
    }
    final parsed = ExamScoreExcel.parseBytes(
      bytes,
      subjects: exam.subjects,
      fileName: fileName,
    );
    return importExamScoreRows(
      examId,
      parsed.rows,
      extraWarnings: parsed.warnings,
    );
  }

  /// 将已解析的成绩行写入考试（学号优先，其次唯一姓名）。
  Future<ExamScoreImportResult> importExamScoreRows(
    String examId,
    List<ExamScoreRow> rows, {
    List<String> extraWarnings = const [],
  }) async {
    final exam = examById(examId);
    if (exam == null) {
      return const ExamScoreImportResult(
        matched: 0,
        skipped: 0,
        warnings: ['考试不存在'],
      );
    }
    if (rows.isEmpty) {
      return ExamScoreImportResult(
        matched: 0,
        skipped: 0,
        warnings: extraWarnings.isEmpty
            ? const ['没有可导入的数据']
            : extraWarnings,
      );
    }

    final byNo = <String, Student>{
      for (final s in students)
        if (s.studentNo.trim().isNotEmpty) s.studentNo.trim(): s,
    };
    final byName = <String, List<Student>>{};
    for (final s in students) {
      byName.putIfAbsent(s.name, () => []).add(s);
    }

    var matched = 0;
    var skipped = 0;
    final warnings = [...extraWarnings];
    final existingByStudent = <String, String>{
      for (final s in scoresOfExam(examId)) s.studentId: s.id,
    };

    for (final row in rows) {
      Student? stu;
      final no = row.studentNo.trim();
      if (no.isNotEmpty) stu = byNo[no];
      if (stu == null) {
        final list = byName[row.name] ?? const [];
        if (list.length == 1) {
          stu = list.first;
        } else if (list.length > 1) {
          warnings.add('${row.name} 重名，请填写学号');
          skipped++;
          continue;
        }
      }
      if (stu == null) {
        warnings.add('未匹配：${row.name}${no.isEmpty ? '' : '($no)'}');
        skipped++;
        continue;
      }

      final scores = <String, double>{};
      for (final sub in exam.subjects) {
        final v = row.scores[sub];
        if (v != null) scores[sub] = v;
      }
      if (scores.isEmpty) {
        // 表里科目名与考试不完全一致时，仍写入；并扩科目列表
        scores.addAll(row.scores);
      }
      final id = existingByStudent[stu.id] ?? _uuid.v4();
      ExamScore? prev;
      for (final s in scoresOfExam(examId)) {
        if (s.id == id) {
          prev = s;
          break;
        }
      }
      final mergedSubjectRanks = <String, int>{
        ...?prev?.subjectRanks,
        ...row.subjectRanks,
      };
      final writeScores =
          scores.isNotEmpty ? scores : (prev?.scores ?? <String, double>{});
      if (writeScores.isEmpty &&
          row.convertedRank == null &&
          row.gradeRank == null &&
          mergedSubjectRanks.isEmpty) {
        skipped++;
        continue;
      }
      await _repo.upsertExamScore(
        ExamScore(
          id: id,
          examId: examId,
          studentId: stu.id,
          scores: writeScores,
          remark: row.remark.isNotEmpty ? row.remark : (prev?.remark ?? ''),
          convertedRank: row.convertedRank ?? prev?.convertedRank,
          gradeRank: row.gradeRank ?? prev?.gradeRank,
          subjectRanks: mergedSubjectRanks,
        ),
      );
      existingByStudent[stu.id] = id;
      matched++;
    }

    // 若导入带出了新科目，合并进考试
    final mergedSubjects = [...exam.subjects];
    for (final row in rows) {
      for (final s in row.scores.keys) {
        if (!mergedSubjects.contains(s)) mergedSubjects.add(s);
      }
    }
    if (mergedSubjects.length != exam.subjects.length) {
      await saveExam(
        id: exam.id,
        title: exam.title,
        category: exam.category,
        examDate: exam.examDate,
        subjects: mergedSubjects,
        fullScore: exam.fullScore,
        passScore: exam.passScore,
        note: exam.note,
      );
    }

    examScoresByExam[examId] = await _repo.getExamScores(examId);
    notifyListeners();

    return ExamScoreImportResult(
      matched: matched,
      skipped: skipped,
      warnings: warnings,
    );
  }

  /// 预览匹配结果（不写库）。
  List<ExamScoreMatchPreview> previewExamScoreRows(List<ExamScoreRow> rows) {
    final byNo = <String, Student>{
      for (final s in students)
        if (s.studentNo.trim().isNotEmpty) s.studentNo.trim(): s,
    };
    final byName = <String, List<Student>>{};
    for (final s in students) {
      byName.putIfAbsent(s.name, () => []).add(s);
    }

    final out = <ExamScoreMatchPreview>[];
    for (final row in rows) {
      Student? stu;
      var status = ExamScoreMatchStatus.unmatched;
      final no = row.studentNo.trim();
      if (no.isNotEmpty) stu = byNo[no];
      if (stu != null) {
        status = ExamScoreMatchStatus.matchedByNo;
      } else {
        final list = byName[row.name] ?? const [];
        if (list.length == 1) {
          stu = list.first;
          status = ExamScoreMatchStatus.matchedByName;
        } else if (list.length > 1) {
          status = ExamScoreMatchStatus.ambiguousName;
        }
      }
      out.add(ExamScoreMatchPreview(row: row, student: stu, status: status));
    }
    return out;
  }

  /// 单科或总分分析
  List<SubjectStat> analyzeExam(String examId) {
    final exam = examById(examId);
    if (exam == null) return const [];
    final list = scoresOfExam(examId);
    final stats = <SubjectStat>[];

    SubjectStat build(String label, List<double> values, double passLine) {
      if (values.isEmpty) {
        return SubjectStat(
          label: label,
          count: 0,
          average: 0,
          median: 0,
          max: 0,
          min: 0,
          passCount: 0,
          passScore: passLine,
        );
      }
      final sum = values.fold(0.0, (a, b) => a + b);
      var max = values.first;
      var min = values.first;
      var pass = 0;
      for (final v in values) {
        if (v > max) max = v;
        if (v < min) min = v;
        if (v >= passLine) pass++;
      }
      final sorted = [...values]..sort();
      final mid = sorted.length ~/ 2;
      final median = sorted.length.isEven
          ? (sorted[mid - 1] + sorted[mid]) / 2
          : sorted[mid];
      return SubjectStat(
        label: label,
        count: values.length,
        average: sum / values.length,
        median: median,
        max: max,
        min: min,
        passCount: pass,
        passScore: passLine,
      );
    }

    for (final sub in exam.subjects) {
      final values = <double>[];
      for (final s in list) {
        final v = s.scoreOf(sub);
        if (v != null) values.add(v);
      }
      stats.add(build(sub, values, exam.passScore));
    }

    final totals = <double>[];
    for (final s in list) {
      if (s.scores.isEmpty) continue;
      totals.add(s.total);
    }
    final totalPass = exam.passScore * exam.subjects.length;
    stats.add(build('总分', totals, totalPass));
    return stats;
  }

  List<ExamScore> rankedScores(String examId) {
    final list = [
      for (final s in scoresOfExam(examId))
        if (s.scores.isNotEmpty) s,
    ];
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// 按单科分数排序（高到低）
  List<ExamScore> rankedScoresBySubject(String examId, String subject) {
    final list = [
      for (final s in scoresOfExam(examId))
        if (s.scoreOf(subject) != null) s,
    ];
    list.sort(
      (a, b) => b.scoreOf(subject)!.compareTo(a.scoreOf(subject)!),
    );
    return list;
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
    String? subject,
  }) async {
    final sub = subject?.trim() ?? '';
    if (sub.isEmpty) {
      await _repo.clearTimetableSlot(weekday, period);
    } else {
      await _repo.upsertTimetableSlot(
        TimetableSlot(
          id: _uuid.v4(),
          weekday: weekday,
          period: period,
          subject: sub,
        ),
      );
    }
    timetable = await _repo.getTimetable();
    await _refreshScheduleCaches();
    notifyListeners();
  }

  /// 向指定班级写入一节课，并标记为本人授课科目
  Future<void> addMyTeachingLesson({
    required String classId,
    required int weekday,
    required int period,
    required String subject,
  }) async {
    final sub = subject.trim();
    if (sub.isEmpty) return;
    await _repo.upsertTimetableSlotForClass(
      classId,
      TimetableSlot(
        id: _uuid.v4(),
        weekday: weekday,
        period: period,
        subject: sub,
      ),
    );
    await _repo.setTeachingSubjectsForClass(classId, [sub]);
    if (classId == currentClass?.id) {
      timetable = await _repo.getTimetable();
      teachingSubjects = await _repo.getTeachingSubjects();
    }
    await _refreshScheduleCaches();
    notifyListeners();
  }

  Future<void> clearMyTeachingLesson({
    required String classId,
    required int weekday,
    required int period,
  }) async {
    await _repo.clearTimetableSlotForClass(classId, weekday, period);
    if (classId == currentClass?.id) {
      timetable = await _repo.getTimetable();
    }
    await _refreshScheduleCaches();
    notifyListeners();
  }

  Future<void> saveTimetablePeriod(TimetablePeriod period) async {
    await _repo.upsertTimetablePeriod(period);
    timetablePeriods = await _repo.getTimetablePeriods();
    notifyListeners();
  }

  Future<void> addTimetablePeriod() async {
    await _repo.addTimetablePeriod();
    timetablePeriods = await _repo.getTimetablePeriods();
    notifyListeners();
  }

  Future<void> deleteLastTimetablePeriod() async {
    await _repo.deleteLastTimetablePeriod();
    timetablePeriods = await _repo.getTimetablePeriods();
    timetable = await _repo.getTimetable();
    notifyListeners();
  }

  String? get teachingSubject =>
      teachingSubjects.isEmpty ? null : teachingSubjects.first;

  Future<void> setTeachingSubject(String subject) async {
    final t = subject.trim();
    if (t.isEmpty || t == teachingSubject) return;
    await _repo.setTeachingSubjects([t]);
    teachingSubjects = await _repo.getTeachingSubjects();
    await _refreshScheduleCaches();
    notifyListeners();
  }

  Future<void> clearTeachingSubject() async {
    if (teachingSubject == null) return;
    await _repo.setTeachingSubjects(const []);
    teachingSubjects = await _repo.getTeachingSubjects();
    await _refreshScheduleCaches();
    notifyListeners();
  }

  bool isMyTeachingSubject(String? subject) {
    final s = subject?.trim() ?? '';
    final mine = teachingSubject;
    if (s.isEmpty || mine == null) return false;
    return s == mine;
  }

  TimetablePeriod? periodAt(int period) {
    for (final p in timetablePeriods) {
      if (p.period == period) return p;
    }
    return null;
  }

  String? subjectAt(int weekday, int period) {
    for (final s in timetable) {
      if (s.weekday == weekday && s.period == period) return s.subject;
    }
    return null;
  }

  /// 老师今日授课（「我的授课」）；优先跨班汇总
  List<TodayTeachingLesson> get todayTeachingLessons {
    if (allTodayLessons.isNotEmpty) return allTodayLessons;
    return _localDayLessons(mineOnly: true);
  }

  /// 当前班今日全部课程（「本班课表」）
  List<TodayTeachingLesson> get todayClassSchedule {
    if (todayClassLessons.isNotEmpty) return todayClassLessons;
    return _localDayLessons(mineOnly: false);
  }

  List<TodayTeachingLesson> _localDayLessons({required bool mineOnly}) {
    final w = DateTime.now().weekday;
    final slots = timetable.where((s) => s.weekday == w).toList()
      ..sort((a, b) => a.period.compareTo(b.period));
    final title = currentClass?.displayTitle ?? profile.displayTitle;
    final classId = currentClass?.id ?? '';
    final out = <TodayTeachingLesson>[];
    for (final s in slots) {
      final sub = s.subject.trim();
      if (sub.isEmpty) continue;
      if (mineOnly && !isMyTeachingSubject(sub)) continue;
      final p = periodAt(s.period);
      out.add(
        TodayTeachingLesson(
          subject: sub,
          periodLabel: p?.displayLabel ?? '第${s.period}节',
          timeRange: p?.timeRange ?? '',
          startTime: p?.startTime ?? '',
          endTime: p?.endTime ?? '',
          classTitle: title,
          classId: classId,
          weekday: w,
          period: s.period,
        ),
      );
    }
    return out;
  }

  Future<void> refreshTodos() async {
    todos = await _repo.getTodos();
    notifyListeners();
  }

  /// 今日页：今天创建的 + 尚未完成的（往日未完成延续到今日）
  List<TeacherTodo> get todayTodos {
    return [
      for (final t in todos)
        if (t.isCreatedToday || !t.done) t,
    ];
  }

  Future<void> addTodo(String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    await _repo.upsertTodo(
      TeacherTodo(
        id: _uuid.v4(),
        title: t,
        sortOrder: todos.length,
        createdAt: DateTime.now(),
      ),
    );
    await refreshTodos();
  }

  /// 批量新增待办：空标题跳过；与未完成同名则跳过。返回实际新增/跳过数。
  Future<({int added, int skipped})> addTodos(List<String> titles) async {
    final openTitles = {
      for (final t in todos)
        if (!t.done) t.title.trim(),
    };
    final seen = <String>{};
    var added = 0;
    var skipped = 0;
    var order = todos.length;

    for (final raw in titles) {
      final t = raw.trim();
      if (t.isEmpty) {
        skipped++;
        continue;
      }
      if (seen.contains(t) || openTitles.contains(t)) {
        skipped++;
        continue;
      }
      seen.add(t);
      openTitles.add(t);
      await _repo.upsertTodo(
        TeacherTodo(
          id: _uuid.v4(),
          title: t,
          sortOrder: order++,
          createdAt: DateTime.now(),
        ),
      );
      added++;
    }
    if (added > 0) await refreshTodos();
    return (added: added, skipped: skipped);
  }

  /// 合并 AI 提议的加减分规则：同 reason 覆盖。返回新增/更新数。
  Future<({int added, int updated, int skipped})> mergePointPresets(
    List<PointReasonPreset> incoming,
  ) async {
    final byReason = <String, PointReasonPreset>{
      for (final p in pointPresets) p.reason: p,
    };
    var added = 0;
    var updated = 0;
    var skipped = 0;

    for (final raw in incoming) {
      final reason = raw.reason.trim();
      if (reason.isEmpty || raw.delta == 0) {
        skipped++;
        continue;
      }
      final next = PointReasonPreset(reason: reason, delta: raw.delta);
      if (byReason.containsKey(reason)) {
        updated++;
      } else {
        added++;
      }
      byReason[reason] = next;
    }

    final list = byReason.values.toList()
      ..sort((a, b) {
        if (a.delta >= 0 && b.delta < 0) return -1;
        if (a.delta < 0 && b.delta >= 0) return 1;
        return a.reason.compareTo(b.reason);
      });
    if (added > 0 || updated > 0) {
      await savePointPresets(list);
    }
    return (added: added, updated: updated, skipped: skipped);
  }

  Future<void> toggleTodo(String id) async {
    TeacherTodo? found;
    for (final t in todos) {
      if (t.id == id) {
        found = t;
        break;
      }
    }
    if (found == null) return;
    await _repo.upsertTodo(found.copyWith(done: !found.done));
    await refreshTodos();
  }

  Future<void> deleteTodo(String id) async {
    await _repo.deleteTodo(id);
    await refreshTodos();
  }

  Future<void> _refreshScheduleCaches() async {
    final today = DateTime.now().weekday;
    final classId = currentClass?.id;
    allTodayLessons = await _repo.collectTeachingLessons(
      mineOnly: true,
      weekday: today,
    );
    todayClassLessons = classId == null
        ? <TodayTeachingLesson>[]
        : await _repo.collectTeachingLessons(
            mineOnly: false,
            weekday: today,
            classId: classId,
          );
    weekMyLessons = await _repo.collectTeachingLessons(mineOnly: true);
    weekClassLessons = classId == null
        ? <TodayTeachingLesson>[]
        : await _repo.collectTeachingLessons(
            mineOnly: false,
            classId: classId,
          );
  }

  Future<void> refreshAllTodayLessons() async {
    await _refreshScheduleCaches();
    notifyListeners();
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
