import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_exam_score_import.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/exam_score_excel.dart';
import 'package:smart_class/services/excel_grid.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:uuid/uuid.dart';

/// AI 智能导入任意格式成绩 Excel：识别 → 预览 → 确认写入。
class AiExamImportScreen extends StatefulWidget {
  const AiExamImportScreen({super.key, this.examId});

  /// 若指定，则导入到该考试；否则可根据 AI 识别新建考试。
  final String? examId;

  static Future<void> push(BuildContext context, {String? examId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AiExamImportScreen(examId: examId)),
    );
  }

  @override
  State<AiExamImportScreen> createState() => _AiExamImportScreenState();
}

class _AiExamImportScreenState extends State<AiExamImportScreen> {
  bool _busy = false;
  String? _fileName;
  AiGradeParseResult? _parsed;
  List<ExamScoreMatchPreview> _previews = const [];
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
    final exam = widget.examId == null ? null : ctrl.examById(widget.examId!);
    final knownNames = [for (final s in ctrl.students) s.name];
    final preferred = exam?.subjects ?? const <String>[];

    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.name;
      _parsed = null;
      _previews = const [];
    });

    try {
      // 导入用 Flash 即可；略加大输出上限保证 JSON 完整
      final result = await AiExamScoreImport(
        aiCtrl.createService(maxTokens: 1200),
      ).parseBytes(
        Uint8List.fromList(bytes),
        fileName: file.name,
        knownStudentNames: knownNames,
        preferredSubjects: preferred,
      );
      if (!mounted) return;
      final previews = ctrl.previewExamScoreRows(result.rows);
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
      final mapping = parsed.mapping;
      late final String targetExamId;

      final existingId = widget.examId;
      if (existingId == null) {
        targetExamId = const Uuid().v4();
        final title = mapping.examTitle.isNotEmpty
            ? mapping.examTitle
            : (_fileName?.replaceAll(
                  RegExp(r'\.(xlsx|xls|csv)$', caseSensitive: false),
                  '',
                ) ??
                '成绩导入');
        final date = _normalizeDate(mapping.examDate) ??
            DateFormat('yyyy-MM-dd').format(DateTime.now());
        final subjects = mapping.subjects.isNotEmpty
            ? mapping.subjects
            : _subjectsFromRows(parsed.rows);
        await ctrl.saveExam(
          id: targetExamId,
          title: title,
          category: mapping.category.isEmpty ? '月考' : mapping.category,
          examDate: date,
          subjects: subjects,
        );
      } else {
        targetExamId = existingId;
        final exam = ctrl.examById(existingId);
        if (exam != null && mapping.subjects.isNotEmpty) {
          final merged = [...exam.subjects];
          for (final s in mapping.subjects) {
            if (!merged.contains(s)) merged.add(s);
          }
          if (merged.length != exam.subjects.length) {
            await ctrl.saveExam(
              id: exam.id,
              title: exam.title,
              category: exam.category,
              examDate: exam.examDate,
              subjects: merged,
              fullScore: exam.fullScore,
              passScore: exam.passScore,
              note: exam.note,
            );
          }
        }
      }

      final result = await ctrl.importExamScoreRows(
        targetExamId,
        parsed.rows,
        extraWarnings: parsed.warnings,
      );
      if (!mounted) return;

      final msg = StringBuffer('匹配写入 ${result.matched} 人');
      if (result.skipped > 0) msg.write('，跳过 ${result.skipped} 人');
      if (result.warnings.isNotEmpty) {
        msg.write('\n');
        msg.write(result.warnings.take(10).join('\n'));
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
      if (!mounted) return;
      if (result.matched > 0) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String? _normalizeDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})').firstMatch(t);
    if (m != null) {
      final y = m.group(1)!;
      final mo = m.group(2)!.padLeft(2, '0');
      final d = m.group(3)!.padLeft(2, '0');
      return '$y-$mo-$d';
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return t;
    return null;
  }

  static List<String> _subjectsFromRows(List<ExamScoreRow> rows) {
    final set = <String>{};
    for (final r in rows) {
      set.addAll(r.scores.keys);
    }
    return set.toList();
  }

  String _statusLabel(ExamScoreMatchStatus s) => switch (s) {
        ExamScoreMatchStatus.matchedByNo => '学号匹配',
        ExamScoreMatchStatus.matchedByName => '姓名匹配',
        ExamScoreMatchStatus.ambiguousName => '重名',
        ExamScoreMatchStatus.unmatched => '未匹配',
      };

  Color _statusColor(ExamScoreMatchStatus s) => switch (s) {
        ExamScoreMatchStatus.matchedByNo ||
        ExamScoreMatchStatus.matchedByName =>
          const Color(0xFF34C759),
        ExamScoreMatchStatus.ambiguousName => const Color(0xFFFF9500),
        ExamScoreMatchStatus.unmatched => AppTheme.destructive,
      };

  @override
  Widget build(BuildContext context) {
    final exam = widget.examId == null
        ? null
        : context.watch<ClassController>().examById(widget.examId!);
    final matched =
        _previews.where((p) => p.isMatched).length;
    final parsed = _parsed;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('AI 智能导入'),
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
            exam == null
                ? '支持 Excel / Word / TXT / HTML。列名不必固定，AI 按语义认姓名与科目，并可新建考试。'
                : '导入到「${exam.title}」。列名不必固定，AI 会尽量对齐科目。',
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
            label: Text(_busy ? 'AI 识别中…' : '选择成绩表格'),
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
                    '考试：${parsed.mapping.examTitle.isEmpty ? '（沿用当前/文件名）' : parsed.mapping.examTitle}',
                  ),
                  if (parsed.mapping.category.isNotEmpty)
                    Text('类别：${parsed.mapping.category}'),
                  if (parsed.mapping.examDate.isNotEmpty)
                    Text('日期：${parsed.mapping.examDate}'),
                  Text(
                    '科目：${parsed.mapping.subjects.isEmpty ? '—' : parsed.mapping.subjects.join('、')}',
                  ),
                  Text('解析 ${parsed.rows.length} 行 · 可匹配 $matched 人'),
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
              '学生匹配预览',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryLabel,
              ),
            ),
            const SizedBox(height: 8),
            for (final p in _previews.take(80))
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
                              p.row.name +
                                  (p.row.studentNo.isEmpty
                                      ? ''
                                      : ' · ${p.row.studentNo}'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              p.row.scores.entries
                                  .map((e) =>
                                      '${e.key} ${e.value == e.value.roundToDouble() ? e.value.round() : e.value}')
                                  .join('  '),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.tertiaryLabel,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
            if (_previews.length > 80)
              Text(
                '…另有 ${_previews.length - 80} 行未展开',
                style: TextStyle(fontSize: 12, color: AppTheme.quaternaryLabel),
              ),
          ],
        ],
      ),
    );
  }
}
