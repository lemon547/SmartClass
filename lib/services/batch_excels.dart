import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/excel_batch_helper.dart';

// ── 考勤 ───────────────────────────────────────────────────────────────────

abstract final class AttendanceBatchExcel {
  static const sheet = '考勤';
  static const headers = ['日期', '学号', '姓名', '状态', '备注'];

  /// 导出当日考勤（当前班级学生 + 登记状态）
  static Uint8List export({
    required String classTitle,
    required String date,
    required List<Student> students,
    required Map<String, AttendanceStatus> statusByStudent,
    Map<String, String> remarkByStudent = const {},
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', sheet);
    final sh = excel[sheet];
    sh.appendRow([TextCellValue('班级'), TextCellValue(classTitle)]);
    sh.appendRow([TextCellValue('日期'), TextCellValue(date)]);
    sh.appendRow([]);
    sh.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final s in students) {
      final status = statusByStudent[s.id] ?? AttendanceStatus.present;
      sh.appendRow([
        TextCellValue(date),
        TextCellValue(s.studentNo),
        TextCellValue(s.name),
        TextCellValue(status.label),
        TextCellValue(remarkByStudent[s.id] ?? ''),
      ]);
    }
    for (var i = 0; i < headers.length; i++) {
      sh.setColumnWidth(i, 14);
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法生成考勤表');
    return Uint8List.fromList(bytes);
  }
}

// ── 值日 ───────────────────────────────────────────────────────────────────

class DutyExcelRow {
  const DutyExcelRow({
    required this.weekday,
    this.studentNo = '',
    this.name = '',
    this.task = '值日',
  });
  final int weekday;
  final String studentNo;
  final String name;
  final String task;
}

abstract final class DutyBatchExcel {
  static const sheet = '值日';
  static const headers = ['星期', '学号', '姓名', '任务'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['一', '20250101', '张三', '扫地'],
          ['一', '20250102', '李四', '擦黑板'],
          ['二', '', '王五', '示例，可删除'],
        ],
        tips: [
          ('星期', '一～日'),
          ('学号', '优先匹配'),
          ('姓名', '无学号时按姓名'),
          ('任务', '如扫地、擦黑板；默认为「值日」'),
        ],
      );

  static ({List<DutyExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '星期': '星期',
      '学号': '学号',
      '姓名': '姓名',
      '任务': '任务',
      '事项': '任务',
    });
    final out = <DutyExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final wd = ExcelBatchHelper.parseWeekday(
        ExcelBatchHelper.at(row, cols, '星期'),
      );
      final no = ExcelBatchHelper.at(row, cols, '学号');
      final name = ExcelBatchHelper.at(row, cols, '姓名');
      final task = ExcelBatchHelper.at(row, cols, '任务');
      if (wd == null && no.isEmpty && name.isEmpty) continue;
      if (ExcelBatchHelper.isSampleMarker(task)) continue;
      if (wd == null) {
        warnings.add('第 ${r + 1} 行星期无效');
        continue;
      }
      if (no.isEmpty && name.isEmpty) {
        warnings.add('第 ${r + 1} 行缺学号/姓名');
        continue;
      }
      out.add(DutyExcelRow(
        weekday: wd,
        studentNo: no,
        name: name,
        task: task.isEmpty ? '值日' : task,
      ));
    }
    return (rows: out, warnings: warnings);
  }
}

// ── 班费 ───────────────────────────────────────────────────────────────────

class FundExcelRow {
  const FundExcelRow({
    required this.title,
    required this.amount,
    required this.date,
    this.note = '',
  });
  final String title;
  final int amount;
  final String date;
  final String note;
}

abstract final class FundBatchExcel {
  static const sheet = '班费';
  static const headers = ['标题', '金额', '日期', '备注'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['班费收取', '50', '2026-07-01', '每人'],
          ['买纸巾', '-30', '2026-07-05', '示例，可删除'],
        ],
        tips: [
          ('标题', '必填'),
          ('金额', '正数=收入，负数=支出，整数'),
          ('日期', 'yyyy-MM-dd'),
          ('备注', '选填'),
        ],
      );

  static ({List<FundExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '标题': '标题',
      '项目': '标题',
      '金额': '金额',
      '日期': '日期',
      '备注': '备注',
    });
    final out = <FundExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final title = ExcelBatchHelper.at(row, cols, '标题');
      final amountRaw = ExcelBatchHelper.at(row, cols, '金额');
      final date = ExcelBatchHelper.at(row, cols, '日期');
      final note = ExcelBatchHelper.at(row, cols, '备注');
      if (title.isEmpty && amountRaw.isEmpty) continue;
      if (ExcelBatchHelper.isSampleMarker(note)) continue;
      final amount = int.tryParse(amountRaw.replaceAll(',', ''));
      if (title.isEmpty || amount == null || date.isEmpty) {
        warnings.add('第 ${r + 1} 行不完整，已跳过');
        continue;
      }
      out.add(FundExcelRow(title: title, amount: amount, date: date, note: note));
    }
    return (rows: out, warnings: warnings);
  }
}

// ── 积分兑换奖品 ───────────────────────────────────────────────────────────

class RewardExcelRow {
  const RewardExcelRow({
    required this.name,
    required this.cost,
    this.stock = 99,
  });
  final String name;
  final int cost;
  final int stock;
}

abstract final class RewardBatchExcel {
  static const sheet = '奖品';
  static const headers = ['名称', '所需积分', '库存'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['铅笔', '5', '50'],
          ['免作业券', '30', '10'],
          ['示例奖品', '1', '1'],
        ],
        tips: [
          ('名称', '必填'),
          ('所需积分', '正整数'),
          ('库存', '默认 99'),
        ],
      );

  static ({List<RewardExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '名称': '名称',
      '奖品': '名称',
      '所需积分': '所需积分',
      '积分': '所需积分',
      '库存': '库存',
    });
    final out = <RewardExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final name = ExcelBatchHelper.at(row, cols, '名称');
      final cost = int.tryParse(ExcelBatchHelper.at(row, cols, '所需积分'));
      final stock =
          int.tryParse(ExcelBatchHelper.at(row, cols, '库存')) ?? 99;
      if (name.isEmpty) continue;
      if (name.contains('示例')) continue;
      if (cost == null || cost < 0) {
        warnings.add('第 ${r + 1} 行积分无效');
        continue;
      }
      out.add(RewardExcelRow(name: name, cost: cost, stock: stock));
    }
    return (rows: out, warnings: warnings);
  }
}

// ── 工作留痕 ───────────────────────────────────────────────────────────────

class WorkLogExcelRow {
  const WorkLogExcelRow({
    required this.category,
    required this.title,
    this.content = '',
    required this.date,
  });
  final WorkLogCategory category;
  final String title;
  final String content;
  final String date;
}

abstract final class WorkLogBatchExcel {
  static const sheet = '工作留痕';
  static const headers = ['类别', '标题', '内容', '日期'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['主题班会', '诚信教育', '要点……', '2026-07-10'],
          ['家访', '张三家访', '示例，可删除', '2026-07-12'],
        ],
        tips: [
          ('类别', '安全教育 / 主题班会 / 学生谈话 / 心理关注 / 家长沟通 / 家访'),
          ('标题', '必填'),
          ('内容', '选填'),
          ('日期', 'yyyy-MM-dd'),
        ],
      );

  /// 导出纯表格：仅类别 / 标题 / 内容 / 日期。
  static Uint8List exportRows(List<WorkLog> logs) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', sheet);
    final sh = excel[sheet];
    sh.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final w in logs) {
      sh.appendRow([
        TextCellValue(w.category.label),
        TextCellValue(w.title),
        TextCellValue(w.content),
        TextCellValue(w.date),
      ]);
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法导出工作留痕');
    return Uint8List.fromList(bytes);
  }

  static ({List<WorkLogExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '类别': '类别',
      '分类': '类别',
      '标题': '标题',
      '内容': '内容',
      '日期': '日期',
    });
    final out = <WorkLogExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final catRaw = ExcelBatchHelper.at(row, cols, '类别');
      final title = ExcelBatchHelper.at(row, cols, '标题');
      final content = ExcelBatchHelper.at(row, cols, '内容');
      final date = ExcelBatchHelper.at(row, cols, '日期');
      if (title.isEmpty && catRaw.isEmpty) continue;
      if (ExcelBatchHelper.isSampleMarker(content)) continue;
      final cat = _category(catRaw);
      if (cat == null || title.isEmpty || date.isEmpty) {
        warnings.add('第 ${r + 1} 行不完整或类别无效');
        continue;
      }
      out.add(WorkLogExcelRow(
        category: cat,
        title: title,
        content: content,
        date: date,
      ));
    }
    return (rows: out, warnings: warnings);
  }

  static WorkLogCategory? _category(String raw) {
    final t = raw.trim();
    for (final c in WorkLogCategory.values) {
      if (c.label == t || c.name == t) return c;
    }
    return null;
  }
}

// ── 授课进度 ───────────────────────────────────────────────────────────────

class LessonExcelRow {
  const LessonExcelRow({
    this.subject = '',
    required this.title,
    this.chapter = '',
    this.status = LessonStatus.planned,
    this.plannedDate = '',
    this.taughtDate = '',
    this.note = '',
  });
  final String subject;
  final String title;
  final String chapter;
  final LessonStatus status;
  final String plannedDate;
  final String taughtDate;
  final String note;
}

abstract final class LessonBatchExcel {
  static const sheet = '授课进度';
  static const headers = ['科目', '课题', '章节', '状态', '计划日期', '授课日期', '备注'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['语文', '荷塘月色', '第三单元', '已讲完', '2026-07-01', '2026-07-02', ''],
          ['数学', '函数复习', '', '进行中', '2026-07-08', '', '示例，可删除'],
        ],
        tips: [
          ('科目', '选填'),
          ('课题', '必填'),
          ('章节', '选填'),
          ('状态', '未讲 / 进行中 / 已讲完'),
          ('计划日期', 'yyyy-MM-dd'),
          ('授课日期', 'yyyy-MM-dd'),
          ('备注', '选填'),
        ],
      );

  static ({List<LessonExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '科目': '科目',
      '课题': '课题',
      '标题': '课题',
      '章节': '章节',
      '状态': '状态',
      '计划日期': '计划日期',
      '授课日期': '授课日期',
      '备注': '备注',
    });
    final out = <LessonExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final title = ExcelBatchHelper.at(row, cols, '课题');
      final note = ExcelBatchHelper.at(row, cols, '备注');
      if (title.isEmpty) continue;
      if (ExcelBatchHelper.isSampleMarker(note)) continue;
      out.add(LessonExcelRow(
        subject: ExcelBatchHelper.at(row, cols, '科目'),
        title: title,
        chapter: ExcelBatchHelper.at(row, cols, '章节'),
        status: _status(ExcelBatchHelper.at(row, cols, '状态')),
        plannedDate: ExcelBatchHelper.at(row, cols, '计划日期'),
        taughtDate: ExcelBatchHelper.at(row, cols, '授课日期'),
        note: note,
      ));
    }
    return (rows: out, warnings: warnings);
  }

  static LessonStatus _status(String raw) {
    final t = raw.trim();
    if (t.contains('已') || t == 'done') return LessonStatus.done;
    if (t.contains('进行') || t == 'teaching') return LessonStatus.teaching;
    return LessonStatus.planned;
  }
}

// ── 倒数日 ─────────────────────────────────────────────────────────────────

class CountdownExcelRow {
  const CountdownExcelRow({required this.title, required this.targetDate});
  final String title;
  final String targetDate;
}

abstract final class CountdownBatchExcel {
  static const sheet = '倒数日';
  static const headers = ['标题', '目标日期'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['期末考试', '2026-07-20'],
          ['暑假放假', '2026-07-15'],
        ],
        tips: [
          ('标题', '必填'),
          ('目标日期', 'yyyy-MM-dd'),
        ],
      );

  static ({List<CountdownExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '标题': '标题',
      '名称': '标题',
      '目标日期': '目标日期',
      '日期': '目标日期',
    });
    final out = <CountdownExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final title = ExcelBatchHelper.at(row, cols, '标题');
      final date = ExcelBatchHelper.at(row, cols, '目标日期');
      if (title.isEmpty) continue;
      if (date.isEmpty) {
        warnings.add('第 ${r + 1} 行缺日期');
        continue;
      }
      out.add(CountdownExcelRow(title: title, targetDate: date));
    }
    return (rows: out, warnings: warnings);
  }
}

// ── 工资 ───────────────────────────────────────────────────────────────────

class SalaryExcelRow {
  const SalaryExcelRow({
    required this.yearMonth,
    this.title = '月工资',
    this.base = 0,
    this.allowance = 0,
    this.deduction = 0,
    this.note = '',
  });
  final String yearMonth;
  final String title;
  final double base;
  final double allowance;
  final double deduction;
  final String note;
}

abstract final class SalaryBatchExcel {
  static const sheet = '工资';
  static const headers = ['月份', '标题', '基本工资', '补贴', '扣款', '备注'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['2026-07', '月工资', '8000', '500', '200', ''],
          ['2026-06', '月工资', '8000', '0', '0', '示例，可删除'],
        ],
        tips: [
          ('月份', 'yyyy-MM'),
          ('标题', '选填，默认「月工资」'),
          ('基本工资', '数字'),
          ('补贴', '数字'),
          ('扣款', '数字；实发=基本+补贴-扣款'),
          ('备注', '选填'),
        ],
      );

  static ({List<SalaryExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '月份': '月份',
      '年月': '月份',
      '标题': '标题',
      '基本工资': '基本工资',
      '基本': '基本工资',
      '补贴': '补贴',
      '津贴': '补贴',
      '扣款': '扣款',
      '备注': '备注',
    });
    final out = <SalaryExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final ym = ExcelBatchHelper.at(row, cols, '月份');
      final note = ExcelBatchHelper.at(row, cols, '备注');
      if (ym.isEmpty) continue;
      if (ExcelBatchHelper.isSampleMarker(note)) continue;
      double num(String k) =>
          double.tryParse(ExcelBatchHelper.at(row, cols, k)) ?? 0;
      out.add(SalaryExcelRow(
        yearMonth: ym,
        title: ExcelBatchHelper.at(row, cols, '标题').isEmpty
            ? '月工资'
            : ExcelBatchHelper.at(row, cols, '标题'),
        base: num('基本工资'),
        allowance: num('补贴'),
        deduction: num('扣款'),
        note: note,
      ));
    }
    return (rows: out, warnings: warnings);
  }
}

// ── 批量加减分 ─────────────────────────────────────────────────────────────

class PointExcelRow {
  const PointExcelRow({
    this.studentNo = '',
    this.name = '',
    required this.delta,
    this.reason = '',
  });
  final String studentNo;
  final String name;
  final int delta;
  final String reason;
}

abstract final class PointBatchExcel {
  static const sheet = '积分';
  static const headers = ['学号', '姓名', '分值', '原因'];

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: headers,
        sampleRows: [
          ['20250101', '张三', '2', '课堂发言'],
          ['20250102', '李四', '-1', '迟到'],
          ['', '王五', '1', '示例，可删除'],
        ],
        tips: [
          ('学号', '优先匹配'),
          ('姓名', '无学号时按姓名'),
          ('分值', '正数加分，负数扣分'),
          ('原因', '选填'),
        ],
      );

  static ({List<PointExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '学号': '学号',
      '姓名': '姓名',
      '分值': '分值',
      '积分': '分值',
      '原因': '原因',
      '事由': '原因',
    });
    final out = <PointExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final no = ExcelBatchHelper.at(row, cols, '学号');
      final name = ExcelBatchHelper.at(row, cols, '姓名');
      final delta = int.tryParse(ExcelBatchHelper.at(row, cols, '分值'));
      final reason = ExcelBatchHelper.at(row, cols, '原因');
      if (no.isEmpty && name.isEmpty && delta == null) continue;
      if (ExcelBatchHelper.isSampleMarker(reason)) continue;
      if (delta == null || delta == 0) {
        warnings.add('第 ${r + 1} 行分值无效');
        continue;
      }
      if (no.isEmpty && name.isEmpty) {
        warnings.add('第 ${r + 1} 行缺学生');
        continue;
      }
      out.add(PointExcelRow(
        studentNo: no,
        name: name,
        delta: delta,
        reason: reason.isEmpty ? (delta > 0 ? '加分' : '扣分') : reason,
      ));
    }
    return (rows: out, warnings: warnings);
  }
}

class TeacherTimetableExcelRow {
  const TeacherTimetableExcelRow({
    required this.weekday,
    required this.period,
    required this.subject,
    required this.className,
  });

  final int weekday;
  final int period;
  final String subject;
  final String className;
}

/// 教师个人课表导入（星期 / 节次 / 科目 / 班级）
abstract final class TeacherTimetableExcel {
  static const sheet = '教师课表';

  static Uint8List template() => ExcelBatchHelper.buildTemplate(
        sheetName: sheet,
        headers: const ['星期', '节次', '科目', '班级'],
        sampleRows: const [
          ['一', '1', '语文', '高一（1）班'],
          ['一', '3', '语文', '高一（2）班'],
          ['三', '5', '班会', '高一（1）班'],
        ],
        tips: const [
          ('星期', '一～日，或 1～7'),
          ('节次', '第几节，数字 1～12'),
          ('科目', '本人授课科目，如语文'),
          ('班级', '须与 App 中班级名称一致（可含年级）'),
          ('说明', '导入会写入对应班级课表，并标记为本人授课；示例行可删'),
        ],
      );

  static ({List<TeacherTimetableExcelRow> rows, List<String> warnings}) parse(
    Uint8List bytes,
  ) {
    final excel = Excel.decodeBytes(bytes);
    final sh = ExcelBatchHelper.pickSheet(excel, preferred: sheet);
    final warnings = <String>[];
    if (sh == null || sh.maxRows < 2) {
      return (rows: const [], warnings: ['没有可导入的数据']);
    }
    final cols = ExcelBatchHelper.mapHeaders(sh, {
      '星期': '星期',
      '周几': '星期',
      '星期几': '星期',
      '节次': '节次',
      '第几节': '节次',
      '科目': '科目',
      '课程': '科目',
      '班级': '班级',
      '班级名称': '班级',
      '上课班级': '班级',
    });
    final out = <TeacherTimetableExcelRow>[];
    for (var r = 1; r < sh.maxRows; r++) {
      final row = sh.row(r);
      final subject = ExcelBatchHelper.at(row, cols, '科目');
      final className = ExcelBatchHelper.at(row, cols, '班级');
      if (ExcelBatchHelper.isSampleMarker(subject) ||
          ExcelBatchHelper.isSampleMarker(className)) {
        continue;
      }
      if (subject.isEmpty && className.isEmpty) continue;
      final wd = ExcelBatchHelper.parseWeekday(
        ExcelBatchHelper.at(row, cols, '星期'),
      );
      final periodRaw = ExcelBatchHelper.at(row, cols, '节次')
          .replaceAll(RegExp(r'[第节次]'), '')
          .trim();
      final period = int.tryParse(periodRaw);
      if (wd == null || period == null || period < 1) {
        warnings.add('第 ${r + 1} 行星期或节次无效');
        continue;
      }
      if (subject.isEmpty) {
        warnings.add('第 ${r + 1} 行缺科目');
        continue;
      }
      if (className.isEmpty) {
        warnings.add('第 ${r + 1} 行缺班级');
        continue;
      }
      out.add(
        TeacherTimetableExcelRow(
          weekday: wd,
          period: period,
          subject: subject,
          className: className,
        ),
      );
    }
    return (rows: out, warnings: warnings);
  }
}
