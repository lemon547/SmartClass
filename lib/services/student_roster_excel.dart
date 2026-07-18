import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/excel_grid.dart';

/// 一行待导入的学生档案（不含 id / 积分 / 座位）。
class StudentRosterRow {
  const StudentRosterRow({
    required this.name,
    this.studentNo = '',
    this.gender = '',
    this.phone = '',
    this.note = '',
    this.groupName = '',
    this.role = '',
    this.birthday = '',
    this.address = '',
  });

  final String name;
  final String studentNo;
  final String gender;
  final String phone;
  final String note;
  final String groupName;
  final String role;
  final String birthday;
  final String address;
}

class StudentRosterParseResult {
  const StudentRosterParseResult({
    required this.rows,
    this.warnings = const [],
  });

  final List<StudentRosterRow> rows;
  final List<String> warnings;
}

/// 学生档案 Excel / CSV（WPS、Microsoft Excel 均可）。
class StudentRosterExcel {
  StudentRosterExcel._();

  static const headers = [
    '姓名',
    '学号',
    '性别',
    '电话',
    '家庭住址',
    '备注',
    '小组',
    '班委',
    '生日',
  ];

  static const _headerAliases = <String, String>{
    '姓名': '姓名',
    '名字': '姓名',
    '学生姓名': '姓名',
    'name': '姓名',
    '学号': '学号',
    '学籍号': '学号',
    '编号': '学号',
    'studentno': '学号',
    'student_no': '学号',
    '性别': '性别',
    'gender': '性别',
    '电话': '电话',
    '手机': '电话',
    '家长电话': '电话',
    '联系电话': '电话',
    'phone': '电话',
    '家庭住址': '家庭住址',
    '住址': '家庭住址',
    '地址': '家庭住址',
    '住址地址': '家庭住址',
    'address': '家庭住址',
    '备注': '备注',
    '说明': '备注',
    'note': '备注',
    '小组': '小组',
    '组别': '小组',
    'group': '小组',
    '班委': '班委',
    '职务': '班委',
    '角色': '班委',
    'role': '班委',
    '生日': '生日',
    '出生日期': '生日',
    'birthday': '生日',
  };

  /// 生成带表头 + 两行示例 + 填写说明 的 xlsx。
  static Uint8List buildTemplateBytes() {
    final excel = Excel.createExcel();
    const sheetName = '学生档案';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];

    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    sheet.appendRow([
      TextCellValue('张三'),
      TextCellValue('20250101'),
      TextCellValue('男'),
      TextCellValue('13800000001'),
      TextCellValue('示例市示例路 1 号'),
      TextCellValue('示例，可删除'),
      TextCellValue('第一组'),
      TextCellValue('班长'),
      TextCellValue('03-15'),
    ]);
    sheet.appendRow([
      TextCellValue('李四'),
      TextCellValue('20250102'),
      TextCellValue('女'),
      TextCellValue('13800000002'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('第二组'),
      TextCellValue(''),
      TextCellValue('08-20'),
    ]);

    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, i == 0 || i == 4 || i == 5 ? 16 : 12);
    }

    final tip = excel['填写说明'];
    tip.appendRow([TextCellValue('栏目'), TextCellValue('说明')]);
    tip.appendRow([TextCellValue('姓名'), TextCellValue('必填')]);
    tip.appendRow([TextCellValue('学号'), TextCellValue('建议填写；导入时按学号更新已有学生')]);
    tip.appendRow([TextCellValue('性别'), TextCellValue('男 / 女')]);
    tip.appendRow([TextCellValue('电话'), TextCellValue('家长或学生联系电话')]);
    tip.appendRow([TextCellValue('家庭住址'), TextCellValue('选填')]);
    tip.appendRow([TextCellValue('备注'), TextCellValue('选填')]);
    tip.appendRow([TextCellValue('小组'), TextCellValue('如：第一组')]);
    tip.appendRow([
      TextCellValue('班委'),
      TextCellValue('可填多个，用顿号分隔，如：班长、学习委员'),
    ]);
    tip.appendRow([TextCellValue('生日'), TextCellValue('月-日，如 03-15')]);
    tip.appendRow([
      TextCellValue('提示'),
      TextCellValue('用 WPS 或 Excel 编辑「学生档案」表后，在 App 中选择「导入 Excel」'),
    ]);

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('无法生成示例表格');
    }
    return Uint8List.fromList(bytes);
  }

  static StudentRosterParseResult parseBytes(Uint8List bytes, {String? fileName}) {
    final lower = (fileName ?? '').toLowerCase();
    if (lower.endsWith('.csv') || _looksLikeCsv(bytes)) {
      return _parseCsv(utf8.decode(bytes, allowMalformed: true));
    }
    return _parseXlsx(bytes);
  }

  static bool _looksLikeCsv(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return false; // ZIP / xlsx
    }
    final head = utf8.decode(
      bytes.take(64).toList(),
      allowMalformed: true,
    );
    return head.contains(',') || head.contains('姓名');
  }

  static StudentRosterParseResult _parseXlsx(Uint8List bytes) {
    final excel = ExcelGrid.decodeExcelBytes(bytes);
    final sheet = _pickSheet(excel);
    if (sheet == null || sheet.maxRows == 0) {
      return const StudentRosterParseResult(
        rows: [],
        warnings: ['表格为空或无法识别工作表'],
      );
    }

    final rawRows = <List<String>>[];
    for (final row in sheet.rows) {
      rawRows.add([for (final cell in row) _cellToString(cell?.value)]);
    }
    return _parseTable(rawRows);
  }

  static Sheet? _pickSheet(Excel excel) {
    for (final name in excel.tables.keys) {
      if (name.contains('学生') || name.contains('花名') || name.contains('档案')) {
        return excel.tables[name];
      }
    }
    if (excel.tables.isEmpty) return null;
    return excel.tables.values.first;
  }

  static StudentRosterParseResult _parseCsv(String text) {
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final rawRows = <List<String>>[];
    for (final line in lines) {
      rawRows.add(_splitCsvLine(line));
    }
    return _parseTable(rawRows);
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

  static StudentRosterParseResult _parseTable(List<List<String>> rawRows) {
    if (rawRows.isEmpty) {
      return const StudentRosterParseResult(
        rows: [],
        warnings: ['表格为空'],
      );
    }

    final headerIndex = _findHeaderRow(rawRows);
    if (headerIndex < 0) {
      return const StudentRosterParseResult(
        rows: [],
        warnings: ['未找到表头，请保留「姓名」列'],
      );
    }

    final colMap = <String, int>{};
    final header = rawRows[headerIndex];
    for (var i = 0; i < header.length; i++) {
      final key = _normalizeHeader(header[i]);
      if (key != null && !colMap.containsKey(key)) {
        colMap[key] = i;
      }
    }
    if (!colMap.containsKey('姓名')) {
      return const StudentRosterParseResult(
        rows: [],
        warnings: ['表头缺少「姓名」列'],
      );
    }

    final rows = <StudentRosterRow>[];
    final warnings = <String>[];
    for (var r = headerIndex + 1; r < rawRows.length; r++) {
      final line = rawRows[r];
      String at(String key) {
        final i = colMap[key];
        if (i == null || i >= line.length) return '';
        return line[i].trim();
      }

      final name = at('姓名');
      if (name.isEmpty) continue;
      if (name == '张三' && at('备注').contains('示例')) {
        continue; // 跳过未改的示例行
      }

      rows.add(
        StudentRosterRow(
          name: name,
          studentNo: at('学号'),
          gender: _normalizeGender(at('性别')),
          phone: at('电话'),
          note: at('备注'),
          groupName: at('小组'),
          role: Student.joinRoles(Student.splitRoles(at('班委'))),
          birthday: _normalizeBirthday(at('生日')),
          address: at('家庭住址'),
        ),
      );
    }

    if (rows.isEmpty) {
      warnings.add('没有可导入的数据行');
    }
    return StudentRosterParseResult(rows: rows, warnings: warnings);
  }

  static int _findHeaderRow(List<List<String>> rawRows) {
    final limit = rawRows.length < 10 ? rawRows.length : 10;
    for (var r = 0; r < limit; r++) {
      for (final cell in rawRows[r]) {
        if (_normalizeHeader(cell) == '姓名') return r;
      }
    }
    return -1;
  }

  static String? _normalizeHeader(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (key.isEmpty) return null;
    return _headerAliases[key] ?? _headerAliases[raw.trim()];
  }

  static String _cellToString(CellValue? value) {
    if (value == null) return '';
    return switch (value) {
      TextCellValue(:final value) => value.toString().trim(),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) =>
        value == value.roundToDouble() ? '${value.round()}' : '$value',
      BoolCellValue(:final value) => value ? '是' : '否',
      DateCellValue(:final month, :final day) =>
        '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      DateTimeCellValue(:final month, :final day) =>
        '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      TimeCellValue() => '',
      FormulaCellValue(:final formula) => formula,
    };
  }

  static String _normalizeGender(String raw) {
    final t = raw.trim();
    if (t.isEmpty || t == '未知') return '';
    if (t == '男' || t.toLowerCase() == 'm' || t.toLowerCase() == 'male') {
      return '男';
    }
    if (t == '女' || t.toLowerCase() == 'f' || t.toLowerCase() == 'female') {
      return '女';
    }
    return '';
  }

  static String _normalizeBirthday(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final md = RegExp(r'^(\d{1,2})[-/.月](\d{1,2})').firstMatch(t);
    if (md != null) {
      final m = int.parse(md.group(1)!);
      final d = int.parse(md.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }
    final ymd = RegExp(r'^\d{4}[-/](\d{1,2})[-/](\d{1,2})').firstMatch(t);
    if (ymd != null) {
      final m = int.parse(ymd.group(1)!);
      final d = int.parse(ymd.group(2)!);
      if (m >= 1 && m <= 12 && d >= 1 && d <= 31) {
        return '${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      }
    }
    return t;
  }
}
