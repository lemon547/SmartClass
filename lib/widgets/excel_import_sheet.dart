import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smart_class/services/excel_batch_helper.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 手机端统一「导入表格 / 手动添加」底部菜单
///
/// [onManualAdd] 手动添加回调（可选）；[manualAddLabel] 手动添加行标题；
/// [manualAddSubtitle] 手动添加行副标题；[downloadTemplate] 用于弱化区下载模板。
Future<void> showExcelImportActions({
  required BuildContext context,
  required String title,
  required Future<String> Function() downloadTemplate,
  required Future<BatchImportResult> Function(Uint8List bytes, String? fileName)
      importBytes,
  VoidCallback? onManualAdd,
  String manualAddLabel = '手动添加',
  String manualAddSubtitle = '逐条填写',
  String tip = '先下载模板，用手机上的 WPS 或 Excel 填写后，再点「通过表格导入」。',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(AppIcons.upload, color: AppTheme.blue),
                title: const Text('通过表格导入'),
                subtitle: const Text('选择已填好的 xlsx / csv'),
                onTap: () {
                  Navigator.pop(ctx);
                  importExcelFromPhone(context, importBytes);
                },
              ),
              if (onManualAdd != null)
                ListTile(
                  leading: Icon(AppIcons.plus, color: AppTheme.blue),
                  title: Text(manualAddLabel),
                  subtitle: Text(manualAddSubtitle),
                  onTap: () {
                    Navigator.pop(ctx);
                    onManualAdd();
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.secondaryLabel,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    downloadExcelTemplate(context, downloadTemplate);
                  },
                  icon: Icon(AppIcons.download, size: 15,
                      color: AppTheme.secondaryLabel),
                  label: const Text('下载空白模板（用手机 WPS / Excel 填写）'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 生成模板后由用户选择保存位置
Future<void> downloadExcelTemplate(
  BuildContext context,
  Future<String> Function() downloadTemplate,
) async {
  try {
    final saved = await FileExport.saveGenerated(
      downloadTemplate,
      dialogTitle: '保存模板',
    );
    if (!context.mounted) return;
    FileExport.showSavedSnackBar(context, saved);
  } catch (e) {
    FileExport.showErrorSnackBar(context, e);
  }
}

Future<void> importExcelFromPhone(
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
          const SnackBar(content: Text('读不到文件，请换一个再试')),
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
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.imported > 0 ? '导入完成' : '未能导入'),
        content: Text(msg.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('导入失败：$e')),
    );
  }
}
