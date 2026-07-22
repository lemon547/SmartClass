import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/ai_exam_assist_screen.dart';
import 'package:smart_class/screens/grades/exam_actions.dart';
import 'package:smart_class/screens/grades/exam_scoresheet.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';

class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({
    super.key,
    required this.examId,
    this.promptEnterScores = false,
    this.initialTab = 0,
  });

  final String examId;
  final bool promptEnterScores;
  final int initialTab;

  static String fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _rankSearch = TextEditingController();
  String _rankQuery = '';
  String? _subjectRankFilter; // null = 总分

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ClassController>().ensureExamScores(widget.examId);
      if (!mounted) return;
      if (widget.promptEnterScores) {
        final exam = context.read<ClassController>().examById(widget.examId);
        if (exam != null &&
            context.read<ClassController>().scoresOfExam(exam.id).isEmpty) {
          await ExamActions.showImportSheet(context, exam);
        }
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _rankSearch.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: PageAppBar(
        title: Text(exam.title),
        actions: [
          IconButton(
            tooltip: '导出本班成绩',
            onPressed: () => ExamActions.exportFilled(context, exam.id),
            icon: const Icon(AppIcons.share),
          ),
          IconButton(
            tooltip: '导入成绩',
            onPressed: () => ExamActions.showImportSheet(context, exam),
            icon: const Icon(AppIcons.download),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: const Icon(AppIcons.moreVert),
            onSelected: (v) {
              switch (v) {
                case 'edit':
                  ExamActions.openEdit(context, exam);
                case 'template':
                  ExamActions.downloadTemplate(context, exam.id);
                case 'upload':
                  ExamActions.pickExamFiles(context, exam.id);
                case 'delete':
                  ExamActions.deleteExam(context, exam);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑考试')),
              PopupMenuItem(value: 'template', child: Text('下载空白模板')),
              PopupMenuItem(value: 'upload', child: Text('上传资料')),
              PopupMenuItem(
                value: 'delete',
                child: Text('删除考试', style: TextStyle(color: Color(0xFFFF3B30))),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: AppTheme.bg,
            child: TabBar(
              controller: _tabs,
              labelColor: AppTheme.label,
              unselectedLabelColor: AppTheme.tertiaryLabel,
              indicatorColor: AppTheme.blue,
              tabs: [
                const Tab(text: '成绩表'),
                Tab(text: ranked.isEmpty ? '分析' : '分析 · ${ranked.length}'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ExamScoresheet(
                  exam: exam,
                  onImport: () => ExamActions.showImportSheet(context, exam),
                  onExport: () => ExamActions.exportFilled(context, exam.id),
                ),
                _AnalysisTab(
                  exam: exam,
                  ranked: ranked,
                  rankSearch: _rankSearch,
                  rankQuery: _rankQuery,
                  subjectFilter: _subjectRankFilter,
                  onRankQuery: (v) => setState(() => _rankQuery = v),
                  onSubjectFilter: (v) => setState(() => _subjectRankFilter = v),
                  onGoScoresheet: () => _tabs.animateTo(0),
                  onImport: () => ExamActions.showImportSheet(context, exam),
                  filesSection: ExamActions.filesSection(context, ctrl, exam),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisTab extends StatelessWidget {
  const _AnalysisTab({
    required this.exam,
    required this.ranked,
    required this.rankSearch,
    required this.rankQuery,
    required this.subjectFilter,
    required this.onRankQuery,
    required this.onSubjectFilter,
    required this.onGoScoresheet,
    required this.onImport,
    required this.filesSection,
  });

  final Exam exam;
  final List<ExamScore> ranked;
  final TextEditingController rankSearch;
  final String rankQuery;
  final String? subjectFilter;
  final ValueChanged<String> onRankQuery;
  final ValueChanged<String?> onSubjectFilter;
  final VoidCallback onGoScoresheet;
  final VoidCallback onImport;
  final Widget filesSection;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final stats = ctrl.analyzeExam(exam.id);
    SubjectStat? totalStat;
    for (final s in stats) {
      if (s.label == '总分') {
        totalStat = s;
        break;
      }
    }

    if (ranked.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          GroupedSection(
            header: '分析',
            footer: '先在成绩表录入或导入后显示均分与排行',
            children: [
              GroupedTile(
                title: '去成绩表录入',
                leading: Icon(AppIcons.fileSheet, color: AppTheme.blue),
                onTap: onGoScoresheet,
              ),
              GroupedTile(
                title: '导入成绩',
                leading: Icon(AppIcons.download, color: AppTheme.blue),
                onTap: onImport,
              ),
            ],
          ),
          const SizedBox(height: 18),
          filesSection,
        ],
      );
    }

    final subjectList = subjectFilter == null
        ? ranked
        : ctrl.rankedScoresBySubject(exam.id, subjectFilter!);
    final ranks = subjectFilter == null
        ? ctrl.classRankByTotal(exam.id)
        : ctrl.classRankBySubject(exam.id, subjectFilter!);

    final q = rankQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? subjectList
        : [
            for (final s in subjectList)
              if ((ctrl.studentById(s.studentId)?.name ?? '')
                      .toLowerCase()
                      .contains(q) ||
                  (ctrl.studentById(s.studentId)?.studentNo ?? '')
                      .toLowerCase()
                      .contains(q))
                s,
          ];

    final passRate = totalStat == null || totalStat.count == 0
        ? null
        : totalStat.passRate;

    Widget kpi(String label, String value, Color color) => Expanded(
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
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 28, top: 8),
      children: [
        GroupedSection(
          header: '班级概览',
          children: [
            GroupedTile(
              title: exam.category,
              subtitle:
                  '${exam.examDate} · ${exam.subjects.join('、')} · 已录 ${ranked.length} 人',
            ),
            if (totalStat != null && totalStat.count > 0) ...[
              const SizedBox(height: 10),
              ...(() {
                final ts = totalStat!;
                final totalFull = exam.fullScore * exam.subjects.length;
                final excellentLine = totalFull * 0.85;
                final excellentRate = ranked.isEmpty
                    ? 0.0
                    : ranked
                            .where((s) => s.total >= excellentLine)
                            .length /
                        ranked.length;
                return [
                  Row(
                    children: [
                      kpi('均分', ExamDetailScreen.fmt(ts.average),
                          AppTheme.blue),
                      const SizedBox(width: 8),
                      kpi('中位数', ExamDetailScreen.fmt(ts.median),
                          AppTheme.blue),
                      const SizedBox(width: 8),
                      kpi('最高', ExamDetailScreen.fmt(ts.max),
                          const Color(0xFF34C759)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      kpi('最低', ExamDetailScreen.fmt(ts.min),
                          const Color(0xFFFF9500)),
                      const SizedBox(width: 8),
                      kpi(
                        '及格率',
                        passRate != null
                            ? '${(passRate * 100).toStringAsFixed(0)}%'
                            : '—',
                        AppTheme.blue,
                      ),
                      const SizedBox(width: 8),
                      kpi(
                        '优秀率',
                        '${(excellentRate * 100).toStringAsFixed(0)}%',
                        const Color(0xFF5B45B0),
                      ),
                    ],
                  ),
                ];
              })(),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ChartCard(
          title: '各科均分',
          height: 200,
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
        ChartCard(
          title: '总分分数段',
          height: 180,
          child: SimpleDonutChart(slices: _totalBands(exam, ranked)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RankChip(
                  label: '总分',
                  selected: subjectFilter == null,
                  onTap: () => onSubjectFilter(null),
                ),
                for (final s in exam.subjects) ...[
                  const SizedBox(width: 8),
                  _RankChip(
                    label: s,
                    selected: subjectFilter == s,
                    onTap: () => onSubjectFilter(s),
                  ),
                ],
              ],
            ),
          ),
        ),
        SearchField(
          controller: rankSearch,
          hint: '搜索学生',
          onChanged: onRankQuery,
        ),
        GroupedSection(
          header: subjectFilter == null
              ? '总分排行 · ${ranked.length}'
              : '$subjectFilter 排行 · ${subjectList.length}',
          footer: '班内名次由分数计算；折算/年级名次来自导入',
          children: [
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '无匹配学生',
                  style: TextStyle(color: AppTheme.tertiaryLabel),
                ),
              )
            else
              for (final score in filtered)
                _ScoreTile(
                  rank: ranks[score.studentId] ?? 0,
                  exam: exam,
                  score: score,
                  subjectFilter: subjectFilter,
                  onTap: onGoScoresheet,
                ),
          ],
        ),
        const SizedBox(height: 18),
        GroupedSection(
          header: 'AI 助手',
          children: [
            GroupedTile(
              title: 'AI 成绩解读',
              leading: Icon(AppIcons.sparkles, color: AppTheme.blue),
              onTap: () => AiExamAssistScreen.open(
                context,
                examId: exam.id,
                mode: AiExamAssistMode.analyze,
              ),
            ),
            GroupedTile(
              title: '生成班会',
              leading: Icon(AppIcons.usersGroup, color: AppTheme.blue),
              onTap: () => AiExamAssistScreen.open(
                context,
                examId: exam.id,
                mode: AiExamAssistMode.classMeeting,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        filesSection,
      ],
    );
  }

  static List<ChartSlice> _totalBands(Exam exam, List<ExamScore> ranked) {
    final full = exam.fullScore * exam.subjects.length;
    final pass = exam.passScore * exam.subjects.length;
    final excellent = full * 0.85;
    final good = full * 0.75;
    var a = 0, b = 0, c = 0, d = 0;
    for (final s in ranked) {
      final t = s.total;
      if (t >= excellent) {
        a++;
      } else if (t >= good) {
        b++;
      } else if (t >= pass) {
        c++;
      } else {
        d++;
      }
    }
    return [
      ChartSlice(
          label: '优秀', value: a.toDouble(), color: const Color(0xFF34C759)),
      ChartSlice(label: '良好', value: b.toDouble(), color: AppTheme.blue),
      ChartSlice(
          label: '及格', value: c.toDouble(), color: const Color(0xFFFF9500)),
      ChartSlice(
          label: '不及格', value: d.toDouble(), color: AppTheme.destructive),
    ];
  }
}

class _RankChip extends StatelessWidget {
  const _RankChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.label : AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? AppTheme.bg : AppTheme.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.rank,
    required this.exam,
    required this.score,
    required this.subjectFilter,
    required this.onTap,
  });

  final int rank;
  final Exam exam;
  final ExamScore score;
  final String? subjectFilter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final stu = ctrl.studentById(score.studentId);
    final trailing = subjectFilter == null
        ? ExamDetailScreen.fmt(score.total)
        : ExamDetailScreen.fmt(score.scoreOf(subjectFilter!)!);

    final meta = <String>[];
    if (subjectFilter == null) {
      meta.addAll([
        for (final s in exam.subjects)
          if (score.scoreOf(s) != null)
            '$s ${ExamDetailScreen.fmt(score.scoreOf(s)!)}',
      ]);
    } else {
      if (score.convertedRank != null) meta.add('折算 ${score.convertedRank}');
      if (score.gradeRank != null) meta.add('年级 ${score.gradeRank}');
      final sr = score.subjectRanks[subjectFilter];
      if (sr != null) meta.add('官方位次 $sr');
    }

    return GroupedTile(
      title: stu?.name ?? '未知',
      subtitle: meta.isEmpty ? null : meta.join(' · '),
      leading: RankBadge(rank: rank <= 0 ? 1 : rank),
      trailing: Text(
        trailing,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
