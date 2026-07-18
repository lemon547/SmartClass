import 'dart:typed_data';

import 'package:smart_class/services/ai_import_pipeline.dart';
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

  AiTimetableMapping copyWith({
    AiTimetableLayout? layout,
    int? headerRowIndex,
    int? weekdayColumn,
    int? periodColumn,
    int? subjectColumn,
    int? classColumn,
    Map<int, int>? weekdayColumns,
    String? className,
    String? notes,
    bool clearWeekdayColumn = false,
    bool clearPeriodColumn = false,
    bool clearSubjectColumn = false,
    bool clearClassColumn = false,
  }) {
    return AiTimetableMapping(
      layout: layout ?? this.layout,
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      weekdayColumn:
          clearWeekdayColumn ? null : (weekdayColumn ?? this.weekdayColumn),
      periodColumn:
          clearPeriodColumn ? null : (periodColumn ?? this.periodColumn),
      subjectColumn:
          clearSubjectColumn ? null : (subjectColumn ?? this.subjectColumn),
      classColumn: clearClassColumn ? null : (classColumn ?? this.classColumn),
      weekdayColumns: weekdayColumns ?? this.weekdayColumns,
      className: className ?? this.className,
      notes: notes ?? this.notes,
    );
  }

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
    required this.grid,
    this.warnings = const [],
    this.validationErrors = const [],
    this.mappingOk = false,
    this.repairAttempts = 0,
  });

  final AiTimetableMapping mapping;
  final List<AiTimetableSlotRow> rows;
  final ExcelGrid grid;
  final List<String> warnings;
  final List<String> validationErrors;
  final bool mappingOk;
  final int repairAttempts;

  bool get needsManualMapping => !mappingOk;
}

/// 任意课表文件 → AI 映射 → 校验/纠错 → 本地全表提取。
class AiTimetableImport {
  AiTimetableImport(this._ai, {this.maxAttempts = 3});

  final DeepSeekAiService _ai;
  final int maxAttempts;

  Future<AiTimetableParseResult> parseBytes(
    Uint8List bytes, {
    String? fileName,
    List<String> knownClassTitles = const [],
  }) async {
    final grid = await ExcelGrid.fromBytesAsync(bytes, fileName: fileName);
    if (grid.rows.isEmpty) {
      return AiTimetableParseResult(
        mapping: const AiTimetableMapping(
          layout: AiTimetableLayout.matrix,
          headerRowIndex: 0,
        ),
        rows: const [],
        grid: grid,
        warnings: const ['表格为空或无法读取'],
        validationErrors: const ['表格为空'],
        mappingOk: false,
      );
    }

    final tsv = grid.toNumberedTsv(maxRows: 40, maxCols: 12);
    final repaired = await AiMappingRepairLoop.run<AiTimetableMapping>(
      ai: _ai,
      seedMessages: _ai.timetableMappingSeedMessages(
        tsv: tsv,
        sheetName: grid.sheetName,
        knownClassTitles: knownClassTitles,
      ),
      parseMapping: AiTimetableMapping.fromJson,
      validate: (m) => validateMapping(grid, m),
      fallbackMapping: const AiTimetableMapping(
        layout: AiTimetableLayout.matrix,
        headerRowIndex: 0,
      ),
      jsonLabel: '课表结构',
      requiredFieldsHint: 'layout、headerRowIndex',
      maxAttempts: maxAttempts,
      repairUserMessage: (m, errors) {
        final dump = AiImportGridHelpers.headerDump(grid, m.headerRowIndex);
        return '语义校验失败，请对照原始 TSV 与各列样例整份重做 json：\n'
            '${errors.map((e) => '- $e').join('\n')}\n\n'
            '当前表头行各列快照：\n$dump';
      },
    );

    final extracted = extractRows(grid, repaired.mapping);
    return AiTimetableParseResult(
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

  static AiTimetableParseResult applyMapping(
    ExcelGrid grid,
    AiTimetableMapping mapping, {
    List<String> extraWarnings = const [],
  }) {
    final errors = validateMapping(grid, mapping);
    final extracted = extractRows(grid, mapping);
    return AiTimetableParseResult(
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
    );
  }

  static List<String> validateMapping(
    ExcelGrid grid,
    AiTimetableMapping mapping,
  ) {
    final errors = <String>[];
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      errors.add('headerRowIndex=$header 无效');
      return errors;
    }

    if (mapping.layout == AiTimetableLayout.list) {
      if (mapping.weekdayColumn == null ||
          mapping.periodColumn == null ||
          mapping.subjectColumn == null) {
        errors.add('长表缺少 weekdayColumn / periodColumn / subjectColumn');
      }
      for (final e in {
        '星期': mapping.weekdayColumn,
        '节次': mapping.periodColumn,
        '科目': mapping.subjectColumn,
        '班级': mapping.classColumn,
      }.entries) {
        if (!AiImportGridHelpers.columnInRange(grid, e.value)) {
          errors.add('${e.key}列索引 ${e.value} 无效');
        }
      }
      if (errors.isNotEmpty) return errors;

      final subjects = AiImportGridHelpers.columnSamples(
        grid,
        header,
        mapping.subjectColumn!,
        limit: 10,
        skip: _isNoiseSubject,
      );
      if (subjects.isEmpty) {
        errors.add('科目列几乎没有有效课程名');
      }
      final weekdays = AiImportGridHelpers.columnSamples(
        grid,
        header,
        mapping.weekdayColumn!,
        limit: 8,
      );
      final parsedWd =
          weekdays.where((s) => ExcelBatchHelper.parseWeekday(s) != null).length;
      if (weekdays.isNotEmpty && parsedWd < (weekdays.length / 2).ceil()) {
        errors.add(
          '星期列样例多数无法解析为周一~周日（${weekdays.take(4).join('、')}）',
        );
      }
    } else {
      if (mapping.weekdayColumns.isEmpty) {
        errors.add('矩阵未识别到 weekdayColumns');
      }
      if (!AiImportGridHelpers.columnInRange(
        grid,
        mapping.periodColumn ?? 0,
      )) {
        errors.add('periodColumn=${mapping.periodColumn} 无效');
      }
      for (final e in mapping.weekdayColumns.entries) {
        if (!AiImportGridHelpers.columnInRange(grid, e.value)) {
          errors.add('星期${e.key}列索引 ${e.value} 无效');
        }
      }
      if (errors.isNotEmpty) return errors;

      // 至少一个星期列抽到非空科目样例
      var subjectHits = 0;
      for (final col in mapping.weekdayColumns.values) {
        final samples = AiImportGridHelpers.columnSamples(
          grid,
          header,
          col,
          limit: 6,
          skip: _isNoiseSubject,
        );
        subjectHits += samples.length;
      }
      if (subjectHits == 0) {
        errors.add('矩阵星期列几乎抽不到科目内容，请检查 weekdayColumns');
      }
    }
    return errors;
  }

  static ({List<AiTimetableSlotRow> rows, List<String> warnings}) extractRows(
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
      period ??= (r - header).clamp(1, 20);

      for (final e in mapping.weekdayColumns.entries) {
        final subject = at(e.value);
        if (subject.isEmpty || _isNoiseSubject(subject)) continue;
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
