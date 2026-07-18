import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_import_pipeline.dart';
import 'package:smart_class/services/ai_student_roster_import.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/excel_grid.dart';
import 'package:smart_class/services/student_roster_excel.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/ai_import_file_source.dart';
import 'package:smart_class/widgets/ai_import_mapping_editor.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// AI 智能导入学生花名册：任意表格/照片 → Map→Validate→Repair→Preview→Commit。
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

class _AiStudentImportScreenState extends State<AiStudentImportScreen>
    with AiImportFileSourceMixin {
  bool _busy = false;
  String? _fileName;
  AiStudentRosterParseResult? _parsed;
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
    await importAiFileFromWeChat(fileKindLabel: '学生名单文件');
  }

  @override
  Future<void> onAiImportFile(AiImportFile file) async {
    final aiCtrl = context.read<AiSettingsController>();
    if (!aiCtrl.hasApiKey) return;

    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.fileName;
      _parsed = null;
    });

    try {
      final result = await AiStudentRosterImport(
        aiCtrl.createService(maxTokens: 1200),
      ).parseBytes(
        file.bytes,
        fileName: file.fileName,
      );
      if (!mounted) return;
      setState(() => _parsed = result);
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

  void _reapply(AiStudentRosterMapping mapping) {
    final parsed = _parsed;
    if (parsed == null) return;
    setState(() {
      _parsed = AiStudentRosterImport.applyMapping(
        parsed.grid,
        mapping,
        extraWarnings: const ['已按手动列映射重新提取'],
      );
    });
  }

  bool get _canConfirm {
    final parsed = _parsed;
    if (parsed == null || parsed.rows.isEmpty || _busy) return false;
    return parsed.mappingOk;
  }

  Future<void> _confirmImport() async {
    final parsed = _parsed;
    if (parsed == null || !_canConfirm) return;

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

  Widget _mappingEditor(AiStudentRosterParseResult parsed) {
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

    DropdownMenuItem<int?> optItem(int? i, String text) => DropdownMenuItem(
          value: i,
          child: Text(text, overflow: TextOverflow.ellipsis),
        );

    final nameSamples = AiImportGridHelpers.columnSamples(
      parsed.grid,
      m.headerRowIndex,
      m.nameColumn,
      limit: 5,
    );

    int? safeOpt(int? v) =>
        (v != null && v >= 0 && v < colCount) ? v : null;

    return AiImportMappingCard(
      needsManual: parsed.needsManualMapping,
      errors: parsed.validationErrors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            label: '姓名列',
            value: m.nameColumn.clamp(0, colCount - 1),
            items: [for (var i = 0; i < colCount; i++) colItem(i)],
            onChanged: (v) {
              if (v == null) return;
              _reapply(m.copyWith(nameColumn: v, nameSamples: const []));
            },
            enabled: !_busy,
          ),
          if (nameSamples.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '样例：${nameSamples.join('、')}',
                style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
              ),
            ),
          AiImportColumnDropdown<int?>(
            label: '学号列',
            value: safeOpt(m.studentNoColumn),
            items: [
              optItem(null, '无'),
              for (var i = 0; i < colCount; i++)
                optItem(i, i < labels.length ? labels[i] : '列 $i'),
            ],
            onChanged: (v) => _reapply(
              m.copyWith(studentNoColumn: v, clearStudentNo: v == null),
            ),
            enabled: !_busy,
          ),
          AiImportColumnDropdown<int?>(
            label: '性别列',
            value: safeOpt(m.genderColumn),
            items: [
              optItem(null, '无'),
              for (var i = 0; i < colCount; i++)
                optItem(i, i < labels.length ? labels[i] : '列 $i'),
            ],
            onChanged: (v) =>
                _reapply(m.copyWith(genderColumn: v, clearGender: v == null)),
            enabled: !_busy,
          ),
          AiImportColumnDropdown<int?>(
            label: '电话列',
            value: safeOpt(m.phoneColumn),
            items: [
              optItem(null, '无'),
              for (var i = 0; i < colCount; i++)
                optItem(i, i < labels.length ? labels[i] : '列 $i'),
            ],
            onChanged: (v) =>
                _reapply(m.copyWith(phoneColumn: v, clearPhone: v == null)),
            enabled: !_busy,
          ),
          AiImportColumnDropdown<int?>(
            label: '组别列',
            value: safeOpt(m.groupColumn),
            items: [
              optItem(null, '无'),
              for (var i = 0; i < colCount; i++)
                optItem(i, i < labels.length ? labels[i] : '列 $i'),
            ],
            onChanged: (v) =>
                _reapply(m.copyWith(groupColumn: v, clearGroup: v == null)),
            enabled: !_busy,
          ),
        ],
      ),
    );
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
            hint:
                '导入到「$classTitle」。微信/本机可选表格或照片截图（先本地 OCR 再 AI）。列名不必固定；有学号则更新。',
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
                  Text('解析 ${parsed.rows.length} 人'),
                  if (updateHint.isNotEmpty) Text(updateHint),
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
            if (!parsed.mappingOk) ...[
              const SizedBox(height: 10),
              Text(
                '列映射未通过校验，请先修正姓名列后再确认导入',
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
