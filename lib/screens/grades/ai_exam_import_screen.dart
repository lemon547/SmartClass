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
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/ai_import_file_source.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/grades_class_context.dart';
import 'package:uuid/uuid.dart';

/// AI 智能导入成绩：本机任意文件或微信分享 → 识别 → 校验/改列 → 预览 → 确认写入。
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

class _AiExamImportScreenState extends State<AiExamImportScreen>
    with AiImportFileSourceMixin {
  bool _busy = false;
  String? _fileName;
  AiGradeParseResult? _parsed;
  List<ExamScoreMatchPreview> _previews = const [];
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
    await importAiFileFromWeChat(fileKindLabel: '成绩表文件');
  }

  @override
  Future<void> onAiImportFile(AiImportFile file) async {
    final aiCtrl = context.read<AiSettingsController>();
    if (!aiCtrl.hasApiKey) return;

    final ctrl = context.read<ClassController>();
    final exam = widget.examId == null ? null : ctrl.examById(widget.examId!);
    final knownNames = [for (final s in ctrl.students) s.name];
    final preferred = exam?.subjects ?? const <String>[];

    setState(() {
      _busy = true;
      _error = null;
      _fileName = file.fileName;
      _parsed = null;
      _previews = const [];
    });

    try {
      final result = await AiExamScoreImport(
        aiCtrl.createService(maxTokens: 1600),
      ).parseBytes(
        file.bytes,
        fileName: file.fileName,
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
      setState(() => _error = ExcelGrid.friendlyParseError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reapplyMapping(AiGradeTableMapping mapping) {
    final parsed = _parsed;
    if (parsed == null) return;
    final ctrl = context.read<ClassController>();
    final knownNames = [for (final s in ctrl.students) s.name];
    final next = AiExamScoreImport.applyMapping(
      parsed.grid,
      mapping,
      knownStudentNames: knownNames,
      extraWarnings: const ['已按手动列映射重新提取'],
    );
    setState(() {
      _parsed = next;
      _previews = ctrl.previewExamScoreRows(next.rows);
    });
  }

  bool get _canConfirm {
    final parsed = _parsed;
    if (parsed == null || parsed.rows.isEmpty || _busy) return false;
    if (!parsed.mappingOk) return false;
    final students = context.read<ClassController>().students;
    final matched = _previews.where((p) => p.isMatched).length;
    // 本班已有学生时，0 匹配通常是姓名列仍错，禁止落库。
    if (students.isNotEmpty && matched == 0) return false;
    return true;
  }

  String? get _confirmBlockReason {
    final parsed = _parsed;
    if (parsed == null) return null;
    if (parsed.rows.isEmpty) return '当前映射未提取到成绩行';
    if (!parsed.mappingOk) {
      return '列映射未通过校验，请先在下方修正姓名列/科目列';
    }
    final students = context.read<ClassController>().students;
    final matched = _previews.where((p) => p.isMatched).length;
    if (students.isNotEmpty && matched == 0) {
      return '本班学生均未匹配，请检查姓名列是否选对';
    }
    return null;
  }

  Future<void> _confirmImport() async {
    final parsed = _parsed;
    if (parsed == null || !_canConfirm) return;

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
                  RegExp(r'\.[^.]+$', caseSensitive: false),
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

  String _nameColumnHint(AiGradeParseResult parsed) {
    final samples = AiExamScoreImport.columnSamples(
      parsed.grid,
      parsed.mapping.headerRowIndex,
      parsed.mapping.nameColumn,
      limit: 3,
    );
    if (samples.isEmpty) return '';
    return ' · 样例 ${samples.join('、')}';
  }

  /// AI notes 里常见自相矛盾长文，界面只留校验/操作相关提示。
  static bool _isNoisyAiNote(String w) {
    final t = w.trim();
    if (t.length > 80 && (t.contains('表头') || t.contains('映射'))) return true;
    if (t.contains('无学号列') && t.contains('备注列') && !t.contains('校验')) {
      return true;
    }
    return false;
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.secondaryLabel,
      ),
    );
  }

  Widget _mappingEditor(AiGradeParseResult parsed) {
    final mapping = parsed.mapping;
    final labels = AiExamScoreImport.headerLabels(
      parsed.grid,
      mapping.headerRowIndex,
    );
    final colCount = parsed.grid.colCount;
    if (colCount == 0) return const SizedBox.shrink();

    final headerMax = parsed.grid.rowCount;
    final headerValue =
        mapping.headerRowIndex.clamp(0, headerMax > 0 ? headerMax - 1 : 0);
    final headerOptions = <int>{
      for (var i = 0; i < headerMax && i < 30; i++) i,
      headerValue,
    }.toList()
      ..sort();

    DropdownMenuItem<int> colItem(int i) => DropdownMenuItem(
          value: i,
          child: Text(
            i < labels.length ? labels[i] : '列 $i',
            overflow: TextOverflow.ellipsis,
          ),
        );

    final nameSamples = AiExamScoreImport.columnSamples(
      parsed.grid,
      mapping.headerRowIndex,
      mapping.nameColumn,
      limit: 5,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: parsed.needsManualMapping
            ? Border.all(color: AppTheme.destructive.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parsed.needsManualMapping) ...[
            Text(
              '需要手动校正列映射',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.destructive,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              parsed.validationErrors.take(4).join('\n'),
              style: TextStyle(fontSize: 12, color: AppTheme.destructive),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const Text(
              '列映射（可改）',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '源列表头与样例如下，改错列后会立即重算预览。',
              style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
            ),
            const SizedBox(height: 12),
          ],
          _dropdownRow<int>(
            label: '表头行',
            value: headerValue,
            items: [
              for (final i in headerOptions)
                DropdownMenuItem(value: i, child: Text('第 $i 行（R$i）')),
            ],
            onChanged: (v) {
              if (v == null) return;
              _reapplyMapping(mapping.copyWith(headerRowIndex: v));
            },
          ),
          const SizedBox(height: 8),
          _dropdownRow<int>(
            label: '姓名列',
            value: mapping.nameColumn.clamp(0, colCount - 1),
            items: [for (var i = 0; i < colCount; i++) colItem(i)],
            onChanged: (v) {
              if (v == null) return;
              _reapplyMapping(
                mapping.copyWith(nameColumn: v, nameSamples: const []),
              );
            },
          ),
          if (nameSamples.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '样例：${nameSamples.join('、')}',
              style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
            ),
          ],
          const SizedBox(height: 8),
          _dropdownRow<int?>(
            label: '学号列',
            value: (mapping.studentNoColumn != null &&
                    mapping.studentNoColumn! >= 0 &&
                    mapping.studentNoColumn! < colCount)
                ? mapping.studentNoColumn
                : null,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('无')),
              for (var i = 0; i < colCount; i++)
                DropdownMenuItem<int?>(
                  value: i,
                  child: Text(
                    i < labels.length ? labels[i] : '列 $i',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              _reapplyMapping(
                mapping.copyWith(
                  studentNoColumn: v,
                  clearStudentNoColumn: v == null,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '科目列',
            style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
          ),
          const SizedBox(height: 6),
          for (final e in mapping.subjectColumns.entries) ...[
            _dropdownRow<int>(
              label: e.key,
              value: e.value.clamp(0, colCount - 1),
              items: [for (var i = 0; i < colCount; i++) colItem(i)],
              onChanged: (v) {
                if (v == null) return;
                final next = Map<String, int>.from(mapping.subjectColumns);
                next[e.key] = v;
                _reapplyMapping(mapping.copyWith(subjectColumns: next));
              },
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _dropdownRow<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
          ),
        ),
        Expanded(
          child: InputDecorator(
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                key: ValueKey<Object?>('$label-$value'),
                value: value,
                isExpanded: true,
                isDense: true,
                items: items,
                onChanged: _busy ? null : onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.examId == null
        ? null
        : context.watch<ClassController>().examById(widget.examId!);
    final matched = _previews.where((p) => p.isMatched).length;
    final parsed = _parsed;
    final blockReason = _confirmBlockReason;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('AI 智能导入'),
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
          const GradesClassContext(),
          const SizedBox(height: 12),
          AiImportSourcePanel(
            busy: _busy,
            awaitingWeChat: awaitingWeChatShare,
            onPickLocal: _startLocal,
            onImportWeChat: _startWeChat,
            onCancelWeChat: cancelAwaitingWeChatShare,
            hint: exam == null
                ? '微信/本机可选成绩表或照片截图（本地 OCR → AI）。列名不必固定，并可新建考试。'
                : '导入到「${exam.title}」。支持文件与照片；列名不必固定，AI 会尽量对齐科目。',
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
              _sectionTitle('列映射（必改）'),
              const SizedBox(height: 8),
              _mappingEditor(parsed),
              if (blockReason != null) ...[
                const SizedBox(height: 10),
                Text(
                  blockReason,
                  style: TextStyle(fontSize: 13, color: AppTheme.destructive),
                ),
              ],
              const SizedBox(height: 16),
            ],
            _sectionTitle('识别结果'),
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
                  Text(
                    '姓名列：列 ${parsed.mapping.nameColumn}'
                    '${_nameColumnHint(parsed)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: parsed.mappingOk
                          ? AppTheme.tertiaryLabel
                          : AppTheme.destructive,
                    ),
                  ),
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
              _sectionTitle('列映射'),
              const SizedBox(height: 8),
              _mappingEditor(parsed),
              if (blockReason != null) ...[
                const SizedBox(height: 10),
                Text(
                  blockReason,
                  style: TextStyle(fontSize: 13, color: AppTheme.destructive),
                ),
              ],
            ],
            if (parsed.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                parsed.warnings
                    .where((w) => !_isNoisyAiNote(w))
                    .take(4)
                    .join('\n'),
                style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
              ),
            ],
            const SizedBox(height: 16),
            _sectionTitle('学生匹配预览'),
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
