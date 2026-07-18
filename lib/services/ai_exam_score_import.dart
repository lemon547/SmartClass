import 'dart:typed_data';

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

  List<String> get subjects => subjectColumns.keys.toList();

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
    this.warnings = const [],
  });

  final AiGradeTableMapping mapping;
  final List<ExamScoreRow> rows;
  final List<String> warnings;
}

/// 任意成绩 Excel → AI 列映射 → 本地全表提取。
class AiExamScoreImport {
  AiExamScoreImport(this._ai);

  final DeepSeekAiService _ai;

  Future<AiGradeParseResult> parseBytes(
    Uint8List bytes, {
    String? fileName,
    List<String> knownStudentNames = const [],
    List<String> preferredSubjects = const [],
  }) async {
    final grid = ExcelGrid.fromBytes(bytes, fileName: fileName);
    if (grid.rows.isEmpty) {
      return const AiGradeParseResult(
        mapping: AiGradeTableMapping(
          headerRowIndex: 0,
          nameColumn: 0,
          subjectColumns: {},
        ),
        rows: [],
        warnings: ['表格为空或无法读取'],
      );
    }

    final mappingJson = await _ai.inferGradeTableMappingJson(
      tsv: grid.toNumberedTsv(),
      sheetName: grid.sheetName,
      knownStudentNames: knownStudentNames,
      preferredSubjects: preferredSubjects,
    );
    final mapping = AiGradeTableMapping.fromJson(mappingJson);

    final extracted = _extractRows(grid, mapping);
    return AiGradeParseResult(
      mapping: mapping,
      rows: extracted.rows,
      warnings: [
        if (mapping.notes.isNotEmpty) mapping.notes,
        ...extracted.warnings,
      ],
    );
  }

  static ({List<ExamScoreRow> rows, List<String> warnings}) _extractRows(
    ExcelGrid grid,
    AiGradeTableMapping mapping,
  ) {
    final warnings = <String>[];
    if (mapping.subjectColumns.isEmpty) {
      return (
        rows: const <ExamScoreRow>[],
        warnings: ['AI 未能识别科目列，请换一张更清晰的成绩表或用标准模板'],
      );
    }
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      return (
        rows: const <ExamScoreRow>[],
        warnings: ['表头行索引无效：$header'],
      );
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
      if (scores.isEmpty) continue;

      rows.add(
        ExamScoreRow(
          name: name,
          studentNo: at(mapping.studentNoColumn),
          scores: scores,
          remark: at(mapping.remarkColumn),
        ),
      );
    }

    if (rows.isEmpty) {
      warnings.add('按 AI 映射未提取到成绩行');
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
