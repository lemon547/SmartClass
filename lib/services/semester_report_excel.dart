import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:smart_class/models/models.dart';

/// 学期统计汇总导出（学生个人 / 全班）
abstract final class SemesterReportExcel {
  static Uint8List buildClassReport({
    required String classTitle,
    required String semesterTitle,
    required List<Student> students,
    required List<AttendanceRecord> attendance,
    required List<PointRecord> pointRecords,
    required List<Exam> exams,
    required Map<String, List<ExamScore>> scoresByExam,
    required List<WorkLog> workLogs,
    required List<FundRecord> fundRecords,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', '班级概况');

    final overview = excel['班级概况'];
    overview.appendRow([TextCellValue('班级'), TextCellValue(classTitle)]);
    overview.appendRow([TextCellValue('学期'), TextCellValue(semesterTitle)]);
    overview.appendRow([
      TextCellValue('导出时间'),
      TextCellValue(DateTime.now().toIso8601String()),
    ]);
    overview.appendRow([TextCellValue('学生人数'), IntCellValue(students.length)]);
    overview.appendRow([
      TextCellValue('考勤记录数'),
      IntCellValue(attendance.length),
    ]);
    overview.appendRow([
      TextCellValue('积分流水数'),
      IntCellValue(pointRecords.length),
    ]);
    overview.appendRow([TextCellValue('考试次数'), IntCellValue(exams.length)]);
    overview.appendRow([
      TextCellValue('工作留痕'),
      IntCellValue(workLogs.length),
    ]);
    final fundBalance = fundRecords.fold<int>(0, (a, b) => a + b.amount);
    overview.appendRow([TextCellValue('班费余额'), IntCellValue(fundBalance)]);

    final roster = excel['学生积分'];
    roster.appendRow([
      TextCellValue('学号'),
      TextCellValue('姓名'),
      TextCellValue('性别'),
      TextCellValue('小组'),
      TextCellValue('班委'),
      TextCellValue('积分'),
      TextCellValue('段位'),
      TextCellValue('电话'),
    ]);
    final ranked = [...students]..sort((a, b) => b.points.compareTo(a.points));
    for (final s in ranked) {
      roster.appendRow([
        TextCellValue(s.studentNo),
        TextCellValue(s.name),
        TextCellValue(s.gender),
        TextCellValue(s.groupName),
        TextCellValue(s.role),
        IntCellValue(s.points),
        TextCellValue(rankTitle(s.points)),
        TextCellValue(s.phone),
      ]);
    }

    final attSheet = excel['考勤汇总'];
    attSheet.appendRow([
      TextCellValue('学号'),
      TextCellValue('姓名'),
      TextCellValue('出勤'),
      TextCellValue('迟到'),
      TextCellValue('请假'),
      TextCellValue('缺勤'),
      TextCellValue('合计天数'),
    ]);
    for (final s in ranked) {
      final mine = attendance.where((a) => a.studentId == s.id);
      var present = 0, late = 0, leave = 0, absent = 0;
      for (final a in mine) {
        switch (a.status) {
          case AttendanceStatus.present:
            present++;
          case AttendanceStatus.late:
            late++;
          case AttendanceStatus.leave:
            leave++;
          case AttendanceStatus.absent:
            absent++;
        }
      }
      attSheet.appendRow([
        TextCellValue(s.studentNo),
        TextCellValue(s.name),
        IntCellValue(present),
        IntCellValue(late),
        IntCellValue(leave),
        IntCellValue(absent),
        IntCellValue(present + late + leave + absent),
      ]);
    }

    final gradeSheet = excel['成绩汇总'];
    gradeSheet.appendRow([
      TextCellValue('考试'),
      TextCellValue('类别'),
      TextCellValue('日期'),
      TextCellValue('学号'),
      TextCellValue('姓名'),
      TextCellValue('总分'),
      TextCellValue('各科明细'),
    ]);
    for (final exam in exams) {
      final scores = scoresByExam[exam.id] ?? const <ExamScore>[];
      for (final sc in scores) {
        Student? stu;
        for (final s in students) {
          if (s.id == sc.studentId) {
            stu = s;
            break;
          }
        }
        final detail = sc.scores.entries
            .map((e) => '${e.key}:${e.value}')
            .join('；');
        gradeSheet.appendRow([
          TextCellValue(exam.title),
          TextCellValue(exam.category),
          TextCellValue(exam.examDate),
          TextCellValue(stu?.studentNo ?? ''),
          TextCellValue(stu?.name ?? sc.studentId),
          DoubleCellValue(sc.total),
          TextCellValue(detail),
        ]);
      }
    }

    final ptsSheet = excel['积分流水'];
    ptsSheet.appendRow([
      TextCellValue('时间'),
      TextCellValue('学号'),
      TextCellValue('姓名'),
      TextCellValue('分值'),
      TextCellValue('原因'),
    ]);
    final byId = {for (final s in students) s.id: s};
    final ptsSorted = [...pointRecords]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final p in ptsSorted) {
      final stu = byId[p.studentId];
      ptsSheet.appendRow([
        TextCellValue(p.createdAt.toIso8601String()),
        TextCellValue(stu?.studentNo ?? ''),
        TextCellValue(stu?.name ?? p.studentId),
        IntCellValue(p.delta),
        TextCellValue(p.reason),
      ]);
    }

    final logSheet = excel['工作留痕'];
    logSheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('类别'),
      TextCellValue('标题'),
      TextCellValue('内容'),
    ]);
    for (final w in workLogs) {
      logSheet.appendRow([
        TextCellValue(w.date),
        TextCellValue(w.category.label),
        TextCellValue(w.title),
        TextCellValue(w.content),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法生成汇总表');
    return Uint8List.fromList(bytes);
  }

  static Uint8List buildStudentReport({
    required String classTitle,
    required String semesterTitle,
    required Student student,
    required List<AttendanceRecord> attendance,
    required List<PointRecord> pointRecords,
    required List<Exam> exams,
    required Map<String, List<ExamScore>> scoresByExam,
    required List<WorkLog> relatedWorkLogs,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', '个人概况');

    final overview = excel['个人概况'];
    overview.appendRow([TextCellValue('班级'), TextCellValue(classTitle)]);
    overview.appendRow([TextCellValue('学期'), TextCellValue(semesterTitle)]);
    overview.appendRow([TextCellValue('姓名'), TextCellValue(student.name)]);
    overview.appendRow([TextCellValue('学号'), TextCellValue(student.studentNo)]);
    overview.appendRow([TextCellValue('性别'), TextCellValue(student.gender)]);
    overview.appendRow([TextCellValue('小组'), TextCellValue(student.groupName)]);
    overview.appendRow([TextCellValue('班委'), TextCellValue(student.role)]);
    overview.appendRow([TextCellValue('电话'), TextCellValue(student.phone)]);
    overview.appendRow([TextCellValue('住址'), TextCellValue(student.address)]);
    overview.appendRow([TextCellValue('生日'), TextCellValue(student.birthday)]);
    overview.appendRow([TextCellValue('积分'), IntCellValue(student.points)]);
    overview.appendRow([
      TextCellValue('段位'),
      TextCellValue(rankTitle(student.points)),
    ]);
    overview.appendRow([TextCellValue('备注'), TextCellValue(student.note)]);

    var present = 0, late = 0, leave = 0, absent = 0;
    for (final a in attendance) {
      switch (a.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.leave:
          leave++;
        case AttendanceStatus.absent:
          absent++;
      }
    }
    overview.appendRow([TextCellValue('出勤次数'), IntCellValue(present)]);
    overview.appendRow([TextCellValue('迟到次数'), IntCellValue(late)]);
    overview.appendRow([TextCellValue('请假次数'), IntCellValue(leave)]);
    overview.appendRow([TextCellValue('缺勤次数'), IntCellValue(absent)]);

    final attSheet = excel['考勤明细'];
    attSheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('状态'),
      TextCellValue('备注'),
    ]);
    final attSorted = [...attendance]..sort((a, b) => b.date.compareTo(a.date));
    for (final a in attSorted) {
      attSheet.appendRow([
        TextCellValue(a.date),
        TextCellValue(a.status.label),
        TextCellValue(a.remark),
      ]);
    }

    final ptsSheet = excel['积分明细'];
    ptsSheet.appendRow([
      TextCellValue('时间'),
      TextCellValue('分值'),
      TextCellValue('原因'),
    ]);
    final ptsSorted = [...pointRecords]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final p in ptsSorted) {
      ptsSheet.appendRow([
        TextCellValue(p.createdAt.toIso8601String()),
        IntCellValue(p.delta),
        TextCellValue(p.reason),
      ]);
    }

    final gradeSheet = excel['成绩'];
    gradeSheet.appendRow([
      TextCellValue('考试'),
      TextCellValue('类别'),
      TextCellValue('日期'),
      TextCellValue('总分'),
      TextCellValue('各科'),
    ]);
    for (final exam in exams) {
      final scores = scoresByExam[exam.id] ?? const <ExamScore>[];
      for (final sc in scores) {
        if (sc.studentId != student.id) continue;
        final detail =
            sc.scores.entries.map((e) => '${e.key}:${e.value}').join('；');
        gradeSheet.appendRow([
          TextCellValue(exam.title),
          TextCellValue(exam.category),
          TextCellValue(exam.examDate),
          DoubleCellValue(sc.total),
          TextCellValue(detail),
        ]);
      }
    }

    final logSheet = excel['相关留痕'];
    logSheet.appendRow([
      TextCellValue('日期'),
      TextCellValue('类别'),
      TextCellValue('标题'),
      TextCellValue('内容'),
    ]);
    for (final w in relatedWorkLogs) {
      logSheet.appendRow([
        TextCellValue(w.date),
        TextCellValue(w.category.label),
        TextCellValue(w.title),
        TextCellValue(w.content),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法生成汇总表');
    return Uint8List.fromList(bytes);
  }
}
