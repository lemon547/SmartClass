import 'dart:typed_data';

import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/excel_batch_helper.dart';
import 'package:smart_class/services/excel_grid.dart';

enum AiTimetableLayout { list, matrix }

class AiTimetableSlotRow {
  const AiTimetableSlotRow({
    required this.weekday,
    required this.period,
    required this.subject,
    this.className = '',
  });

  final int weekday; // 1–7
  final int period;
  final String subject;
  final String className;
}

class AiTimetableMapping {
  const AiTimetableMapping({
    required this.layout,
    required this.headerRowIndex,
    this.weekdayColumn,
    this.periodColumn,
    this.subjectColumn,
    this.classColumn,
    this.weekdayColumns = const {},
    this.className = '',
    this.notes = '',
  });

  final AiTimetableLayout layout;
  final int headerRowIndex;
  final int? weekdayColumn;
  final int? periodColumn;
  final int? subjectColumn;
  final int? classColumn;

  /// matrix: weekday(1-7) → column index
  final Map<int, int> weekdayColumns;
  final String className;
  final String notes;

  factory AiTimetableMapping.fromJson(Map<String, dynamic> json) {
    final layoutRaw = (json['layout'] ?? 'matrix').toString().toLowerCase();
    final layout = layoutRaw == 'list'
        ? AiTimetableLayout.list
        : AiTimetableLayout.matrix;

    final wdCols = <int, int>{};
    final rawCols = json['weekdayColumns'];
    if (rawCols is Map) {
      for (final e in rawCols.entries) {
        final wd = int.tryParse(e.key.toString().trim()) ?? _asInt(e.key);
        final col = _asInt(e.value);
        if (wd != null && wd >= 1 && wd <= 7 && col != null && col >= 0) {
          wdCols[wd] = col;
        }
      }
    }

    return AiTimetableMapping(
      layout: layout,
      headerRowIndex: _asInt(json['headerRowIndex']) ?? 0,
      weekdayColumn: _asInt(json['weekdayColumn']),
      periodColumn: _asInt(json['periodColumn']),
      subjectColumn: _asInt(json['subjectColumn']),
      classColumn: _asInt(json['classColumn']),
      weekdayColumns: wdCols,
      className: (json['className'] ?? '').toString().trim(),
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

class AiTimetableParseResult {
  const AiTimetableParseResult({
    required this.mapping,
    required this.rows,
    this.warnings = const [],
  });

  final AiTimetableMapping mapping;
  final List<AiTimetableSlotRow> rows;
  final List<String> warnings;
}

/// 任意课表 Excel → AI 映射 → 本地全表提取。
class AiTimetableImport {
  AiTimetableImport(this._ai);

  final DeepSeekAiService _ai;

  Future<AiTimetableParseResult> parseBytes(
    Uint8List bytes, {
    String? fileName,
    List<String> knownClassTitles = const [],
  }) async {
    final grid = ExcelGrid.fromBytes(bytes, fileName: fileName);
    if (grid.rows.isEmpty) {
      return const AiTimetableParseResult(
        mapping: AiTimetableMapping(
          layout: AiTimetableLayout.matrix,
          headerRowIndex: 0,
        ),
        rows: [],
        warnings: ['表格为空或无法读取'],
      );
    }

    final mappingJson = await _ai.inferTimetableMappingJson(
      tsv: grid.toNumberedTsv(maxRows: 40, maxCols: 12),
      sheetName: grid.sheetName,
      knownClassTitles: knownClassTitles,
    );
    final mapping = AiTimetableMapping.fromJson(mappingJson);
    final extracted = _extractRows(grid, mapping);
    return AiTimetableParseResult(
      mapping: mapping,
      rows: extracted.rows,
      warnings: [
        if (mapping.notes.isNotEmpty) mapping.notes,
        ...extracted.warnings,
      ],
    );
  }

  static ({List<AiTimetableSlotRow> rows, List<String> warnings}) _extractRows(
    ExcelGrid grid,
    AiTimetableMapping mapping,
  ) {
    return mapping.layout == AiTimetableLayout.list
        ? _extractList(grid, mapping)
        : _extractMatrix(grid, mapping);
  }

  static ({List<AiTimetableSlotRow> rows, List<String> warnings}) _extractList(
    ExcelGrid grid,
    AiTimetableMapping mapping,
  ) {
    final warnings = <String>[];
    final wdCol = mapping.weekdayColumn;
    final pCol = mapping.periodColumn;
    final sCol = mapping.subjectColumn;
    if (wdCol == null || pCol == null || sCol == null) {
      return (
        rows: const <AiTimetableSlotRow>[],
        warnings: ['长表缺少星期/节次/科目列映射'],
      );
    }
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      return (
        rows: const <AiTimetableSlotRow>[],
        warnings: ['表头行无效'],
      );
    }

    final rows = <AiTimetableSlotRow>[];
    for (var r = header + 1; r < grid.rows.length; r++) {
      final line = grid.rows[r];
      String at(int? i) {
        if (i == null || i < 0 || i >= line.length) return '';
        return line[i].trim();
      }

      final subject = at(sCol);
      if (subject.isEmpty || _isNoiseSubject(subject)) continue;
      final wd = ExcelBatchHelper.parseWeekday(at(wdCol));
      final period = _parsePeriod(at(pCol));
      if (wd == null || period == null) {
        warnings.add('第 ${r + 1} 行星期/节次无法识别');
        continue;
      }
      final className = at(mapping.classColumn);
      rows.add(
        AiTimetableSlotRow(
          weekday: wd,
          period: period,
          subject: subject,
          className: className.isNotEmpty ? className : mapping.className,
        ),
      );
    }
    if (rows.isEmpty) warnings.add('长表未提取到课程行');
    return (rows: rows, warnings: warnings);
  }

  static ({List<AiTimetableSlotRow> rows, List<String> warnings}) _extractMatrix(
    ExcelGrid grid,
    AiTimetableMapping mapping,
  ) {
    final warnings = <String>[];
    if (mapping.weekdayColumns.isEmpty) {
      return (
        rows: const <AiTimetableSlotRow>[],
        warnings: ['矩阵未识别到星期列'],
      );
    }
    final header = mapping.headerRowIndex;
    final pCol = mapping.periodColumn ?? 0;
    if (header < 0 || header >= grid.rows.length) {
      return (
        rows: const <AiTimetableSlotRow>[],
        warnings: ['表头行无效'],
      );
    }

    final rows = <AiTimetableSlotRow>[];
    for (var r = header + 1; r < grid.rows.length; r++) {
      final line = grid.rows[r];
      String at(int i) {
        if (i < 0 || i >= line.length) return '';
        return line[i].trim();
      }

      var period = _parsePeriod(at(pCol));
      // 若节次列为空，尝试用相对行号：表头下一行为第 1 节
      period ??= (r - header).clamp(1, 20);

      for (final e in mapping.weekdayColumns.entries) {
        final subject = at(e.value);
        if (subject.isEmpty || _isNoiseSubject(subject)) continue;
        // 单元格可能是「语文\n张老师」只取第一行科目
        final sub = subject.split(RegExp(r'[\n/|]')).first.trim();
        if (sub.isEmpty || _isNoiseSubject(sub)) continue;
        rows.add(
          AiTimetableSlotRow(
            weekday: e.key,
            period: period,
            subject: sub,
            className: mapping.className,
          ),
        );
      }
    }
    if (rows.isEmpty) warnings.add('矩阵未提取到课程格');
    return (rows: rows, warnings: warnings);
  }

  static int? _parsePeriod(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n != null && n >= 1 && n <= 20) return n;
    final m = RegExp(r'(\d+)').firstMatch(t);
    if (m != null) {
      final v = int.tryParse(m.group(1)!);
      if (v != null && v >= 1 && v <= 20) return v;
    }
    return null;
  }

  static bool _isNoiseSubject(String s) {
    const noise = [
      '备课',
      '教研',
      '会议',
      '空',
      '无',
      '/',
      '-',
      '—',
      '休息',
      '放学',
    ];
    final t = s.trim();
    if (t.isEmpty) return true;
    return noise.any((k) => t == k || (t.contains(k) && t.length <= 4));
  }
}
