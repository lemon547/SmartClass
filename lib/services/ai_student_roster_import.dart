import 'dart:typed_data';

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

  factory AiStudentRosterMapping.fromJson(Map<String, dynamic> json) {
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
    this.warnings = const [],
  });

  final AiStudentRosterMapping mapping;
  final List<StudentRosterRow> rows;
  final List<String> warnings;
}

class AiStudentRosterImport {
  AiStudentRosterImport(this._ai);

  final DeepSeekAiService _ai;

  Future<AiStudentRosterParseResult> parseBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final grid = ExcelGrid.fromBytes(bytes, fileName: fileName);
    if (grid.rows.isEmpty) {
      return const AiStudentRosterParseResult(
        mapping: AiStudentRosterMapping(headerRowIndex: 0, nameColumn: 0),
        rows: [],
        warnings: ['表格为空或无法读取'],
      );
    }

    final mappingJson = await _ai.inferStudentRosterMappingJson(
      tsv: grid.toNumberedTsv(maxRows: 50, maxCols: 20),
      sheetName: grid.sheetName,
    );
    final mapping = AiStudentRosterMapping.fromJson(mappingJson);
    final extracted = _extractRows(grid, mapping);
    return AiStudentRosterParseResult(
      mapping: mapping,
      rows: extracted.rows,
      warnings: [
        if (mapping.notes.isNotEmpty) mapping.notes,
        ...extracted.warnings,
      ],
    );
  }

  static ({List<StudentRosterRow> rows, List<String> warnings}) _extractRows(
    ExcelGrid grid,
    AiStudentRosterMapping mapping,
  ) {
    final warnings = <String>[];
    final header = mapping.headerRowIndex;
    if (header < 0 || header >= grid.rows.length) {
      return (
        rows: const <StudentRosterRow>[],
        warnings: ['表头行无效'],
      );
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
