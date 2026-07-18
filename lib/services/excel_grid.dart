import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:smart_class/services/image_ocr.dart';

/// 把常见表格类文件转成二维文本，供 AI 识别。
/// 可解析：xlsx / xls / csv / tsv / txt / docx / html；
/// 图片（jpg/png/webp 等）先经本地免费 OCR 抽文字，再按表格文本处理。
class ExcelGrid {
  const ExcelGrid({
    required this.sheetName,
    required this.rows,
  });

  final String sheetName;
  final List<List<String>> rows;

  int get rowCount => rows.length;
  int get colCount =>
      rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);

  String toNumberedTsv({int maxRows = 60, int maxCols = 30}) {
    final buf = StringBuffer();
    final limit = rows.length < maxRows ? rows.length : maxRows;
    for (var r = 0; r < limit; r++) {
      final line = rows[r];
      final cells = <String>[];
      final cLimit = line.length < maxCols ? line.length : maxCols;
      for (var c = 0; c < cLimit; c++) {
        cells.add(_escape(line[c]));
      }
      if (line.length > maxCols) cells.add('…');
      buf.writeln('R$r\t${cells.join('\t')}');
    }
    if (rows.length > maxRows) {
      buf.writeln('…共 ${rows.length} 行，仅展示前 $maxRows 行');
    }
    return buf.toString();
  }

  static String _escape(String s) {
    final t = s.replaceAll('\t', ' ').replaceAll('\n', ' ').trim();
    return t;
  }

  /// 异步入口：图片会走 OCR；其余与 [fromBytes] 相同。
  static Future<ExcelGrid> fromBytesAsync(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final lower = (fileName ?? '').toLowerCase();
    final kind = _detectKind(bytes, lower);
    if (kind == _FileKind.image) {
      final tsv = await ImageOcr.extractTableTsv(bytes, fileName: fileName);
      return ExcelGrid(
        sheetName: '图片OCR',
        rows: _clean([
          for (final line in _lines(tsv))
            line.split('\t').map((e) => e.trim()).toList(),
        ]),
      );
    }
    return fromBytes(bytes, fileName: fileName);
  }

  /// 按扩展名 / 文件头识别格式并解析（同步；图片请用 [fromBytesAsync]）。
  static ExcelGrid fromBytes(Uint8List bytes, {String? fileName}) {
    final lower = (fileName ?? '').toLowerCase();
    final kind = _detectKind(bytes, lower);

    switch (kind) {
      case _FileKind.docx:
        return _fromDocx(bytes);
      case _FileKind.html:
        return _fromHtml(utf8.decode(bytes, allowMalformed: true));
      case _FileKind.textTable:
        return _fromPlainText(utf8.decode(bytes, allowMalformed: true), lower);
      case _FileKind.excel:
        return _fromExcel(bytes);
      case _FileKind.image:
        throw const FormatException(
          '检测到图片，请通过 AI 导入入口解析（需先 OCR 抽文字）。',
        );
      case _FileKind.unsupported:
        final hint = lower.isEmpty ? '该文件' : fileName;
        throw FormatException(
          '暂不支持解析「$hint」。\n'
          '可用：Excel / CSV / TXT / Word(.docx) / HTML / 照片截图。\n'
          'PDF、旧版 .doc 暂不支持。',
        );
    }
  }

  static _FileKind _detectKind(Uint8List bytes, String lower) {
    if (lower.endsWith('.docx')) return _FileKind.docx;
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return _FileKind.html;
    if (lower.endsWith('.txt') || lower.endsWith('.tsv')) {
      return _FileKind.textTable;
    }
    if (lower.endsWith('.csv')) return _FileKind.textTable;
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) {
      return _FileKind.excel;
    }
    if (_isImageName(lower) || _isImageBytes(bytes)) {
      return _FileKind.image;
    }
    // 无扩展名：嗅探
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      // zip: xlsx 或 docx
      try {
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);
        final names = archive.files.map((f) => f.name).toSet();
        if (names.any((n) => n.startsWith('word/'))) return _FileKind.docx;
        if (names.any((n) => n.startsWith('xl/'))) return _FileKind.excel;
      } catch (_) {}
      return _FileKind.excel;
    }
    final head = utf8.decode(
      bytes.take(bytes.length < 256 ? bytes.length : 256).toList(),
      allowMalformed: true,
    );
    final headLower = head.toLowerCase();
    if (headLower.contains('<table') || headLower.contains('<html')) {
      return _FileKind.html;
    }
    if (_looksLikeTextTable(head)) return _FileKind.textTable;
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return _FileKind.unsupported; // pdf
    }
    return _FileKind.unsupported;
  }

  static bool _isImageName(String lower) {
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  static bool _isImageBytes(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return true; // jpeg
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true; // png
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true; // webp
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return true; // bmp
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return true; // gif
    }
    return false;
  }

  static bool _looksLikeTextTable(String head) {
    return head.contains(',') ||
        head.contains('\t') ||
        head.contains('姓名') ||
        head.contains('学号') ||
        head.contains('星期一') ||
        head.contains('语文');
  }

  static ExcelGrid _fromPlainText(String text, String lower) {
    final rows = lower.endsWith('.tsv')
        ? [
            for (final line in _lines(text))
              line.split('\t').map((e) => e.trim()).toList(),
          ]
        : _csvToRows(text);
    return ExcelGrid(
      sheetName: lower.endsWith('.tsv')
          ? 'TSV'
          : (lower.endsWith('.txt') ? 'TXT' : 'CSV'),
      rows: _clean(rows),
    );
  }

  static ExcelGrid _fromHtml(String html) {
    final tables = <List<List<String>>>[];
    final tableRe = RegExp(
      r'<table\b[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final m in tableRe.allMatches(html)) {
      final body = m.group(1) ?? '';
      final rows = <List<String>>[];
      final trRe = RegExp(
        r'<tr\b[^>]*>(.*?)</tr>',
        caseSensitive: false,
        dotAll: true,
      );
      for (final tr in trRe.allMatches(body)) {
        final rowHtml = tr.group(1) ?? '';
        final cells = <String>[];
        final tdRe = RegExp(
          r'<t[dh]\b[^>]*>(.*?)</t[dh]>',
          caseSensitive: false,
          dotAll: true,
        );
        for (final td in tdRe.allMatches(rowHtml)) {
          cells.add(_stripHtml(td.group(1) ?? ''));
        }
        if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
      }
      if (rows.isNotEmpty) tables.add(rows);
    }
    if (tables.isEmpty) {
      return _fromPlainText(_stripHtml(html), '.txt');
    }
    tables.sort((a, b) => b.length.compareTo(a.length));
    return ExcelGrid(sheetName: 'HTML', rows: _clean(tables.first));
  }

  static ExcelGrid _fromDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);
    ArchiveFile? doc;
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        doc = f;
        break;
      }
    }
    if (doc == null || !doc.isFile) {
      throw const FormatException('Word 文件中找不到正文（document.xml）');
    }
    final xml = utf8.decode(doc.content as List<int>, allowMalformed: true);
    final tables = <List<List<String>>>[];
    final tblRe = RegExp(r'<w:tbl\b[^>]*>(.*?)</w:tbl>', dotAll: true);
    for (final m in tblRe.allMatches(xml)) {
      final tbl = m.group(1) ?? '';
      final rows = <List<String>>[];
      final trRe = RegExp(r'<w:tr\b[^>]*>(.*?)</w:tr>', dotAll: true);
      for (final tr in trRe.allMatches(tbl)) {
        final rowXml = tr.group(1) ?? '';
        final cells = <String>[];
        final tcRe = RegExp(r'<w:tc\b[^>]*>(.*?)</w:tc>', dotAll: true);
        for (final tc in tcRe.allMatches(rowXml)) {
          cells.add(_docxCellText(tc.group(1) ?? ''));
        }
        if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
      }
      if (rows.isNotEmpty) tables.add(rows);
    }

    if (tables.isNotEmpty) {
      tables.sort((a, b) => b.length.compareTo(a.length));
      return ExcelGrid(sheetName: 'Word表格', rows: _clean(tables.first));
    }

    final paras = <String>[];
    final pRe = RegExp(r'<w:p\b[^>]*>(.*?)</w:p>', dotAll: true);
    for (final m in pRe.allMatches(xml)) {
      final t = _docxCellText(m.group(1) ?? '');
      if (t.isNotEmpty) paras.add(t);
    }
    if (paras.isEmpty) {
      throw const FormatException('Word 中未找到表格或可用文字');
    }
    return ExcelGrid(
      sheetName: 'Word文本',
      rows: [
        for (final p in paras) [p],
      ],
    );
  }

  static String _docxCellText(String xml) {
    final parts = <String>[];
    for (final m in RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true)
        .allMatches(xml)) {
      parts.add(_unescapeXml(m.group(1) ?? ''));
    }
    return parts.join().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _unescapeXml(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");

  static String _stripHtml(String s) {
    var t = s
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static ExcelGrid _fromExcel(Uint8List bytes) {
    try {
      return _sheetToGrid(decodeExcelBytes(bytes));
    } on FormatException {
      rethrow;
    } catch (e) {
      if (_isNumFmtIdBug(e)) {
        throw const FormatException(
          '该 Excel 的数字格式较特殊，当前无法直接解析。\n'
          '请用 WPS/Excel「另存为」标准 .xlsx，或导出 CSV 后再导入。',
        );
      }
      rethrow;
    }
  }

  /// 安全解码 xlsx：自动兼容 WPS/Office 把内置 numFmtId 写进自定义区的文件。
  static Excel decodeExcelBytes(Uint8List bytes) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (e) {
      if (!_isNumFmtIdBug(e)) rethrow;
      return Excel.decodeBytes(_sanitizeXlsxNumFmts(bytes));
    }
  }

  static bool _isNumFmtIdBug(Object e) {
    final s = e.toString();
    return s.contains('numFmtId') || s.contains('NumFmt');
  }

  static ExcelGrid _sheetToGrid(Excel excel) {
    Sheet? sheet;
    const preferred = <String>[
      '课表',
      '课程表',
      '教师课表',
      '班级课表',
      '学生',
      '花名册',
      '名单',
      '档案',
      '成绩',
      '分数',
      '成绩单',
      'score',
    ];
    for (final key in preferred) {
      for (final name in excel.tables.keys) {
        if (name.contains(key) || name.toLowerCase().contains(key)) {
          sheet = excel.tables[name];
          break;
        }
      }
      if (sheet != null) break;
    }
    sheet ??= excel.tables.values.isEmpty ? null : excel.tables.values.first;
    if (sheet == null) {
      return const ExcelGrid(sheetName: '', rows: []);
    }
    final raw = <List<String>>[];
    for (final row in sheet.rows) {
      raw.add([for (final c in row) _cellToString(c?.value)]);
    }
    return ExcelGrid(sheetName: sheet.sheetName, rows: _clean(raw));
  }

  /// 去掉 styles.xml 里非法的「自定义 numFmtId < 164」声明（多为内置格式被重复写出）。
  static Uint8List _sanitizeXlsxNumFmts(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      ArchiveFile? styles;
      for (final f in archive.files) {
        if (f.name == 'xl/styles.xml') {
          styles = f;
          break;
        }
      }
      if (styles == null || !styles.isFile) return bytes;

      final content = styles.content;
      final raw = content is List<int>
          ? content
          : (content as Uint8List).toList();
      var xml = utf8.decode(raw, allowMalformed: true);
      final before = xml;
      // <numFmt ... numFmtId="41" ... /> 或属性顺序不同
      xml = xml.replaceAllMapped(
        RegExp(
          r'<numFmt\b([^>]*?)\s*/>',
          caseSensitive: false,
        ),
        (m) {
          final attrs = m.group(1) ?? '';
          final idMatch =
              RegExp(r'numFmtId\s*=\s*"(\d+)"', caseSensitive: false)
                  .firstMatch(attrs);
          final id = int.tryParse(idMatch?.group(1) ?? '') ?? 999;
          if (id < 164) return '';
          return m.group(0)!;
        },
      );
      if (xml == before) return bytes;

      // 修正 numFmts count（有则更新，无则忽略）
      final remaining = RegExp(
        r'<numFmt\b',
        caseSensitive: false,
      ).allMatches(xml).length;
      xml = xml.replaceFirstMapped(
        RegExp(r'(<numFmts\b[^>]*\bcount\s*=\s*")(\d+)(")', caseSensitive: false),
        (m) => '${m.group(1)}$remaining${m.group(3)}',
      );

      final out = Archive();
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (f.name == styles.name) {
          final nb = utf8.encode(xml);
          out.addFile(ArchiveFile(f.name, nb.length, nb));
        } else {
          final data = f.content;
          final list = data is List<int> ? data : (data as Uint8List).toList();
          out.addFile(ArchiveFile(f.name, list.length, list));
        }
      }
      final encoded = ZipEncoder().encode(out);
      if (encoded == null || encoded.isEmpty) return bytes;
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  static List<List<String>> _clean(List<List<String>> raw) => [
        for (final r in raw)
          if (r.any((c) => c.trim().isNotEmpty)) r,
      ];

  static Iterable<String> _lines(String text) => text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .where((l) => l.trim().isNotEmpty);

  static List<List<String>> _csvToRows(String text) {
    return [for (final line in _lines(text)) _splitCsvLine(line)];
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

  /// 把解析异常收成用户可读短句（避免把库内部 Exception 原文甩到界面）。
  static String friendlyParseError(Object e) {
    if (e is FormatException) {
      final m = e.message.trim();
      return m.isEmpty ? '文件格式无法识别' : m;
    }
    final s = e.toString();
    if (s.contains('numFmtId') || s.contains('NumFmt')) {
      return '该 Excel 数字格式较特殊。请另存为标准 xlsx，或导出 CSV 后再试。';
    }
    final cleaned = s
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^FormatException:\s*'), '')
        .trim();
    return cleaned.isEmpty ? '解析失败' : cleaned;
  }
}

enum _FileKind { excel, textTable, docx, html, image, unsupported }
