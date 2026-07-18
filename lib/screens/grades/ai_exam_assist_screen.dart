import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/more/ai_settings_screen.dart';
import 'package:smart_class/services/ai_class_context.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

enum AiExamAssistMode {
  analyze,
  classMeeting,
}

/// 考试详情 → AI 成绩解读 / 生成班会
class AiExamAssistScreen extends StatefulWidget {
  const AiExamAssistScreen({
    super.key,
    required this.examId,
    required this.mode,
  });

  final String examId;
  final AiExamAssistMode mode;

  static Future<void> open(
    BuildContext context, {
    required String examId,
    required AiExamAssistMode mode,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiExamAssistScreen(examId: examId, mode: mode),
      ),
    );
  }

  @override
  State<AiExamAssistScreen> createState() => _AiExamAssistScreenState();
}

class _AiExamAssistScreenState extends State<AiExamAssistScreen> {
  final _themeHint = TextEditingController();
  String? _result;
  bool _busy = false;
  String? _error;

  String get _title => switch (widget.mode) {
        AiExamAssistMode.analyze => 'AI 成绩解读',
        AiExamAssistMode.classMeeting => '生成班会内容',
      };

  @override
  void dispose() {
    _themeHint.dispose();
    super.dispose();
  }

  Future<bool> _ensureKey() async {
    final ai = context.read<AiSettingsController>();
    if (ai.hasApiKey) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('尚未配置 AI'),
        content: const Text('请先在「我的 → AI 助手」填写 DeepSeek API Key。'),
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

  Future<void> _run() async {
    if (_busy) return;
    if (!await _ensureKey()) return;
    if (!mounted) return;

    final ctrl = context.read<ClassController>();
    final ai = context.read<AiSettingsController>();
    final exam = ctrl.examById(widget.examId);
    if (exam == null) {
      setState(() => _error = '考试不存在');
      return;
    }
    final ranked = ctrl.rankedScores(widget.examId);
    if (ranked.isEmpty) {
      setState(() => _error = '还没有成绩，请先导入或录入后再试');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final brief = await AiClassContext.buildExamBrief(ctrl, widget.examId);
      // 班会/解读略重要：体验档点深度会走 Pro；日常 Flash 也够用
      final service = ai.createService(maxTokens: 1600);
      final text = switch (widget.mode) {
        AiExamAssistMode.analyze =>
          await service.analyzeExamReport(examBrief: brief),
        AiExamAssistMode.classMeeting =>
          await service.generateClassMeetingFromExam(
            examBrief: brief,
            themeHint: _themeHint.text,
          ),
      };
      if (!mounted) return;
      setState(() => _result = text);
    } on DeepSeekAiException catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final t = _result?.trim();
    if (t == null || t.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制')),
    );
  }

  Future<void> _saveWorkLog() async {
    final t = _result?.trim();
    if (t == null || t.isEmpty) return;
    final ctrl = context.read<ClassController>();
    final exam = ctrl.examById(widget.examId);
    final title = switch (widget.mode) {
      AiExamAssistMode.analyze => '成绩解读 · ${exam?.title ?? '考试'}',
      AiExamAssistMode.classMeeting => '主题班会 · ${exam?.title ?? '考试反馈'}',
    };
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await ctrl.saveWorkLog(
      category: WorkLogCategory.classMeeting,
      title: title,
      content: t,
      date: date,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.mode == AiExamAssistMode.classMeeting
              ? '已保存到工作留痕（主题班会）'
              : '已保存到工作留痕，可随时查阅',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exam = context.watch<ClassController>().examById(widget.examId);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: Text(_title),
        actions: [
          if (_result != null && !_busy) ...[
            IconButton(
              tooltip: '复制',
              onPressed: _copy,
              icon: const Icon(AppIcons.copy),
            ),
            IconButton(
              tooltip: '重新生成',
              onPressed: _run,
              icon: const Icon(AppIcons.refresh),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            exam == null
                ? '考试不存在'
                : '${exam.title} · ${exam.category} · ${exam.examDate}',
            style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
          ),
          if (widget.mode == AiExamAssistMode.classMeeting) ...[
            const SizedBox(height: 12),
            Text(
              '主题倾向（可选）',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _themeHint,
              decoration: const InputDecoration(
                hintText: '如：诚信考试、学习方法、迎接下次月考',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _run(),
            ),
          ],
          const SizedBox(height: 16),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  CircularProgressIndicator.adaptive(),
                  SizedBox(height: 14),
                  Text('懒羊羊正在写…'),
                ],
              ),
            )
          else if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!, style: TextStyle(color: AppTheme.destructive)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _run, child: const Text('重试')),
                ],
              ),
            )
          else if (_result != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                _result!,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.label,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(AppIcons.copy, size: 18),
                    label: const Text('复制'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveWorkLog,
                    icon: const Icon(AppIcons.notebook, size: 18),
                    label: Text(
                      widget.mode == AiExamAssistMode.classMeeting
                          ? '存为班会留痕'
                          : '存到工作留痕',
                    ),
                  ),
                ),
              ],
            ),
            if (widget.mode == AiExamAssistMode.classMeeting) ...[
              const SizedBox(height: 10),
              Text(
                '可改主题倾向后点右上角刷新重新生成。',
                style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
              ),
            ],
          ] else ...[
            Text(
              widget.mode == AiExamAssistMode.analyze
                  ? '根据本场考试数据生成成绩解读，可复制或存入工作留痕。'
                  : '可先填写主题倾向，再生成班会议程与主持话术。',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.tertiaryLabel,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _run,
              icon: const Icon(AppIcons.sparkles, size: 18),
              label: Text(
                widget.mode == AiExamAssistMode.analyze ? '生成解读' : '生成班会',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
