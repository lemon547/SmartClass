import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:smart_class/services/excel_batch_helper.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 手机端统一「下载模板 / 导入表格」底部菜单
Future<void> showExcelImportActions({
  required BuildContext context,
  required String title,
  required Future<String> Function() downloadTemplate,
  required Future<BatchImportResult> Function(Uint8List bytes, String? fileName)
      importBytes,
  String tip = '先下载模板，用手机上的 WPS 或 Excel 填写后，再点「从手机导入」。',
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title · 表格',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tip,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(AppIcons.download, color: AppTheme.blue),
                title: const Text('下载空白模板'),
                subtitle: const Text('保存到手机，可用 WPS 打开'),
                onTap: () {
                  Navigator.pop(ctx);
                  downloadExcelTemplate(context, downloadTemplate);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.upload, color: AppTheme.blue),
                title: const Text('从手机导入'),
                subtitle: const Text('选择已填好的 xlsx / csv'),
                onTap: () {
                  Navigator.pop(ctx);
                  importExcelFromPhone(context, importBytes);
                },
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    },
  );
}

/// 生成模板并引导用本机 App 打开（适合手机，不只弹路径）
Future<void> downloadExcelTemplate(
  BuildContext context,
  Future<String> Function() downloadTemplate,
) async {
  try {
    final path = await downloadTemplate();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('模板已保存到本机'),
                  subtitle: Text(
                    path,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(AppIcons.openFile, color: AppTheme.blue),
                  title: const Text('用表格软件打开'),
                  subtitle: const Text('推荐 WPS、Excel'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final res = await OpenFilex.open(path);
                    if (!context.mounted) return;
                    if (res.type != ResultType.done) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            res.message.isNotEmpty
                                ? res.message
                                : '打不开文件，请用文件管理器查找',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.copy, color: AppTheme.blue),
                  title: const Text('复制文件路径'),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: path));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('路径已复制')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('生成失败：$e')),
    );
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
