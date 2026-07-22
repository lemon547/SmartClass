import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/ai_exam_import_screen.dart';
import 'package:smart_class/screens/grades/exam_hub_screen.dart';
import 'package:smart_class/screens/grades/exam_edit_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';
import 'package:smart_class/widgets/grades_class_context.dart';

/// 成绩报告列表（对齐班级优化大师「成绩报告」）
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClassController>().ensureAllExamScores();
    });
  }

  List<String> _populatedCategories(ClassController ctrl) {
    final counts = <String, int>{};
    for (final e in ctrl.exams) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    final ordered = <String>[];
    for (final c in ctrl.examCategories) {
      if (counts.containsKey(c)) ordered.add(c);
    }
    for (final c in counts.keys) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final populated = _populatedCategories(ctrl);
    final filter =
        (_filter != null && populated.contains(_filter)) ? _filter : null;
    final list = ctrl.examsOf(filter);
    final showFilter = populated.length >= 2;
    final roster = ctrl.students.length;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('成绩'),
        actions: [
          IconButton(
            tooltip: 'AI 智能导入',
            onPressed: () => AiExamImportScreen.push(context),
            icon: const Icon(AppIcons.sparkles),
          ),
          IconButton(
            tooltip: '新建成绩报告',
            onPressed: () => _createExam(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GradesClassContext(),
            ),
          ),
          if (showFilter)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                children: [
                  _CategoryPill(
                    label: '全部',
                    selected: filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final c in populated)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CategoryPill(
                        label: c,
                        selected: filter == c,
                        onTap: () => setState(() => _filter = c),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? _EmptyState(
                    filter: filter,
                    onCreate: () => _createExam(context),
                    onAiImport: () => AiExamImportScreen.push(context),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 28, top: 4),
                    children: [
                      if (_examAvgBars(ctrl, list).length >= 2)
                        ChartCard(
                          title: '历次总分均分对比',
                          height: 200,
                          child: SimpleBarChart(
                            items: _examAvgBars(ctrl, list),
                          ),
                        ),
                      ..._examSections(
                        ctrl,
                        list,
                        filter,
                        populated,
                        roster,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _examSections(
    ClassController ctrl,
    List<Exam> list,
    String? filter,
    List<String> populated,
    int roster,
  ) {
    if (filter == null && populated.length >= 2) {
      return [
        for (final cat in populated)
          if (list.any((e) => e.category == cat))
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GroupedSection(
                header:
                    '$cat · ${list.where((e) => e.category == cat).length}',
                children: [
                  for (final e in list)
                    if (e.category == cat)
                      _ExamTile(
                        exam: e,
                        showCategory: false,
                        ctrl: ctrl,
                        roster: roster,
                      ),
                ],
              ),
            ),
      ];
    }
    // 无分组时不显示「成绩报告 · N」——标题栏与筛选项已够
    return [
      GroupedSection(
        children: [
          for (final e in list)
            _ExamTile(
              exam: e,
              showCategory: filter == null,
              ctrl: ctrl,
              roster: roster,
            ),
        ],
      ),
    ];
  }

  Future<void> _createExam(BuildContext context) async {
    final id = await ExamEditScreen.push(context);
    if (id == null || !context.mounted) return;
    if (id == ExamEditScreen.deletedToken) return;
    await ExamHubScreen.push(
      context,
      examId: id,
      promptEnterScores: true,
    );
  }

  List<ChartBarItem> _examAvgBars(ClassController ctrl, List<Exam> list) {
    final items = <ChartBarItem>[];
    final sorted = [...list]..sort((a, b) => a.examDate.compareTo(b.examDate));
    for (final e in sorted) {
      final scores = ctrl.scoresOfExam(e.id);
      if (scores.isEmpty) continue;
      final avg =
          scores.map((s) => s.total).fold(0.0, (a, b) => a + b) / scores.length;
      final label = e.title.length > 6 ? e.title.substring(0, 6) : e.title;
      items.add(ChartBarItem(label: label, value: avg));
    }
    return items;
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.exam,
    required this.showCategory,
    required this.ctrl,
    required this.roster,
  });

  final Exam exam;
  final bool showCategory;
  final ClassController ctrl;
  final int roster;

  @override
  Widget build(BuildContext context) {
    final recorded = ctrl.scoresOfExam(exam.id).length;
    final meta = <String>[
      if (showCategory) exam.category,
      exam.examDate,
      if (roster > 0) '$recorded/$roster 人' else '$recorded 人',
    ];

    return GroupedTile(
      title: exam.title,
      subtitle: meta.join(' · '),
      trailing: Icon(
        AppIcons.chevronRight,
        size: 20,
        color: AppTheme.quaternaryLabel,
      ),
      onTap: () => ExamHubScreen.push(context, examId: exam.id),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.filter,
    required this.onCreate,
    required this.onAiImport,
  });

  final String? filter;
  final VoidCallback onCreate;
  final VoidCallback onAiImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chart, size: 40, color: AppTheme.quaternaryLabel),
            const SizedBox(height: 12),
            Text(
              filter == null ? '还没有成绩报告' : '暂无「$filter」报告',
              style: TextStyle(color: AppTheme.tertiaryLabel),
            ),
            const SizedBox(height: 8),
            Text(
              '新建报告后在成绩表中录入，或用 AI 导入成绩表/照片',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.quaternaryLabel,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreate,
              child: const Text('新建成绩报告'),
            ),
            if (filter == null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onAiImport,
                icon: const Icon(AppIcons.sparkles, size: 18),
                label: const Text('AI 智能导入'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
