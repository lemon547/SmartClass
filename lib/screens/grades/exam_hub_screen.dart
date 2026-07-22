import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/ai_exam_assist_screen.dart';
import 'package:smart_class/screens/grades/exam_actions.dart';
import 'package:smart_class/screens/grades/exam_detail_screen.dart';
import 'package:smart_class/screens/grades/exam_files_screen.dart';
import 'package:smart_class/screens/grades/exam_missing_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';

/// 单场考试功能中心：点进考试后先到此页，再进入成绩表/分析/资料等子功能。
class ExamHubScreen extends StatefulWidget {
  const ExamHubScreen({
    super.key,
    required this.examId,
    this.promptEnterScores = false,
  });

  final String examId;
  final bool promptEnterScores;

  static Future<void> push(
    BuildContext context, {
    required String examId,
    bool promptEnterScores = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamHubScreen(
          examId: examId,
          promptEnterScores: promptEnterScores,
        ),
      ),
    );
  }

  @override
  State<ExamHubScreen> createState() => _ExamHubScreenState();
}

class _ExamHubScreenState extends State<ExamHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ClassController>().ensureExamScores(widget.examId);
      if (!mounted) return;
      if (widget.promptEnterScores) {
        final ctrl = context.read<ClassController>();
        final exam = ctrl.examById(widget.examId);
        if (exam != null && ctrl.scoresOfExam(exam.id).isEmpty) {
          await ExamActions.showImportSheet(context, exam);
        }
      }
    });
  }

  void _openDetail({int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExamDetailScreen(
          examId: widget.examId,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final exam = ctrl.examById(widget.examId);
    if (exam == null) {
      return Scaffold(
        appBar: PageAppBar(title: const Text('考试')),
        body: const Center(child: Text('考试不存在')),
      );
    }

    final ranked = ctrl.rankedScores(widget.examId);
    final files = ctrl.filesOfExam(exam.id);
    final roster = ctrl.students.length;
    final recorded = ranked.length;
    final missing = roster - recorded;
    final stats = ctrl.analyzeExam(exam.id);
    SubjectStat? totalStat;
    for (final s in stats) {
      if (s.label == '总分') {
        totalStat = s;
        break;
      }
    }

    final prevExams = ctrl.exams
        .where((e) => e.id != exam.id && ctrl.scoresOfExam(e.id).isNotEmpty)
        .toList();

    return Scaffold(
      appBar: PageAppBar(
        title: Text(exam.title),
        actions: [
          IconButton(
            tooltip: '编辑考试',
            onPressed: () => ExamActions.openEdit(context, exam),
            icon: const Icon(AppIcons.edit),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(AppIcons.moreVert),
            onSelected: (v) {
              switch (v) {
                case 'template':
                  ExamActions.downloadTemplate(context, exam.id);
                case 'delete':
                  ExamActions.deleteExam(context, exam);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'template', child: Text('下载空白模板')),
              PopupMenuItem(
                value: 'delete',
                child: Text('删除考试', style: TextStyle(color: Color(0xFFFF3B30))),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          GroupedSection(
            header: '概况',
            children: [
              GroupedTile(
                title: exam.category,
                subtitle: [
                  exam.examDate,
                  exam.subjects.join('、'),
                  if (roster > 0) '已录 $recorded/$roster 人' else '已录 $recorded 人',
                ].join(' · '),
              ),
              if (exam.note.trim().isNotEmpty)
                GroupedTile(
                  title: '备注',
                  subtitle: exam.note.trim(),
                ),
              if (totalStat != null && totalStat.count > 0) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _KpiChip(
                        label: '均分',
                        value: ExamDetailScreen.fmt(totalStat.average),
                        color: AppTheme.blue,
                      ),
                      const SizedBox(width: 8),
                      _KpiChip(
                        label: '最高',
                        value: ExamDetailScreen.fmt(totalStat.max),
                        color: const Color(0xFF34C759),
                      ),
                      const SizedBox(width: 8),
                      _KpiChip(
                        label: '及格率',
                        value:
                            '${(totalStat.passRate * 100).toStringAsFixed(0)}%',
                        color: const Color(0xFF5B45B0),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (ranked.isNotEmpty && stats.any((s) => s.label != '总分' && s.count > 0))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ChartCard(
                title: '各科均分预览',
                height: 160,
                child: SimpleBarChart(
                  items: [
                    for (final s in stats)
                      if (s.label != '总分' && s.count > 0)
                        ChartBarItem(
                          label: s.label,
                          value: s.average,
                          color: AppTheme.blue,
                        ),
                  ],
                  maxY: exam.fullScore,
                ),
              ),
            ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '成绩',
            footer: recorded == 0 ? '尚未录入，可先导入或去成绩表手动录入' : null,
            children: [
              GroupedTile(
                title: '查看成绩表',
                subtitle: '表格录入、逐格修改',
                leading: Icon(AppIcons.fileSheet, color: AppTheme.blue),
                onTap: () => _openDetail(initialTab: 0),
              ),
              GroupedTile(
                title: '导入成绩',
                subtitle: 'Excel / AI 智能识别',
                leading: Icon(AppIcons.download, color: AppTheme.blue),
                onTap: () => ExamActions.showImportSheet(context, exam),
              ),
              GroupedTile(
                title: '导出成绩',
                subtitle: '导出本班已填 Excel',
                leading: Icon(AppIcons.share, color: AppTheme.blue),
                onTap: () => ExamActions.exportFilled(context, exam.id),
              ),
              if (missing > 0)
                GroupedTile(
                  title: '缺考名单',
                  subtitle: '$missing 人尚未录入',
                  leading: Icon(AppIcons.alert, color: const Color(0xFFFF9500)),
                  onTap: () => ExamMissingScreen.push(context, examId: exam.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '分析',
            footer: ranked.isEmpty ? '录入成绩后可查看图表与排行' : '均分、分数段、单科与总分排行',
            children: [
              GroupedTile(
                title: '动态图分析',
                subtitle: ranked.isEmpty
                    ? '各科均分、分数段、排行'
                    : '各科均分、分数段、排行 · ${ranked.length} 人',
                leading: Icon(AppIcons.chart, color: const Color(0xFF5B45B0)),
                onTap: () => _openDetail(initialTab: 1),
              ),
              if (prevExams.isNotEmpty)
                GroupedTile(
                  title: '历次均分对比',
                  subtitle: '与本班 ${prevExams.length + 1} 次考试对比',
                  leading: Icon(AppIcons.sliders, color: AppTheme.blue),
                  onTap: () => _showTrendCompare(context, ctrl, exam, prevExams),
                ),
            ],
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '资料',
            footer: '试卷、答题卡、扫描件等原始文件',
            children: [
              GroupedTile(
                title: '查看原始文件',
                subtitle: files.isEmpty ? '暂无存档' : '共 ${files.length} 个文件',
                leading: Icon(AppIcons.folder, color: AppTheme.blue),
                onTap: () => ExamFilesScreen.push(context, examId: exam.id),
              ),
              GroupedTile(
                title: '上传资料',
                leading: Icon(AppIcons.upload, color: AppTheme.blue),
                onTap: () => ExamActions.pickExamFiles(context, exam.id),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: 'AI 助手',
            children: [
              GroupedTile(
                title: 'AI 成绩解读',
                subtitle: '生成可落地的班级分析',
                leading: Icon(AppIcons.sparkles, color: AppTheme.blue),
                onTap: () => AiExamAssistScreen.open(
                  context,
                  examId: exam.id,
                  mode: AiExamAssistMode.analyze,
                ),
              ),
              GroupedTile(
                title: '生成班会材料',
                subtitle: '基于本场成绩写班会稿',
                leading: Icon(AppIcons.usersGroup, color: AppTheme.blue),
                onTap: () => AiExamAssistScreen.open(
                  context,
                  examId: exam.id,
                  mode: AiExamAssistMode.classMeeting,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTrendCompare(
    BuildContext context,
    ClassController ctrl,
    Exam current,
    List<Exam> others,
  ) {
    final all = [...others, current]
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '历次总分均分对比',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.label,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: SimpleBarChart(
                    items: [
                      for (final e in all)
                        ChartBarItem(
                          label: e.title.length > 6
                              ? '${e.title.substring(0, 6)}…'
                              : e.title,
                          value: _examAvg(ctrl, e.id),
                          color: e.id == current.id
                              ? const Color(0xFF5B45B0)
                              : AppTheme.blue,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '紫色为当前考试；完整列表见成绩页顶部图表',
                  style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static double _examAvg(ClassController ctrl, String examId) {
    final scores = ctrl.scoresOfExam(examId);
    if (scores.isEmpty) return 0;
    var sum = 0.0;
    for (final s in scores) {
      sum += s.total;
    }
    return sum / scores.length;
  }
}

class _KpiChip extends StatelessWidget {
  const _KpiChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppTheme.tertiaryLabel),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
