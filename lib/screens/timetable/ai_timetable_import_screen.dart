import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_import_pipeline.dart';
import 'package:smart_class/services/ai_timetable_import.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/excel_grid.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/ai_import_file_source.dart';
import 'package:smart_class/widgets/ai_import_mapping_editor.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// AI 智能导入课表：任意表格/照片 → Map→Validate→Repair→Preview→Commit。
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

class _AiTimetableImportScreenState extends State<AiTimetableImportScreen>
    with AiImportFileSourceMixin {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  bool _busy = false;
  String? _fileName;
  AiTimetableParseResult? _parsed;
  List<TimetableMatchPreview> _previews = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    initAiImportFileSource();
  }

  @override
  void dispose() {
    disposeAiImportFileSource();
    super.dispose();
  }

  Future<bool> _ensureAiKey() async {
    final ai = context.read<AiSettingsController>();
    if (ai.hasApiKey) return true;
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
    if (!mounted) return false;
    return context.read<AiSettingsController>().hasApiKey;
  }

  Future<void> _startLocal() async {
    if (!await _ensureAiKey()) return;
    if (!mounted) return;
    await pickAiImportLocalFile();
  }

  Future<void> _startWeChat() async {
    if (!await _ensureAiKey()) return;
    if (!mounted) return;
    await importAiFileFromWeChat(fileKindLabel: '课表文件');
  }

  @override
  Future<void> onAiImportFile(AiImportFile file) async {
    final aiCtrl = context.read<AiSettingsController>();
    if (!aiCtrl.hasApiKey) return;

    final ctrl = context.read<ClassController>();
    final classTitles = [
      for (final c in ctrl.classes) c.displayTitle,
    ];

    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.fileName;
      _parsed = null;
      _previews = const [];
    });

    try {
      final result = await AiTimetableImport(
        aiCtrl.createService(maxTokens: 1400),
      ).parseBytes(
        file.bytes,
        fileName: file.fileName,
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
      setState(() => _error = ExcelGrid.friendlyParseError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reapply(AiTimetableMapping mapping) {
    final parsed = _parsed;
    if (parsed == null) return;
    final ctrl = context.read<ClassController>();
    final next = AiTimetableImport.applyMapping(
      parsed.grid,
      mapping,
      extraWarnings: const ['已按手动列映射重新提取'],
    );
    setState(() {
      _parsed = next;
      _previews = ctrl.previewTimetableRows(next.rows);
    });
  }

  bool get _canConfirm {
    final parsed = _parsed;
    if (parsed == null || parsed.rows.isEmpty || _busy) return false;
    if (!parsed.mappingOk) return false;
    final okCount = _previews.where((p) => p.isOk).length;
    return okCount > 0;
  }

  Future<void> _confirmImport() async {
    final parsed = _parsed;
    if (parsed == null || !_canConfirm) return;

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

  Widget _mappingEditor(AiTimetableParseResult parsed) {
    final m = parsed.mapping;
    final labels = AiImportGridHelpers.headerLabels(
      parsed.grid,
      m.headerRowIndex,
    );
    final colCount = parsed.grid.colCount;
    if (colCount == 0) return const SizedBox.shrink();

    DropdownMenuItem<int> colItem(int i) => DropdownMenuItem(
          value: i,
          child: Text(
            i < labels.length ? labels[i] : '列 $i',
            overflow: TextOverflow.ellipsis,
          ),
        );

    return AiImportMappingCard(
      needsManual: parsed.needsManualMapping,
      errors: parsed.validationErrors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiImportColumnDropdown<AiTimetableLayout>(
            label: '布局',
            value: m.layout,
            items: const [
              DropdownMenuItem(
                value: AiTimetableLayout.matrix,
                child: Text('矩阵课表'),
              ),
              DropdownMenuItem(
                value: AiTimetableLayout.list,
                child: Text('长表'),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              _reapply(m.copyWith(layout: v));
            },
            enabled: !_busy,
          ),
          AiImportColumnDropdown<int>(
            label: '表头行',
            value: m.headerRowIndex.clamp(0, parsed.grid.rowCount - 1),
            items: [
              for (var i = 0; i < parsed.grid.rowCount && i < 30; i++)
                DropdownMenuItem(value: i, child: Text('第 $i 行')),
            ],
            onChanged: (v) {
              if (v == null) return;
              _reapply(m.copyWith(headerRowIndex: v));
            },
            enabled: !_busy,
          ),
          AiImportColumnDropdown<int>(
            label: '节次列',
            value: (m.periodColumn ?? 0).clamp(0, colCount - 1),
            items: [for (var i = 0; i < colCount; i++) colItem(i)],
            onChanged: (v) {
              if (v == null) return;
              _reapply(m.copyWith(periodColumn: v));
            },
            enabled: !_busy,
          ),
          if (m.layout == AiTimetableLayout.list) ...[
            AiImportColumnDropdown<int>(
              label: '星期列',
              value: (m.weekdayColumn ?? 0).clamp(0, colCount - 1),
              items: [for (var i = 0; i < colCount; i++) colItem(i)],
              onChanged: (v) {
                if (v == null) return;
                _reapply(m.copyWith(weekdayColumn: v));
              },
              enabled: !_busy,
            ),
            AiImportColumnDropdown<int>(
              label: '科目列',
              value: (m.subjectColumn ?? 0).clamp(0, colCount - 1),
              items: [for (var i = 0; i < colCount; i++) colItem(i)],
              onChanged: (v) {
                if (v == null) return;
                _reapply(m.copyWith(subjectColumn: v));
              },
              enabled: !_busy,
            ),
            AiImportColumnDropdown<int?>(
              label: '班级列',
              value: (m.classColumn != null &&
                      m.classColumn! >= 0 &&
                      m.classColumn! < colCount)
                  ? m.classColumn
                  : null,
              items: [
                const DropdownMenuItem(value: null, child: Text('无')),
                for (var i = 0; i < colCount; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      i < labels.length ? labels[i] : '列 $i',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => _reapply(
                m.copyWith(classColumn: v, clearClassColumn: v == null),
              ),
              enabled: !_busy,
            ),
          ] else ...[
            Text(
              '星期列（矩阵）',
              style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
            ),
            const SizedBox(height: 6),
            for (var wd = 1; wd <= 5; wd++)
              AiImportColumnDropdown<int>(
                label: '周${_weekLabels[wd - 1]}',
                value: (m.weekdayColumns[wd] ?? wd.clamp(0, colCount - 1))
                    .clamp(0, colCount - 1),
                items: [for (var i = 0; i < colCount; i++) colItem(i)],
                onChanged: (v) {
                  if (v == null) return;
                  final next = Map<int, int>.from(m.weekdayColumns);
                  next[wd] = v;
                  _reapply(m.copyWith(weekdayColumns: next));
                },
                enabled: !_busy,
              ),
          ],
        ],
      ),
    );
  }

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
          if (parsed != null)
            TextButton(
              onPressed: _canConfirm ? _confirmImport : null,
              child: const Text('确认导入'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          AiImportSourcePanel(
            busy: _busy,
            awaitingWeChat: awaitingWeChatShare,
            onPickLocal: _startLocal,
            onImportWeChat: _startWeChat,
            onCancelWeChat: cancelAwaitingWeChatShare,
            hint: widget.markAsMine
                ? '支持课表文件或照片（OCR→AI）。含班级列时写入对应班并标记本人授课。'
                : '支持课表文件或照片（OCR→AI）。无班级列时写入当前班「$classTitle」。',
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
            if (parsed.needsManualMapping) ...[
              Text(
                '列映射（必改）',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryLabel,
                ),
              ),
              const SizedBox(height: 8),
              _mappingEditor(parsed),
              const SizedBox(height: 16),
            ],
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
                  if (parsed.repairAttempts > 0)
                    Text(
                      'AI 识别尝试 ${parsed.repairAttempts} 次'
                      '${parsed.mappingOk ? ' · 校验通过' : ' · 待人工校正'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: parsed.mappingOk
                            ? AppTheme.tertiaryLabel
                            : AppTheme.destructive,
                      ),
                    ),
                ],
              ),
            ),
            if (!parsed.needsManualMapping) ...[
              const SizedBox(height: 16),
              Text(
                '列映射',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryLabel,
                ),
              ),
              const SizedBox(height: 8),
              _mappingEditor(parsed),
            ],
            if (!_canConfirm && parsed.rows.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                !parsed.mappingOk
                    ? '列映射未通过校验，请先修正后再确认导入'
                    : '当前没有可导入的课程（班级未匹配或未选班级）',
                style: TextStyle(fontSize: 13, color: AppTheme.destructive),
              ),
            ],
            if (parsed.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                parsed.warnings.take(4).join('\n'),
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
