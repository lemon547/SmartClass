import 'dart:typed_data';

import 'package:smart_class/services/ai_import_pipeline.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/exam_score_excel.dart';
import 'package:smart_class/services/excel_grid.dart';

/// AI 识别出的成绩表列映射（再由本地代码扫全表，避免漏行）。
class AiGradeTableMapping {
  const AiGradeTableMapping({
    this.examTitle = '',
    this.examDate = '',
    this.category = '',
    required this.headerRowIndex,
    required this.nameColumn,
    this.studentNoColumn,
    this.remarkColumn,
    required this.subjectColumns,
    this.notes = '',
    this.nameSamples = const [],
  });

  final String examTitle;
  final String examDate;
  final String category;
  final int headerRowIndex;
  final int nameColumn;
  final int? studentNoColumn;
  final int? remarkColumn;

  /// 标准科目名 → 列索引（0-based）
  final Map<String, int> subjectColumns;
  final String notes;

  /// AI 自称从姓名列抄写的样例（用于 grounding 校验）。
  final List<String> nameSamples;

  List<String> get subjects => subjectColumns.keys.toList();

  AiGradeTableMapping copyWith({
    String? examTitle,
    String? examDate,
    String? category,
    int? headerRowIndex,
    int? nameColumn,
    int? studentNoColumn,
    int? remarkColumn,
    Map<String, int>? subjectColumns,
    String? notes,
    List<String>? nameSamples,
    bool clearStudentNoColumn = false,
    bool clearRemarkColumn = false,
  }) {
    return AiGradeTableMapping(
      examTitle: examTitle ?? this.examTitle,
      examDate: examDate ?? this.examDate,
      category: category ?? this.category,
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      nameColumn: nameColumn ?? this.nameColumn,
      studentNoColumn: clearStudentNoColumn
          ? null
          : (studentNoColumn ?? this.studentNoColumn),
      remarkColumn:
          clearRemarkColumn ? null : (remarkColumn ?? this.remarkColumn),
      subjectColumns: subjectColumns ?? this.subjectColumns,
      notes: notes ?? this.notes,
      nameSamples: nameSamples ?? this.nameSamples,
    );
  }

  factory AiGradeTableMapping.fromJson(Map<String, dynamic> json) {
    final subjectsRaw = json['subjectColumns'];
    final subjects = <String, int>{};
    if (subjectsRaw is Map) {
      for (final e in subjectsRaw.entries) {
        final key = e.key.toString().trim();
        final col = _asInt(e.value);
        if (key.isEmpty || col == null || col < 0) continue;
        subjects[key] = col;
      }
    }
    final samplesRaw = json['nameSamples'];
    final samples = <String>[];
    if (samplesRaw is List) {
      for (final v in samplesRaw) {
        final s = v.toString().trim();
        if (s.isNotEmpty) samples.add(s);
      }
    }
    return AiGradeTableMapping(
      examTitle: (json['examTitle'] ?? '').toString().trim(),
      examDate: (json['examDate'] ?? '').toString().trim(),
      category: (json['category'] ?? '').toString().trim(),
      headerRowIndex: _asInt(json['headerRowIndex']) ?? 0,
      nameColumn: _asInt(json['nameColumn']) ?? 0,
      studentNoColumn: _asInt(json['studentNoColumn']),
      remarkColumn: _asInt(json['remarkColumn']),
      subjectColumns: subjects,
      notes: (json['notes'] ?? '').toString().trim(),
      nameSamples: samples,
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString().trim());
  }
}

class AiGradeParseResult {
  const AiGradeParseResult({
    required this.mapping,
    required this.rows,
    required this.grid,
    this.warnings = const [],
    this.validationErrors = const [],
    this.mappingOk = false,
    this.repairAttempts = 0,
  });

  final AiGradeTableMapping mapping;
  final List<ExamScoreRow> rows;
  final ExcelGrid grid;
  final List<String> warnings;

  /// 确定性语义校验未通过的原因（空表示通过）。
  final List<String> validationErrors;

  /// 映射是否通过语义校验（AI 重试耗尽后仍可能为 false，需人工改列）。
  final bool mappingOk;

  /// 实际调用模型的次数（含首次）。
  final int repairAttempts;

  bool get needsManualMapping => !mappingOk;
}

/// 任意成绩 Excel → AI 列映射 → 校验/纠错 → 本地全表提取。
class AiExamScoreImport {
  AiExamScoreImport(this._ai, {this.maxAttempts = 3});

  final DeepSeekAiService _ai;

  /// 含首次，最多尝试次数（规范：封顶重试后升级人工）。
  final int maxAttempts;

  Future<AiGradeParseResult> parseBytes(
    Uint8List bytes, {
    String? fileName,
    List<String> knownStudentNames = const [],
    List<String> preferredSubjects = const [],
  }) async {
    final grid = await ExcelGrid.fromBytesAsync(bytes, fileName: fileName);
    if (grid.rows.isEmpty) {
      return AiGradeParseResult(
        mapping: const AiGradeTableMapping(
          headerRowIndex: 0,
          nameColumn: 0,
          subjectColumns: {},
        ),
        rows: const [],
        grid: grid,
        warnings: const ['表格为空或无法读取'],
        validationErrors: const ['表格为空'],
        mappingOk: false,
      );
    }

    final tsv = grid.toNumberedTsv();
    final repaired = await AiMappingRepairLoop.run<AiGradeTableMapping>(
      ai: _ai,
      seedMessages: _ai.gradeTableMappingSeedMessages(
        tsv: tsv,
        sheetName: grid.sheetName,
        knownStudentNames: knownStudentNames,
        preferredSubjects: preferredSubjects,
      ),
      parseMapping: AiGradeTableMapping.fromJson,
      validate: (m) => validateMapping(
        grid,
        m,
        knownStudentNames: knownStudentNames,
      ),
      fallbackMapping: const AiGradeTableMapping(
        headerRowIndex: 0,
        nameColumn: 0,
        subjectColumns: {},
      ),
      jsonLabel: '成绩表结构',
      requiredFieldsHint:
          'headerRowIndex、nameColumn、subjectColumns、nameSamples',
      maxAttempts: maxAttempts,
      repairUserMessage: (m, errors) {
        final dump = AiImportGridHelpers.headerDump(grid, m.headerRowIndex);
        return '语义校验失败，请对照原始 TSV 与下列各列样例，整份重做并输出完整 json'
            '（务必改正 nameColumn，不要沿用错误值）：\n'
            '${errors.map((e) => '- $e').join('\n')}\n\n'
            '当前表头行各列快照：\n$dump';
      },
    );

    final extracted = extractRows(grid, repaired.mapping);
    return AiGradeParseResult(
      mapping: repaired.mapping,
      rows: extracted.rows,
      grid: grid,
      warnings: [
        if (repaired.mapping.notes.isNotEmpty) repaired.mapping.notes,
        ...repaired.warnings,
        ...extracted.warnings,
      ],
      validationErrors: repaired.validationErrors,
      mappingOk: repaired.mappingOk,
      repairAttempts: repaired.attempts,
    );
  }

  /// 用户改列后：本地重抽 + 重校验（不再调 AI）。
  static AiGradeParseResult applyMapping(
    ExcelGrid grid,
    AiGradeTableMapping mapping, {
    List<String> knownStudentNames = const [],
    List<String> extraWarnings = const [],
  }) {
    final errors = validateMapping(
      grid,
      mapping,
      knownStudentNames: knownStudentNames,
    );
    final extracted = extractRows(grid, mapping);
    return AiGradeParseResult(
      mapping: mapping,
      rows: extracted.rows,
      grid: grid,
      warnings: [
        if (mapping.notes.isNotEmpty) mapping.notes,
        ...extraWarnings,
        ...extracted.warnings,
      ],
      validationErrors: errors,
      mappingOk: errors.isEmpty,
      repairAttempts: 0,
    );
  }

  /// 确定性语义校验：只检查证据，不写死业务词表猜列。
  static List<String> validateMapping(
    ExcelGrid grid,
    AiGradeTableMapping mapping, {
    List<String> knownStudentNames = const [],
  }) {
    final errors = <String>[];
    final header = mapping.headerRowIndex;
    if (grid.rows.isEmpty) {
      errors.add('表格为空');
      return errors;
    }
    if (header < 0 || header >= grid.rows.length) {
      errors.add('headerRowIndex=$header 超出表格范围（0..${grid.rows.length - 1}）');
      return errors;
    }

    final width = grid.colCount;
    if (mapping.nameColumn < 0 || mapping.nameColumn >= width) {
      errors.add('nameColumn=${mapping.nameColumn} 无效（列数 $width）');
    }
    if (mapping.studentNoColumn != null &&
        (mapping.studentNoColumn! < 0 || mapping.studentNoColumn! >= width)) {
      errors.add('studentNoColumn=${mapping.studentNoColumn} 无效');
    }
    if (mapping.remarkColumn != null &&
        (mapping.remarkColumn! < 0 || mapping.remarkColumn! >= width)) {
      errors.add('remarkColumn=${mapping.remarkColumn} 无效');
    }
    if (mapping.subjectColumns.isEmpty) {
      errors.add('subjectColumns 为空：至少需要一列单科成绩');
    }
    for (final e in mapping.subjectColumns.entries) {
      if (e.value < 0 || e.value >= width) {
        errors.add('科目「${e.key}」列索引 ${e.value} 无效');
      }
      if (e.value == mapping.nameColumn) {
        errors.add('科目「${e.key}」与 nameColumn 指向同一列');
      }
    }
    if (errors.isNotEmpty) return errors;

    final nameSamples = columnSamples(grid, header, mapping.nameColumn, limit: 12);
    if (nameSamples.isEmpty) {
      errors.add('nameColumn=${mapping.nameColumn} 在表头以下几乎没有非空单元格');
      return errors;
    }

    final uniqueNames = nameSamples.toSet();

    // 低多样性：姓名列几乎全相同 → 几乎必然指错列（不依赖词表）。
    if (AiImportGridHelpers.isLowDiversityNameColumn(nameSamples)) {
      errors.add(
        'nameColumn=${mapping.nameColumn} 样例几乎全是同一个值「${uniqueNames.first}」，'
        '不像每人不同的姓名列；请改选其它列',
      );
    }

    // Grounding：AI 宣称的 nameSamples 应能在该列真实读到。
    if (mapping.nameSamples.isNotEmpty) {
      final colSet = uniqueNames;
      final grounded =
          mapping.nameSamples.where((s) => colSet.contains(s.trim())).length;
      if (grounded == 0) {
        errors.add(
          'nameSamples（${mapping.nameSamples.take(5).join('、')}）'
          '在 nameColumn=${mapping.nameColumn} 的实际单元格中找不到，说明姓名列指错或样例编造',
        );
      }
    }

    final known = {
      for (final n in knownStudentNames)
        if (n.trim().isNotEmpty) n.trim(),
    };
    if (known.isNotEmpty && nameSamples.length >= 3) {
      final hits = nameSamples.where(known.contains).length;
      // 无重合且样例几乎不变 → 典型指错列；样例多样但无重合可能是他班表，留给匹配预览处理。
      if (hits == 0 && uniqueNames.length <= 2) {
        errors.add(
          'nameColumn=${mapping.nameColumn} 样例「${nameSamples.take(6).join('、')}」'
          '与本班花名册完全无重合，且几乎不变化',
        );
      }
    }

    // 科目列应能解析出足够比例的数字。
    for (final e in mapping.subjectColumns.entries) {
      final samples = columnSamples(grid, header, e.value, limit: 10);
      if (samples.isEmpty) {
        errors.add('科目「${e.key}」列 ${e.value} 几乎全空');
        continue;
      }
      var numeric = 0;
      for (final raw in samples) {
        final cleaned = raw
            .replaceAll(',', '')
            .replaceAll('，', '')
            .replaceAll('分', '')
            .trim();
        if (double.tryParse(cleaned) != null) numeric++;
      }
      if (numeric < (samples.length / 2).ceil()) {
        errors.add(
          '科目「${e.key}」列 ${e.value} 多数单元格不是分数'
          '（样例：${samples.take(4).join('、')}）',
        );
      }
    }

    return errors;
  }

  static List<String> columnSamples(
    ExcelGrid grid,
    int headerRowIndex,
    int column, {
    int limit = 12,
  }) {
    return AiImportGridHelpers.columnSamples(
      grid,
      headerRowIndex,
      column,
      limit: limit,
      skip: _isSummaryName,
    );
  }

  /// 表头行各列标签（供 UI 下拉展示）。
  static List<String> headerLabels(ExcelGrid grid, int headerRowIndex) =>
      AiImportGridHelpers.headerLabels(grid, headerRowIndex);

  static ({List<ExamScoreRow> rows, List<String> warnings}) extractRows(
    ExcelGrid grid,
    AiGradeTableMapping mapping,
  ) {
    final warnings = <String>[];
    if (mapping.subjectColumns.isEmpty) {
      return (
        rows: const <ExamScoreRow>[],
        warnings: ['未能识别科目列'],
      );
    }
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      return (
        rows: const <ExamScoreRow>[],
        warnings: ['表头行索引无效：$header'],
      );
    }

    final headerCells = grid.rows[header];
    int? convertedCol;
    int? gradeCol;
    final subjectRankCols = <String, int>{};
    for (var i = 0; i < headerCells.length; i++) {
      final h = headerCells[i].trim();
      if (h.isEmpty) continue;
      if (h == '折算排名' ||
          h == '赋分排名' ||
          h == '折算名次' ||
          h == '赋分名次') {
        convertedCol = i;
        continue;
      }
      if (h == '年级排名' ||
          h == '校级排名' ||
          h == '年级名次' ||
          h == '校级名次' ||
          h == '位次') {
        gradeCol = i;
        continue;
      }
      if ((h.endsWith('排名') || h.endsWith('名次')) &&
          h != '班级排名' &&
          h != '班内排名' &&
          h != '名次') {
        final sub = h.replaceAll(RegExp(r'(排名|名次)$'), '').trim();
        if (sub.isNotEmpty) subjectRankCols[sub] = i;
      }
    }

    int? parseRank(String raw) {
      if (raw.isEmpty) return null;
      return int.tryParse(raw.replaceAll(RegExp(r'[名第]'), ''));
    }

    final rows = <ExamScoreRow>[];
    for (var r = header + 1; r < grid.rows.length; r++) {
      final line = grid.rows[r];
      String at(int? i) {
        if (i == null || i < 0 || i >= line.length) return '';
        return line[i].trim();
      }

      final name = at(mapping.nameColumn);
      if (name.isEmpty) continue;
      if (_isSummaryName(name)) continue;

      final scores = <String, double>{};
      for (final e in mapping.subjectColumns.entries) {
        final raw = at(e.value);
        if (raw.isEmpty) continue;
        final cleaned = raw
            .replaceAll(',', '')
            .replaceAll('，', '')
            .replaceAll('分', '')
            .trim();
        final v = double.tryParse(cleaned);
        if (v == null) {
          if (RegExp(r'[\d.]').hasMatch(cleaned)) {
            warnings.add('第 ${r + 1} 行「${e.key}」无法识别：$raw');
          }
          continue;
        }
        scores[e.key] = v;
      }

      final subjectRanks = <String, int>{};
      for (final e in subjectRankCols.entries) {
        final rk = parseRank(at(e.value));
        if (rk != null) subjectRanks[e.key] = rk;
      }
      final convertedRank = parseRank(at(convertedCol));
      final gradeRank = parseRank(at(gradeCol));

      if (scores.isEmpty &&
          convertedRank == null &&
          gradeRank == null &&
          subjectRanks.isEmpty) {
        continue;
      }

      rows.add(
        ExamScoreRow(
          name: name,
          studentNo: at(mapping.studentNoColumn),
          scores: scores,
          remark: at(mapping.remarkColumn),
          convertedRank: convertedRank,
          gradeRank: gradeRank,
          subjectRanks: subjectRanks,
        ),
      );
    }

    if (rows.isEmpty) {
      warnings.add('按当前列映射未提取到成绩行');
    }
    return (rows: rows, warnings: warnings);
  }

  static bool _isSummaryName(String name) {
    const keys = [
      '合计',
      '总计',
      '平均',
      '均分',
      '最高',
      '最低',
      '班级',
      '人数',
      '备注说明',
    ];
    return keys.any((k) => name.contains(k));
  }
}
