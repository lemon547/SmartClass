import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:smart_class/models/models.dart';
import 'package:smart_class/services/batch_excels.dart';

/// 工作留痕导出包：纯 Excel 台账 + 可选附件原文件（ZIP）。
/// Excel 仅含类别/标题/内容/日期；附件按「附件/序号_日期_标题/」存放，文件名与实体一致。
abstract final class WorkLogExportPack {
  static Future<Uint8List> buildZip({
    required List<WorkLog> logs,
    required Map<String, List<WorkLogAttachment>> attachmentsByLog,
    required Future<String> Function(WorkLogAttachment item) absolutePathOf,
  }) async {
    final archive = Archive();

    for (var i = 0; i < logs.length; i++) {
      final w = logs[i];
      final atts = attachmentsByLog[w.id] ?? const <WorkLogAttachment>[];
      if (atts.isEmpty) continue;

      final folder = _safeFolderName(
        index: i + 1,
        date: w.date,
        title: w.title,
      );

      for (var j = 0; j < atts.length; j++) {
        final a = atts[j];
        final srcPath = await absolutePathOf(a);
        final src = File(srcPath);
        if (!await src.exists()) continue;
        final fileName = _safeFileName(
          index: j + 1,
          kind: a.kind,
          original: a.fileName,
        );
        final bytes = await src.readAsBytes();
        archive.addFile(
          ArchiveFile(
            '附件/$folder/$fileName',
            bytes.length,
            bytes,
          ),
        );
      }
    }

    final excelBytes = WorkLogBatchExcel.exportRows(logs);
    archive.addFile(
      ArchiveFile('工作留痕.xlsx', excelBytes.length, excelBytes),
    );

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw StateError('无法打包工作留痕附件');
    return Uint8List.fromList(encoded);
  }

  static String _safeFolderName({
    required int index,
    required String date,
    required String title,
  }) {
    final t = title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final short = t.length > 24 ? t.substring(0, 24) : t;
    final prefix = index.toString().padLeft(2, '0');
    final d = date.isEmpty ? '无日期' : date;
    return '${prefix}_${d}_$short';
  }

  static String _safeFileName({
    required int index,
    required WorkLogMediaKind kind,
    required String original,
  }) {
    final base = p.basename(original).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final n = index.toString().padLeft(2, '0');
    return '${n}_${kind.label}_$base';
  }
}
