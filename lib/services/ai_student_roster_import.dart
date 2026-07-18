import 'dart:typed_data';

import 'package:smart_class/services/ai_import_pipeline.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/excel_grid.dart';
import 'package:smart_class/services/student_roster_excel.dart';

class AiStudentRosterMapping {
  const AiStudentRosterMapping({
    required this.headerRowIndex,
    required this.nameColumn,
    this.studentNoColumn,
    this.genderColumn,
    this.phoneColumn,
    this.addressColumn,
    this.noteColumn,
    this.groupColumn,
    this.roleColumn,
    this.birthdayColumn,
    this.notes = '',
    this.nameSamples = const [],
  });

  final int headerRowIndex;
  final int nameColumn;
  final int? studentNoColumn;
  final int? genderColumn;
  final int? phoneColumn;
  final int? addressColumn;
  final int? noteColumn;
  final int? groupColumn;
  final int? roleColumn;
  final int? birthdayColumn;
  final String notes;
  final List<String> nameSamples;

  AiStudentRosterMapping copyWith({
    int? headerRowIndex,
    int? nameColumn,
    int? studentNoColumn,
    int? genderColumn,
    int? phoneColumn,
    int? addressColumn,
    int? noteColumn,
    int? groupColumn,
    int? roleColumn,
    int? birthdayColumn,
    String? notes,
    List<String>? nameSamples,
    bool clearStudentNo = false,
    bool clearGender = false,
    bool clearPhone = false,
    bool clearAddress = false,
    bool clearNote = false,
    bool clearGroup = false,
    bool clearRole = false,
    bool clearBirthday = false,
  }) {
    return AiStudentRosterMapping(
      headerRowIndex: headerRowIndex ?? this.headerRowIndex,
      nameColumn: nameColumn ?? this.nameColumn,
      studentNoColumn:
          clearStudentNo ? null : (studentNoColumn ?? this.studentNoColumn),
      genderColumn: clearGender ? null : (genderColumn ?? this.genderColumn),
      phoneColumn: clearPhone ? null : (phoneColumn ?? this.phoneColumn),
      addressColumn:
          clearAddress ? null : (addressColumn ?? this.addressColumn),
      noteColumn: clearNote ? null : (noteColumn ?? this.noteColumn),
      groupColumn: clearGroup ? null : (groupColumn ?? this.groupColumn),
      roleColumn: clearRole ? null : (roleColumn ?? this.roleColumn),
      birthdayColumn:
          clearBirthday ? null : (birthdayColumn ?? this.birthdayColumn),
      notes: notes ?? this.notes,
      nameSamples: nameSamples ?? this.nameSamples,
    );
  }

  factory AiStudentRosterMapping.fromJson(Map<String, dynamic> json) {
    final samplesRaw = json['nameSamples'];
    final samples = <String>[];
    if (samplesRaw is List) {
      for (final v in samplesRaw) {
        final s = v.toString().trim();
        if (s.isNotEmpty) samples.add(s);
      }
    }
    return AiStudentRosterMapping(
      headerRowIndex: _asInt(json['headerRowIndex']) ?? 0,
      nameColumn: _asInt(json['nameColumn']) ?? 0,
      studentNoColumn: _asInt(json['studentNoColumn']),
      genderColumn: _asInt(json['genderColumn']),
      phoneColumn: _asInt(json['phoneColumn']),
      addressColumn: _asInt(json['addressColumn']),
      noteColumn: _asInt(json['noteColumn']),
      groupColumn: _asInt(json['groupColumn']),
      roleColumn: _asInt(json['roleColumn']),
      birthdayColumn: _asInt(json['birthdayColumn']),
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

class AiStudentRosterParseResult {
  const AiStudentRosterParseResult({
    required this.mapping,
    required this.rows,
    required this.grid,
    this.warnings = const [],
    this.validationErrors = const [],
    this.mappingOk = false,
    this.repairAttempts = 0,
  });

  final AiStudentRosterMapping mapping;
  final List<StudentRosterRow> rows;
  final ExcelGrid grid;
  final List<String> warnings;
  final List<String> validationErrors;
  final bool mappingOk;
  final int repairAttempts;

  bool get needsManualMapping => !mappingOk;
}

class AiStudentRosterImport {
  AiStudentRosterImport(this._ai, {this.maxAttempts = 3});

  final DeepSeekAiService _ai;
  final int maxAttempts;

  Future<AiStudentRosterParseResult> parseBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final grid = await ExcelGrid.fromBytesAsync(bytes, fileName: fileName);
    if (grid.rows.isEmpty) {
      return AiStudentRosterParseResult(
        mapping: const AiStudentRosterMapping(headerRowIndex: 0, nameColumn: 0),
        rows: const [],
        grid: grid,
        warnings: const ['表格为空或无法读取'],
        validationErrors: const ['表格为空'],
        mappingOk: false,
      );
    }

    final tsv = grid.toNumberedTsv(maxRows: 50, maxCols: 20);
    final repaired = await AiMappingRepairLoop.run<AiStudentRosterMapping>(
      ai: _ai,
      seedMessages: _ai.studentRosterMappingSeedMessages(
        tsv: tsv,
        sheetName: grid.sheetName,
      ),
      parseMapping: AiStudentRosterMapping.fromJson,
      validate: (m) => validateMapping(grid, m),
      fallbackMapping:
          const AiStudentRosterMapping(headerRowIndex: 0, nameColumn: 0),
      jsonLabel: '花名册结构',
      requiredFieldsHint: 'headerRowIndex、nameColumn、nameSamples',
      maxAttempts: maxAttempts,
      repairUserMessage: (m, errors) {
        final dump = AiImportGridHelpers.headerDump(grid, m.headerRowIndex);
        return '语义校验失败，请对照原始 TSV 与各列样例整份重做 json'
            '（务必改正 nameColumn）：\n'
            '${errors.map((e) => '- $e').join('\n')}\n\n'
            '当前表头行各列快照：\n$dump';
      },
    );

    final extracted = extractRows(grid, repaired.mapping);
    return AiStudentRosterParseResult(
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

  static AiStudentRosterParseResult applyMapping(
    ExcelGrid grid,
    AiStudentRosterMapping mapping, {
    List<String> extraWarnings = const [],
  }) {
    final errors = validateMapping(grid, mapping);
    final extracted = extractRows(grid, mapping);
    return AiStudentRosterParseResult(
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
    AiStudentRosterMapping mapping,
  ) {
    final errors = <String>[];
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      errors.add('headerRowIndex=$header 无效');
      return errors;
    }
    if (!AiImportGridHelpers.columnInRange(grid, mapping.nameColumn)) {
      errors.add('nameColumn=${mapping.nameColumn} 无效');
    }
    for (final e in {
      '学号': mapping.studentNoColumn,
      '性别': mapping.genderColumn,
      '电话': mapping.phoneColumn,
      '地址': mapping.addressColumn,
      '备注': mapping.noteColumn,
      '组别': mapping.groupColumn,
      '职务': mapping.roleColumn,
      '生日': mapping.birthdayColumn,
    }.entries) {
      if (!AiImportGridHelpers.columnInRange(grid, e.value)) {
        errors.add('${e.key}列索引 ${e.value} 无效');
      }
    }
    if (errors.isNotEmpty) return errors;

    final samples = AiImportGridHelpers.columnSamples(
      grid,
      header,
      mapping.nameColumn,
      limit: 12,
      skip: _isNoiseName,
    );
    if (samples.isEmpty) {
      errors.add('nameColumn=${mapping.nameColumn} 几乎没有有效姓名');
      return errors;
    }
    if (AiImportGridHelpers.isLowDiversityNameColumn(samples)) {
      errors.add(
        'nameColumn=${mapping.nameColumn} 样例几乎全是「${samples.first}」，'
        '不像每人不同的姓名列',
      );
    }
    if (mapping.nameSamples.isNotEmpty) {
      final grounded = mapping.nameSamples
          .where((s) => samples.contains(s.trim()))
          .length;
      if (grounded == 0) {
        errors.add(
          'nameSamples 在 nameColumn 实际单元格中找不到，说明姓名列指错或样例编造',
        );
      }
    }
    return errors;
  }

  static ({List<StudentRosterRow> rows, List<String> warnings}) extractRows(
    ExcelGrid grid,
    AiStudentRosterMapping mapping,
  ) {
    final warnings = <String>[];
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      return (rows: const <StudentRosterRow>[], warnings: ['表头行无效']);
    }

    final rows = <StudentRosterRow>[];
    for (var r = header + 1; r < grid.rows.length; r++) {
      final line = grid.rows[r];
      String at(int? i) {
        if (i == null || i < 0 || i >= line.length) return '';
        return line[i].trim();
      }

      final name = at(mapping.nameColumn);
      if (name.isEmpty) continue;
      if (_isNoiseName(name)) continue;

      rows.add(
        StudentRosterRow(
          name: name,
          studentNo: at(mapping.studentNoColumn),
          gender: _normalizeGender(at(mapping.genderColumn)),
          phone: at(mapping.phoneColumn),
          address: at(mapping.addressColumn),
          note: at(mapping.noteColumn),
          groupName: at(mapping.groupColumn),
          role: at(mapping.roleColumn),
          birthday: _normalizeBirthday(at(mapping.birthdayColumn)),
        ),
      );
    }

    if (rows.isEmpty) warnings.add('未提取到学生行');
    return (rows: rows, warnings: warnings);
  }

  static bool _isNoiseName(String name) {
    const keys = ['合计', '总计', '平均', '人数', '班级', '备注说明', '姓名'];
    return keys.any((k) => name == k || (name.contains(k) && name.length <= 4));
  }

  static String _normalizeGender(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (t.contains('男') || t.toLowerCase() == 'm') return '男';
    if (t.contains('女') || t.toLowerCase() == 'f') return '女';
    return t;
  }

  static String _normalizeBirthday(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final m = RegExp(r'(\d{4})[-/.年](\d{1,2})[-/.月]?(\d{1,2})?').firstMatch(t);
    if (m != null) {
      final y = m.group(1)!;
      final mo = m.group(2)!.padLeft(2, '0');
      final d = (m.group(3) ?? '01').padLeft(2, '0');
      return '$y-$mo-$d';
    }
    return t;
  }
}
