import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_timetable_import.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/services/excel_grid.dart';

/// AI 智能导入任意格式课表 Excel：识别 → 预览 → 确认写入。
class AiTimetableImportScreen extends StatefulWidget {
  const AiTimetableImportScreen({
    super.key,
    this.markAsMine = false,
  });

  /// true：跨班写入并标记本人授课；false：写入当前班级课表格子。
  final bool markAsMine;

  static Future<void> push(
    BuildContext context, {
    bool markAsMine = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiTimetableImportScreen(markAsMine: markAsMine),
      ),
    );
  }

  @override
  State<AiTimetableImportScreen> createState() =>
      _AiTimetableImportScreenState();
}

class _AiTimetableImportScreenState extends State<AiTimetableImportScreen> {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  bool _busy = false;
  String? _fileName;
  AiTimetableParseResult? _parsed;
  List<TimetableMatchPreview> _previews = const [];
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

    final ctrl = context.read<ClassController>();
    final classTitles = [
      for (final c in ctrl.classes) c.displayTitle,
    ];

    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.name;
      _parsed = null;
      _previews = const [];
    });

    try {
      final result = await AiTimetableImport(aiCtrl.createService()).parseBytes(
        Uint8List.fromList(bytes),
        fileName: file.name,
        knownClassTitles: classTitles,
      );
      if (!mounted) return;
      final previews = ctrl.previewTimetableRows(result.rows);
      setState(() {
        _parsed = result;
        _previews = previews;
      });
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
      final result = await ctrl.importAiTimetableRows(
        parsed.rows,
        markAsMine: widget.markAsMine,
        extraWarnings: parsed.warnings,
      );
      if (!mounted) return;

      final msg = StringBuffer('写入 ${result.imported} 节');
      if (result.skipped > 0) msg.write('，跳过 ${result.skipped} 节');
      if (result.warnings.isNotEmpty) {
        msg.write('\n');
        msg.write(result.warnings.take(10).join('\n'));
      }

      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.imported > 0 ? '导入完成' : '未能导入'),
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
      if (result.imported > 0) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _weekLabel(int wd) =>
      (wd >= 1 && wd <= 7) ? '周${_weekLabels[wd - 1]}' : '周$wd';

  String _statusLabel(TimetableMatchStatus s) => switch (s) {
        TimetableMatchStatus.ok => '可导入',
        TimetableMatchStatus.classNotFound => '班级未匹配',
        TimetableMatchStatus.noCurrentClass => '未选班级',
      };

  Color _statusColor(TimetableMatchStatus s) => switch (s) {
        TimetableMatchStatus.ok => const Color(0xFF34C759),
        TimetableMatchStatus.classNotFound ||
        TimetableMatchStatus.noCurrentClass =>
          AppTheme.destructive,
      };

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final okCount = _previews.where((p) => p.isOk).length;
    final parsed = _parsed;
    final classTitle = ctrl.currentClass?.displayTitle ?? '未选班级';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('AI 导入课表'),
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
            widget.markAsMine
                ? '支持 Excel / Word / TXT / HTML。列名不必固定。含班级列时写入对应班并标记本人授课。'
                : '支持 Excel / Word / TXT / HTML。列名不必固定。无班级列时写入当前班「$classTitle」。',
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
            label: Text(_busy ? 'AI 识别中…' : '选择课表文件'),
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
                  Text(
                    '布局：${parsed.mapping.layout == AiTimetableLayout.matrix ? '矩阵课表' : '长表'}',
                  ),
                  if (parsed.mapping.className.isNotEmpty)
                    Text('班级：${parsed.mapping.className}'),
                  Text('解析 ${parsed.rows.length} 节 · 可导入 $okCount 节'),
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
              '课程预览',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in _previews.take(100))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_weekLabel(p.row.weekday)} 第${p.row.period}节 · ${p.row.subject}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              p.matchedClass?.displayTitle ??
                                  (p.row.className.isEmpty
                                      ? classTitle
                                      : p.row.className),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.tertiaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _statusLabel(p.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(p.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_previews.length > 100)
              Text(
                '…另有 ${_previews.length - 100} 节未展开',
                style: TextStyle(fontSize: 12, color: AppTheme.quaternaryLabel),
              ),
          ],
        ],
      ),
    );
  }
}
