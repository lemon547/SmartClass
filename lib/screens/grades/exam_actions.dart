import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/ai_exam_import_screen.dart';
import 'package:smart_class/screens/grades/exam_edit_screen.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 考试相关操作（成绩导入导出、资料、编辑删除），供 Hub 与详情页共用。
abstract final class ExamActions {
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> exportFilled(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    try {
      final saved = await FileExport.saveGenerated(
        () => ctrl.exportExamFilledFile(examId),
        dialogTitle: '导出本班成绩',
      );
      if (!context.mounted) return;
      FileExport.showSavedSnackBar(context, saved);
    } catch (e) {
      FileExport.showErrorSnackBar(context, e);
    }
  }

  static Future<void> openEdit(BuildContext context, Exam exam) async {
    final result = await ExamEditScreen.push(context, existing: exam);
    if (result == ExamEditScreen.deletedToken && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  static Future<void> showImportSheet(BuildContext context, Exam exam) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('导入成绩'),
        message: const Text('可含折算/年级排名列；点单元格也可改分'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              downloadTemplate(context, exam.id);
            },
            child: const Text('下载空白模板'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              importExcel(context, exam.id);
            },
            child: const Text('导入标准 Excel'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              AiExamImportScreen.push(context, examId: exam.id);
            },
            child: const Text('AI 智能导入'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  static Future<void> downloadTemplate(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    try {
      final saved = await FileExport.saveGenerated(
        () => ctrl.exportExamTemplateFile(examId),
        dialogTitle: '保存成绩导入模板',
      );
      if (!context.mounted) return;
      FileExport.showSavedSnackBar(context, saved);
    } catch (e) {
      FileExport.showErrorSnackBar(context, e);
    }
  }

  static Future<void> importExcel(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
        return;
      }

      final result = await ctrl.importExamScoresFromBytes(
        examId,
        bytes,
        fileName: file.name,
      );
      if (!context.mounted) return;
      final msg = StringBuffer('匹配 ${result.matched} 人');
      if (result.skipped > 0) msg.write('，跳过 ${result.skipped} 人');
      if (result.warnings.isNotEmpty) {
        msg.write('\n');
        msg.write(result.warnings.take(8).join('\n'));
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.matched > 0 ? '导入完成' : '未能导入'),
          content: Text(msg.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
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

  static Future<void> deleteExam(BuildContext context, Exam exam) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${exam.title}」？'),
        content: const Text('成绩与考试资料将一并删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<ClassController>().deleteExam(exam.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  static Future<void> pickExamFiles(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    var ok = 0;
    for (final f in result.files) {
      final path = f.path;
      if (path == null || path.isEmpty) continue;
      await ctrl.attachExamFile(
        examId: examId,
        sourcePath: path,
        originalName: f.name,
      );
      ok++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok == 0 ? '未能读取所选文件' : '已存档 $ok 个文件')),
      );
    }
  }

  static Future<void> openExamFile(BuildContext context, ExamFile file) async {
    final path = await context.read<ClassController>().examFilePath(file);
    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isEmpty ? '无法打开文件' : res.message,
          ),
        ),
      );
    }
  }

  static Future<void> deleteExamFile(BuildContext context, ExamFile file) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('删除该资料？'),
        content: Text(file.fileName),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(d, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().deleteExamFile(file);
    }
  }

  static Widget filesSection(
    BuildContext context,
    ClassController ctrl,
    Exam exam,
  ) {
    final files = ctrl.filesOfExam(exam.id);
    return GroupedSection(
      header: '考试资料',
      footer: files.isEmpty ? '可上传试卷、答题卡、扫描件等' : '点文件打开；长按删除',
      children: [
        GroupedTile(
          title: '上传文件',
          leading: Icon(AppIcons.upload, color: AppTheme.blue),
          onTap: () => pickExamFiles(context, exam.id),
        ),
        for (final f in files)
          GroupedTile(
            title: f.fileName,
            subtitle: formatSize(f.sizeBytes),
            leading: Icon(AppIcons.file, color: AppTheme.blue),
            onTap: () => openExamFile(context, f),
            onLongPress: () => deleteExamFile(context, f),
          ),
      ],
    );
  }
}
