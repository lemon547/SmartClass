import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// 手机端导出：调起系统「另存为」，由用户选择保存位置（Android SAF）。
abstract final class FileExport {
  /// 返回保存后的完整路径；用户取消时返回 null。
  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String dialogTitle = '选择保存位置',
  }) async {
    final ext = p.extension(fileName).replaceFirst('.', '');
    final path = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: ext.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: ext.isEmpty ? null : [ext],
      bytes: bytes,
    );
    if (path == null || path.isEmpty) return null;
    return path;
  }

  /// 将已生成的临时文件另存到用户选择的位置。
  static Future<String?> saveFromPath({
    required String sourcePath,
    String? fileName,
    String dialogTitle = '选择保存位置',
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('文件不存在');
    }
    final name = fileName ?? p.basename(sourcePath);
    return saveBytes(
      bytes: await src.readAsBytes(),
      fileName: name,
      dialogTitle: dialogTitle,
    );
  }

  /// 生成到应用临时目录后，再让用户选择保存位置。
  static Future<String?> saveGenerated(
    Future<String> Function() generateToTempPath, {
    String? fileName,
    String dialogTitle = '选择保存位置',
  }) async {
    final temp = await generateToTempPath();
    return saveFromPath(
      sourcePath: temp,
      fileName: fileName ?? p.basename(temp),
      dialogTitle: dialogTitle,
    );
  }

  static void showSavedSnackBar(BuildContext context, String? savedPath) {
    if (!context.mounted || savedPath == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存：${p.basename(savedPath)}')),
    );
  }

  static void showErrorSnackBar(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('保存失败：$error')),
    );
  }
}
