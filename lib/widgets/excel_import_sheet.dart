import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_class/services/excel_batch_helper.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 统一「下载示例表格 / 导入 Excel」操作
Future<void> showExcelImportActions({
  required BuildContext context,
  required String title,
  required Future<String> Function() downloadTemplate,
  required Future<BatchImportResult> Function(Uint8List bytes, String? fileName)
      importBytes,
}) async {
  await showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text('$title Excel'),
      content: const Text('可用 WPS / Excel 编辑后导入'),
      actions: [
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(ctx);
            _download(context, downloadTemplate);
          },
          child: const Text('下载示例表格'),
        ),
        CupertinoDialogAction(
          onPressed: () {
            Navigator.pop(ctx);
            _import(context, importBytes);
          },
          child: const Text('导入 Excel'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ],
    ),
  );
}

Future<void> _download(
  BuildContext context,
  Future<String> Function() downloadTemplate,
) async {
  try {
    final path = await downloadTemplate();
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('示例表格已生成'),
        content: Text('可用 WPS 或 Excel 打开填写。\n\n$path\n\n路径已复制到剪贴板。'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('生成失败：$e')),
    );
  }
}

Future<void> _import(
  BuildContext context,
  Future<BatchImportResult> Function(Uint8List bytes, String? fileName)
      importBytes,
) async {
  try {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件内容')),
        );
      }
      return;
    }
    final result = await importBytes(Uint8List.fromList(bytes), f.name);
    if (!context.mounted) return;
    final msg = StringBuffer('成功导入 ${result.imported} 条');
    if (result.skipped > 0) msg.write('，跳过 ${result.skipped} 条');
    if (result.warnings.isNotEmpty) {
      msg.write('\n${result.warnings.take(3).join('\n')}');
      if (result.warnings.length > 3) {
        msg.write('\n…共 ${result.warnings.length} 条提示');
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.toString()),
        backgroundColor:
            result.imported == 0 ? AppTheme.destructive : null,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入失败：$e')),
    );
  }
}
