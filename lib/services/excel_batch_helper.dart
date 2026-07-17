import 'dart:typed_data';

import 'package:excel/excel.dart';

/// 通用 Excel 示例表 / 解析辅助（WPS、Microsoft Excel）
abstract final class ExcelBatchHelper {
  static Uint8List buildTemplate({
    required String sheetName,
    required List<String> headers,
    required List<List<String>> sampleRows,
    required List<(String col, String tip)> tips,
  }) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    sheet.appendRow([for (final h in headers) TextCellValue(h)]);
    for (final row in sampleRows) {
      sheet.appendRow([for (final c in row) TextCellValue(c)]);
    }
    for (var i = 0; i < headers.length; i++) {
      sheet.setColumnWidth(i, 14);
    }

    final tipSheet = excel['填写说明'];
    tipSheet.appendRow([TextCellValue('栏目'), TextCellValue('说明')]);
    for (final t in tips) {
      tipSheet.appendRow([TextCellValue(t.$1), TextCellValue(t.$2)]);
    }
    tipSheet.appendRow([
      TextCellValue('提示'),
      TextCellValue('用 WPS 或 Excel 编辑「$sheetName」表后，在 App 中选择「导入 Excel」。示例行可删。'),
    ]);

    final bytes = excel.encode();
    if (bytes == null) throw StateError('无法生成示例表格');
    return Uint8List.fromList(bytes);
  }

  static Sheet? pickSheet(Excel excel, {String? preferred}) {
    if (preferred != null && excel.sheets.containsKey(preferred)) {
      return excel[preferred];
    }
    for (final name in excel.tables.keys) {
      if (name == '填写说明') continue;
      return excel[name];
    }
    return null;
  }

  static String cellText(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final v = cell.value!;
    return switch (v) {
      TextCellValue(:final value) => value.toString().trim(),
      IntCellValue(:final value) => '$value',
      DoubleCellValue(:final value) =>
        value == value.roundToDouble() ? '${value.toInt()}' : '$value',
      DateCellValue(:final year, :final month, :final day) =>
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      _ => '$v'.trim(),
    };
  }

  /// 返回表头列名 -> 列索引（已按 aliases 归一化）
  static Map<String, int> mapHeaders(
    Sheet sheet,
    Map<String, String> aliases,
  ) {
    final map = <String, int>{};
    if (sheet.maxRows == 0) return map;
    final row = sheet.row(0);
    for (var i = 0; i < row.length; i++) {
      final raw = cellText(row[i]).trim();
      if (raw.isEmpty) continue;
      final lower = raw.toLowerCase().replaceAll(' ', '');
      final key = aliases[raw] ?? aliases[lower] ?? raw;
      map.putIfAbsent(key, () => i);
    }
    return map;
  }

  static String at(List<Data?> row, Map<String, int> cols, String key) {
    final i = cols[key];
    if (i == null || i >= row.length) return '';
    return cellText(row[i]);
  }

  static bool isSampleMarker(String text) =>
      text.contains('示例') || text.contains('可删除');

  /// 一～日 或 1～7
  static int? parseWeekday(String raw) {
    final t = raw.trim();
    final n = int.tryParse(t);
    if (n != null && n >= 1 && n <= 7) return n;
    return switch (t.replaceAll('周', '').replaceAll('星期', '')) {
      '一' || '1' => 1,
      '二' || '2' => 2,
      '三' || '3' => 3,
      '四' || '4' => 4,
      '五' || '5' => 5,
      '六' || '6' => 6,
      '日' || '天' || '七' || '7' => 7,
      _ => null,
    };
  }
}

class BatchImportResult {
  const BatchImportResult({
    required this.imported,
    this.skipped = 0,
    this.warnings = const [],
  });

  final int imported;
  final int skipped;
  final List<String> warnings;
}
