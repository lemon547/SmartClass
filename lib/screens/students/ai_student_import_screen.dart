import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_student_roster_import.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/excel_grid.dart';
import 'package:smart_class/services/student_roster_excel.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// AI 智能导入任意格式学生花名册。
class AiStudentImportScreen extends StatefulWidget {
  const AiStudentImportScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiStudentImportScreen()),
    );
  }

  @override
  State<AiStudentImportScreen> createState() => _AiStudentImportScreenState();
}

class _AiStudentImportScreenState extends State<AiStudentImportScreen> {
  bool _busy = false;
  String? _fileName;
  AiStudentRosterParseResult? _parsed;
  String? _error;

  Future<void> _ensureAiKey() async {
    final ai = context.read<AiSettingsController>();
    if (ai.hasApiKey) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('尚未配置 AI'),
        content: const Text('AI 智能导入需要 DeepSeek API Key。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去配置'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
      );
    }
  }

  Future<void> _pickAndParse() async {
    await _ensureAiKey();
    if (!mounted) return;
    final aiCtrl = context.read<AiSettingsController>();
    if (!aiCtrl.hasApiKey) return;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAiImportExtensions,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    if (!mounted) return;

    final file = picked.files.single;
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _error = '无法读取文件');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.name;
      _parsed = null;
    });

    try {
      final result =
          await AiStudentRosterImport(aiCtrl.createService()).parseBytes(
        Uint8List.fromList(bytes),
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() => _parsed = result);
    } on DeepSeekAiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '解析失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmImport() async {
    final parsed = _parsed;
    if (parsed == null || parsed.rows.isEmpty) return;

    setState(() => _busy = true);
    try {
      final ctrl = context.read<ClassController>();
      final byNo = {
        for (final s in ctrl.students)
          if (s.studentNo.trim().isNotEmpty) s.studentNo.trim(): s,
      };
      var willUpdate = 0;
      var willAdd = 0;
      for (final row in parsed.rows) {
        final no = row.studentNo.trim();
        if (no.isNotEmpty && byNo.containsKey(no)) {
          willUpdate++;
        } else {
          willAdd++;
        }
      }

      final result = await ctrl.importStudentRosterRows(
        parsed.rows,
        extraWarnings: parsed.warnings,
      );
      if (!mounted) return;

      final msg = StringBuffer(
        '新增 ${result.added} 人，更新 ${result.updated} 人'
        '（预估新增 $willAdd / 更新 $willUpdate）',
      );
      if (result.warnings.isNotEmpty) {
        msg.write('\n');
        msg.write(result.warnings.take(8).join('\n'));
      }

      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.total > 0 ? '导入完成' : '未能导入'),
          content: Text(msg.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (result.total > 0) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _rowSubtitle(StudentRosterRow row) {
    final parts = <String>[
      if (row.studentNo.isNotEmpty) row.studentNo,
      if (row.gender.isNotEmpty) row.gender,
      if (row.phone.isNotEmpty) row.phone,
      if (row.groupName.isNotEmpty) row.groupName,
      if (row.role.isNotEmpty) row.role,
    ];
    return parts.isEmpty ? '仅姓名' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final classTitle =
        context.watch<ClassController>().currentClass?.displayTitle ?? '当前班级';
    final parsed = _parsed;
    final updateHint = () {
      if (parsed == null) return '';
      final byNo = {
        for (final s in context.read<ClassController>().students)
          if (s.studentNo.trim().isNotEmpty) s.studentNo.trim(): true,
      };
      var u = 0;
      var a = 0;
      for (final r in parsed.rows) {
        final no = r.studentNo.trim();
        if (no.isNotEmpty && byNo.containsKey(no)) {
          u++;
        } else {
          a++;
        }
      }
      return '预计新增 $a 人 · 按学号更新 $u 人';
    }();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('AI 导入学生'),
        actions: [
          if (parsed != null && parsed.rows.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : _confirmImport,
              child: const Text('确认导入'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '支持 Excel / CSV / TXT / Word / HTML。列名不必固定（如「学生姓名」「学籍号」），AI 按语义识别。导入到「$classTitle」。有学号则更新。',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppTheme.secondaryLabel,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _pickAndParse,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(AppIcons.sparkles, size: 18),
            label: Text(_busy ? 'AI 识别中…' : '选择学生表格'),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 10),
            Text(
              '文件：$_fileName',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: AppTheme.destructive, fontSize: 14),
            ),
          ],
          if (parsed != null) ...[
            const SizedBox(height: 20),
            Text(
              '识别结果',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('解析 ${parsed.rows.length} 人'),
                  if (updateHint.isNotEmpty) Text(updateHint),
                ],
              ),
            ),
            if (parsed.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                parsed.warnings.take(6).join('\n'),
                style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '学生预览',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            for (final row in parsed.rows.take(100))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _rowSubtitle(row),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.tertiaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (parsed.rows.length > 100)
              Text(
                '…另有 ${parsed.rows.length - 100} 人未展开',
                style: TextStyle(fontSize: 12, color: AppTheme.quaternaryLabel),
              ),
          ],
        ],
      ),
    );
  }
}
