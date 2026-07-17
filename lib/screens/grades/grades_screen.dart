import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/exam_detail_screen.dart';
import 'package:smart_class/screens/grades/exam_edit_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';

/// 成绩存档与分析：期末 / 半期 / 月考等可自由编辑
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.examsOf(_filter);

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('成绩分析'),
        actions: [
          IconButton(
            tooltip: '新建考试',
            onPressed: () => ExamEditScreen.push(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('全部 (${ctrl.exams.length})'),
                    selected: _filter == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final c in ctrl.examCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        '$c (${ctrl.exams.where((e) => e.category == c).length})',
                      ),
                      selected: _filter == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.chart,
                              size: 40, color: AppTheme.quaternaryLabel),
                          const SizedBox(height: 12),
                          Text(
                            _filter == null ? '还没有考试存档' : '暂无「$_filter」记录',
                            style: TextStyle(color: AppTheme.tertiaryLabel),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '可新建期末考、半期考、月考等，导入 Excel 后查看分析',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.quaternaryLabel,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => ExamEditScreen.push(context),
                            child: const Text('新建考试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (_examAvgBars(ctrl, list).length >= 2)
                        ChartCard(
                          title: '历次总分均分对比',
                          height: 200,
                          child: SimpleBarChart(
                            items: _examAvgBars(ctrl, list),
                          ),
                        ),
                      GroupedSection(
                        header: '${list.length} 次考试',
                        children: [
                          for (final e in list)
                            GroupedTile(
                              title: e.title,
                              subtitle:
                                  '${e.category} · ${e.examDate} · ${e.subjects.length} 科 · ${ctrl.scoresOfExam(e.id).length} 人${ctrl.filesOfExam(e.id).isEmpty ? '' : ' · ${ctrl.filesOfExam(e.id).length} 份资料'}',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ExamDetailScreen(examId: e.id),
                                ),
                              ),
                              onLongPress: () =>
                                  ExamEditScreen.push(context, existing: e),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<ChartBarItem> _examAvgBars(ClassController ctrl, List<Exam> list) {
    final items = <ChartBarItem>[];
    // 按日期升序对比
    final sorted = [...list]
      ..sort((a, b) => a.examDate.compareTo(b.examDate));
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
