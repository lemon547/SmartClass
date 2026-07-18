import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/excel_grid.dart';

class ExamScoreRow {
  const ExamScoreRow({
    required this.name,
    this.studentNo = '',
    required this.scores,
    this.remark = '',
    this.convertedRank,
    this.gradeRank,
    this.subjectRanks = const {},
  });

  final String name;
  final String studentNo;
  final Map<String, double> scores;
  final String remark;
  final int? convertedRank;
  final int? gradeRank;
  final Map<String, int> subjectRanks;
}

class ExamScoreParseResult {
  const ExamScoreParseResult({
    required this.rows,
    this.warnings = const [],
  });

  final List<ExamScoreRow> rows;
  final List<String> warnings;
}

/// 成绩表 Excel（WPS / Excel）：姓名、学号 + 各科目列 + 可选排名列
class ExamScoreExcel {
  ExamScoreExcel._();

  static bool _isSkipHeader(String h) {
    if (h == '总分' || h == '合计' || h == '平均分') return true;
    if (h == '班级排名' || h == '班内排名' || h == '名次') return true;
    return false;
  }

  static bool _isConvertedRank(String h) =>
      h == '折算排名' || h == '赋分排名' || h == '折算名次' || h == '赋分名次';

  static bool _isGradeRank(String h) =>
      h == '年级排名' ||
      h == '校级排名' ||
      h == '年级名次' ||
      h == '校级名次' ||
      h == '位次';

  static Uint8List buildTemplateBytes({
    required Exam exam,
    required List<Student> students,
  }) {
    final excel = Excel.createExcel();
    const sheetName = '成绩表';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final headers = <CellValue?>[
      TextCellValue('姓名'),
      TextCellValue('学号'),
      for (final s in exam.subjects) TextCellValue(s),
      TextCellValue('备注'),
      TextCellValue('折算排名'),
      TextCellValue('年级排名'),
    ];
    sheet.appendRow(headers);

    if (students.isEmpty) {
      sheet.appendRow([
        TextCellValue('张三'),
        TextCellValue('01'),
        for (final _ in exam.subjects) TextCellValue(''),
        TextCellValue('示例行，可删除'),
        TextCellValue(''),
        TextCellValue(''),
      ]);
    } else {
      for (final stu in students) {
        sheet.appendRow([
          TextCellValue(stu.name),
          TextCellValue(stu.studentNo),
          for (final _ in exam.subjects) TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue(''),
        ]);
      }
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i < 2 ? 12 : 10);
    }

    final tip = excel['填写说明'];
    tip.appendRow([TextCellValue('考试'), TextCellValue(exam.title)]);
    tip.appendRow([TextCellValue('类别'), TextCellValue(exam.category)]);
    tip.appendRow([
      TextCellValue('科目'),
      TextCellValue(exam.subjects.join('、')),
    ]);
    tip.appendRow([
      TextCellValue('满分 / 及格'),
      TextCellValue('${_fmt(exam.fullScore)} / ${_fmt(exam.passScore)}'),
    ]);
    tip.appendRow([
      TextCellValue('App 自动计算'),
      TextCellValue('班内总分排名、单科排名（按已录分数，无需填写）'),
    ]);
    tip.appendRow([
      TextCellValue('需从学校表粘贴'),
      TextCellValue('折算排名、年级/校级排名；可选「语文排名」等官方单科位次列'),
    ]);
    tip.appendRow([
      TextCellValue('提示'),
      TextCellValue('用 WPS 或 Excel 填「成绩表」后导入；优先按学号匹配学生'),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法生成成绩模板');
    return Uint8List.fromList(bytes);
  }

  /// 导出本班本场已填成绩（含计算班内名次与导入的折算/年级名次）
  static Uint8List buildFilledBytes({
    required Exam exam,
    required String classTitle,
    required List<Student> students,
    required List<ExamScore> scores,
    required Map<String, int> classRanksByStudentId,
  }) {
    final excel = Excel.createExcel();
    const sheetName = '成绩表';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    final hasConverted = scores.any((s) => s.convertedRank != null);
    final hasGrade = scores.any((s) => s.gradeRank != null);

    final headers = <CellValue?>[
      TextCellValue('姓名'),
      TextCellValue('学号'),
      for (final s in exam.subjects) TextCellValue(s),
      TextCellValue('总分'),
      TextCellValue('班级排名'),
      if (hasConverted) TextCellValue('折算排名'),
      if (hasGrade) TextCellValue('年级排名'),
      TextCellValue('备注'),
    ];
    sheet.appendRow(headers);

    final byId = {for (final s in scores) s.studentId: s};
    for (final stu in students) {
      final sc = byId[stu.id];
      sheet.appendRow([
        TextCellValue(stu.name),
        TextCellValue(stu.studentNo),
        for (final sub in exam.subjects)
          sc?.scoreOf(sub) == null
              ? TextCellValue('')
              : DoubleCellValue(sc!.scoreOf(sub)!),
        sc == null || sc.scores.isEmpty
            ? TextCellValue('')
            : DoubleCellValue(sc.total),
        classRanksByStudentId[stu.id] == null
            ? TextCellValue('')
            : IntCellValue(classRanksByStudentId[stu.id]!),
        if (hasConverted)
          sc?.convertedRank == null
              ? TextCellValue('')
              : IntCellValue(sc!.convertedRank!),
        if (hasGrade)
          sc?.gradeRank == null
              ? TextCellValue('')
              : IntCellValue(sc!.gradeRank!),
        TextCellValue(sc?.remark ?? ''),
      ]);
    }

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i < 2 ? 12 : 10);
    }

    final tip = excel['导出说明'];
    tip.appendRow([TextCellValue('班级'), TextCellValue(classTitle)]);
    tip.appendRow([TextCellValue('考试'), TextCellValue(exam.title)]);
    tip.appendRow([TextCellValue('日期'), TextCellValue(exam.examDate)]);
    tip.appendRow([
      TextCellValue('班级排名'),
      TextCellValue('由 App 按总分计算（dense rank）'),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法导出成绩表');
    return Uint8List.fromList(bytes);
  }

  static ExamScoreParseResult parseBytes(
    Uint8List bytes, {
    required List<String> subjects,
    String? fileName,
  }) {
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.csv') || _looksLikeCsv(bytes)) {
      return _parseTable(
        _csvToRows(utf8.decode(bytes, allowMalformed: true)),
        subjects,
      );
    }
    final excel = ExcelGrid.decodeExcelBytes(bytes);
    Sheet? sheet;
    for (final name in excel.tables.keys) {
      if (name.contains('成绩') || name.contains('分数')) {
        sheet = excel.tables[name];
        break;
      }
    }
    sheet ??= excel.tables.values.isEmpty ? null : excel.tables.values.first;
    if (sheet == null) {
      return const ExamScoreParseResult(
        rows: [],
        warnings: ['表格为空'],
      );
    }
    final raw = <List<String>>[];
    for (final row in sheet.rows) {
      raw.add([for (final c in row) _cellToString(c?.value)]);
    }
    return _parseTable(raw, subjects);
  }

  static bool _looksLikeCsv(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return false;
    }
    final head = utf8.decode(bytes.take(64).toList(), allowMalformed: true);
    return head.contains(',') || head.contains('姓名');
  }

  static List<List<String>> _csvToRows(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty);
    return [for (final line in lines) _splitCsvLine(line)];
  }

  static List<String> _splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (!inQuotes && (c == ',' || c == '\t' || c == ';')) {
        out.add(buf.toString().trim());
        buf.clear();
        continue;
      }
      buf.write(c);
    }
    out.add(buf.toString().trim());
    return out;
  }

  static ExamScoreParseResult _parseTable(
    List<List<String>> rawRows,
    List<String> expectedSubjects,
  ) {
    if (rawRows.isEmpty) {
      return const ExamScoreParseResult(rows: [], warnings: ['表格为空']);
    }

    var headerIndex = -1;
    for (var r = 0; r < (rawRows.length < 10 ? rawRows.length : 10); r++) {
      if (rawRows[r].any((c) => c.trim() == '姓名' || c.trim() == '名字')) {
        headerIndex = r;
        break;
      }
    }
    if (headerIndex < 0) {
      return const ExamScoreParseResult(
        rows: [],
        warnings: ['未找到「姓名」表头'],
      );
    }

    final header = rawRows[headerIndex];
    int? nameCol;
    int? noCol;
    int? remarkCol;
    int? convertedCol;
    int? gradeCol;
    final subjectCols = <String, int>{};
    final subjectRankCols = <String, int>{};

    for (var i = 0; i < header.length; i++) {
      final h = header[i].trim();
      if (h.isEmpty) continue;
      if (h == '姓名' || h == '名字') {
        nameCol = i;
        continue;
      }
      if (h == '学号' || h == '学籍号' || h == '编号') {
        noCol = i;
        continue;
      }
      if (h == '备注' || h == '说明') {
        remarkCol = i;
        continue;
      }
      if (_isConvertedRank(h)) {
        convertedCol = i;
        continue;
      }
      if (_isGradeRank(h)) {
        gradeCol = i;
        continue;
      }
      if (_isSkipHeader(h)) continue;
      if (h.endsWith('排名') || h.endsWith('名次')) {
        final sub = h.replaceAll(RegExp(r'(排名|名次)$'), '').trim();
        if (sub.isNotEmpty &&
            !_isConvertedRank(h) &&
            !_isGradeRank(h) &&
            h != '班级排名' &&
            h != '班内排名') {
          subjectRankCols[sub] = i;
          continue;
        }
      }
      subjectCols[h] = i;
    }

    if (nameCol == null) {
      return const ExamScoreParseResult(
        rows: [],
        warnings: ['表头缺少「姓名」'],
      );
    }

    final usedSubjects = <String>[];
    if (expectedSubjects.isNotEmpty) {
      for (final s in expectedSubjects) {
        if (subjectCols.containsKey(s)) usedSubjects.add(s);
      }
    }
    if (usedSubjects.isEmpty) {
      usedSubjects.addAll(subjectCols.keys);
    }

    final rows = <ExamScoreRow>[];
    final warnings = <String>[];
    for (var r = headerIndex + 1; r < rawRows.length; r++) {
      final line = rawRows[r];
      String at(int? i) {
        if (i == null || i >= line.length) return '';
        return line[i].trim();
      }

      int? parseRank(int? col) {
        final raw = at(col);
        if (raw.isEmpty) return null;
        return int.tryParse(raw.replaceAll(RegExp(r'[名第]'), ''));
      }

      final name = at(nameCol);
      if (name.isEmpty) continue;
      if (name == '张三' && at(remarkCol).contains('示例')) continue;

      final scores = <String, double>{};
      for (final s in usedSubjects) {
        final col = subjectCols[s];
        if (col == null) continue;
        final raw = at(col);
        if (raw.isEmpty) continue;
        final v = double.tryParse(raw.replaceAll(',', ''));
        if (v == null) {
          warnings.add('第 ${r + 1} 行「$s」无法识别：$raw');
          continue;
        }
        scores[s] = v;
      }

      final subjectRanks = <String, int>{};
      for (final e in subjectRankCols.entries) {
        final rk = parseRank(e.value);
        if (rk != null) subjectRanks[e.key] = rk;
      }

      final convertedRank = parseRank(convertedCol);
      final gradeRank = parseRank(gradeCol);

      if (scores.isEmpty &&
          convertedRank == null &&
          gradeRank == null &&
          subjectRanks.isEmpty) {
        continue;
      }

      rows.add(
        ExamScoreRow(
          name: name,
          studentNo: at(noCol),
          scores: scores,
          remark: at(remarkCol),
          convertedRank: convertedRank,
          gradeRank: gradeRank,
          subjectRanks: subjectRanks,
        ),
      );
    }

    if (rows.isEmpty) {
      warnings.add('没有可导入的成绩行');
    }
    return ExamScoreParseResult(rows: rows, warnings: warnings);
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    return switch (value) {
      TextCellValue(:final value) => value.toString().trim(),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) =>
        value == value.roundToDouble() ? '${value.round()}' : '$value',
      BoolCellValue(:final value) => value ? '1' : '0',
      DateCellValue() => '',
      DateTimeCellValue() => '',
      TimeCellValue() => '',
      FormulaCellValue(:final formula) => formula,
    };
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';
}
