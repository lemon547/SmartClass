import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/exam_edit_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';

class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({super.key, required this.examId});

  final String examId;

  static String fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClassController>().ensureExamScores(widget.examId);
    });
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
    final stats = ctrl.analyzeExam(widget.examId);

    return Scaffold(
      appBar: PageAppBar(
        title: Text(exam.title),
        actions: [
          IconButton(
            tooltip: '编辑考试',
            onPressed: () => ExamEditScreen.push(context, existing: exam),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: '上传资料',
            onPressed: () => _pickExamFiles(context, exam.id),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: '导入成绩',
            onPressed: () => _showExcelActions(context, exam),
            icon: const Icon(AppIcons.fileSheet),
          ),
          IconButton(
            tooltip: '删除',
            onPressed: () => _deleteExam(context, exam),
            icon: Icon(AppIcons.trash, color: AppTheme.destructive),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 8),
          GroupedSection(
            header: '概览',
            children: [
              GroupedTile(
                title: exam.category,
                subtitle:
                    '${exam.examDate} · 满分 ${ExamDetailScreen.fmt(exam.fullScore)} · 及格 ${ExamDetailScreen.fmt(exam.passScore)}',
              ),
              GroupedTile(
                title: '科目',
                subtitle: exam.subjects.isEmpty
                    ? '未设置'
                    : exam.subjects.join('、'),
              ),
              GroupedTile(
                title: '已录成绩',
                trailing: Text('${ranked.length} 人'),
              ),
              if (exam.note.isNotEmpty)
                GroupedTile(title: '备注', subtitle: exam.note),
            ],
          ),
          const SizedBox(height: 18),
          Builder(
            builder: (context) {
              final files = ctrl.filesOfExam(exam.id);
              return GroupedSection(
                header: '考试资料',
                footer: files.isEmpty
                    ? '可上传试卷、答题卡、分析表、PPT 等，保存在本机'
                    : '点文件打开；长按删除',
                children: [
                  GroupedTile(
                    title: '上传文件',
                    subtitle: '支持多选',
                    leading:
                        Icon(Icons.add_circle_outline, color: AppTheme.blue),
                    onTap: () => _pickExamFiles(context, exam.id),
                  ),
                  for (final f in files)
                    GroupedTile(
                      title: f.fileName,
                      subtitle: _formatSize(f.sizeBytes),
                      leading: Icon(
                        Icons.insert_drive_file_outlined,
                        color: AppTheme.blue,
                      ),
                      onTap: () => _openExamFile(context, f),
                      onLongPress: () => _deleteExamFile(context, f),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '成绩分析',
            footer: ranked.isEmpty ? '导入 Excel 或手动录入后显示均分、最高分、及格率等' : null,
            children: [
              if (stats.isEmpty || ranked.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '暂无数据',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                )
              else
                for (final s in stats)
                  GroupedTile(
                    title: s.label,
                    subtitle: s.count == 0
                        ? '无数据'
                        : '均分 ${ExamDetailScreen.fmt(s.average)} · 最高 ${ExamDetailScreen.fmt(s.max)} · 最低 ${ExamDetailScreen.fmt(s.min)}',
                    trailing: s.count == 0
                        ? const Text('—')
                        : Text(
                            '及格 ${(s.passRate * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.tertiaryLabel,
                            ),
                          ),
                  ),
            ],
          ),
          if (ranked.isNotEmpty) ...[
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
              title: '各科及格率',
              height: 200,
              child: SimpleBarChart(
                items: [
                  for (final s in stats)
                    if (s.label != '总分' && s.count > 0)
                      ChartBarItem(
                        label: s.label,
                        value: s.passRate * 100,
                        color: const Color(0xFF34C759),
                      ),
                ],
                maxY: 100,
                showAsPercent: true,
                valueSuffix: '%',
              ),
            ),
            ChartCard(
              title: '单科最高 / 最低',
              height: 200,
              footer: '蓝柱为最高分，橙柱为最低分',
              child: _HighLowBarChart(stats: stats, fullScore: exam.fullScore),
            ),
            ChartCard(
              title: '总分分数段',
              height: 180,
              child: SimpleDonutChart(
                slices: _totalBands(exam, ranked),
              ),
            ),
            ChartCard(
              title: '总分 Top 8',
              height: (ranked.length.clamp(1, 8) * 28.0) + 8,
              child: HorizontalRankChart(
                items: [
                  for (final s in ranked.take(8))
                    ChartBarItem(
                      label: ctrl.studentById(s.studentId)?.name ?? '?',
                      value: s.total,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          GroupedSection(
            header: '总分排行',
            children: [
              if (ranked.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '暂无成绩',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                )
              else
                for (var i = 0; i < ranked.length; i++)
                  _ScoreTile(
                    rank: i + 1,
                    exam: exam,
                    score: ranked[i],
                    onTap: () => _editScore(context, exam, ranked[i]),
                  ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _editScore(context, exam, null),
              icon: const Icon(AppIcons.plus, size: 18),
              label: const Text('手动录入成绩'),
            ),
          ),
        ],
      ),
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
      ChartSlice(label: '优秀', value: a.toDouble(), color: const Color(0xFF34C759)),
      ChartSlice(label: '良好', value: b.toDouble(), color: AppTheme.blue),
      ChartSlice(label: '及格', value: c.toDouble(), color: const Color(0xFFFF9500)),
      ChartSlice(label: '不及格', value: d.toDouble(), color: AppTheme.destructive),
    ];
  }

  Future<void> _showExcelActions(BuildContext context, Exam exam) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('成绩 Excel'),
        message: const Text('可用 WPS / Excel 编辑后导入'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadTemplate(context, exam.id);
            },
            child: const Text('下载成绩模板'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _importExcel(context, exam.id);
            },
            child: const Text('导入 Excel'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    try {
      final saved = await FileExport.saveGenerated(
        () => ctrl.exportExamTemplateFile(examId),
        dialogTitle: '保存成绩导入模板',
      );
      if (!context.mounted) return;
      FileExport.showSavedSnackBar(context, saved);
    } catch (e) {
      FileExport.showErrorSnackBar(context, e);
    }
  }

  Future<void> _importExcel(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
        return;
      }

      final result = await ctrl.importExamScoresFromBytes(
        examId,
        bytes,
        fileName: file.name,
      );
      if (!context.mounted) return;
      final msg = StringBuffer('匹配 ${result.matched} 人');
      if (result.skipped > 0) msg.write('，跳过 ${result.skipped} 人');
      if (result.warnings.isNotEmpty) {
        msg.write('\n');
        msg.write(result.warnings.take(8).join('\n'));
        if (result.warnings.length > 8) {
          msg.write('\n…共 ${result.warnings.length} 条提示');
        }
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
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _deleteExam(BuildContext context, Exam exam) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${exam.title}」？'),
        content: const Text('成绩记录与已上传的考试资料将一并删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<ClassController>().deleteExam(exam.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<void> _pickExamFiles(BuildContext context, String examId) async {
    final ctrl = context.read<ClassController>();
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    var ok = 0;
    for (final f in result.files) {
      final path = f.path;
      if (path == null || path.isEmpty) continue;
      await ctrl.attachExamFile(
        examId: examId,
        sourcePath: path,
        originalName: f.name,
      );
      ok++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok == 0 ? '未能读取所选文件' : '已存档 $ok 个文件')),
      );
    }
  }

  static Future<void> _openExamFile(BuildContext context, ExamFile file) async {
    final path = await context.read<ClassController>().examFilePath(file);
    final res = await OpenFilex.open(path);
    if (res.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.message.isEmpty ? '无法打开文件，请安装对应应用' : res.message,
          ),
        ),
      );
    }
  }

  static Future<void> _deleteExamFile(
    BuildContext context,
    ExamFile file,
  ) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('删除该资料？'),
        content: Text(file.fileName),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(d, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().deleteExamFile(file);
    }
  }

  Future<void> _editScore(
    BuildContext context,
    Exam exam,
    ExamScore? existing,
  ) async {
    final ctrl = context.read<ClassController>();
    String? studentId = existing?.studentId;
    final controllers = <String, TextEditingController>{
      for (final s in exam.subjects)
        s: TextEditingController(
          text: existing?.scoreOf(s) == null
              ? ''
              : ExamDetailScreen.fmt(existing!.scoreOf(s)!),
        ),
    };
    final remark = TextEditingController(text: existing?.remark ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final selected = studentId == null
                ? null
                : ctrl.studentById(studentId!);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null ? '录入成绩' : '编辑成绩',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(selected?.name ?? '选择学生'),
                      subtitle: Text(
                        selected == null
                            ? '点此选择'
                            : [
                                if (selected.studentNo.isNotEmpty)
                                  selected.studentNo,
                                if (selected.groupName.isNotEmpty)
                                  selected.groupName,
                              ].join(' · '),
                      ),
                      trailing: const Icon(AppIcons.chevronRight),
                      onTap: existing != null
                          ? null
                          : () async {
                              final id = await _pickStudent(ctx, ctrl);
                              if (id != null) setState(() => studentId = id);
                            },
                    ),
                    const SizedBox(height: 8),
                    for (final s in exam.subjects) ...[
                      TextField(
                        controller: controllers[s],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(labelText: s),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: remark,
                      decoration: const InputDecoration(labelText: '备注'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (studentId == null) return;
                        final scores = <String, double>{};
                        for (final s in exam.subjects) {
                          final raw = controllers[s]!.text.trim();
                          if (raw.isEmpty) continue;
                          final v = double.tryParse(raw);
                          if (v != null) scores[s] = v;
                        }
                        if (scores.isEmpty) return;
                        await ctrl.saveExamScore(
                          examId: exam.id,
                          studentId: studentId!,
                          scores: scores,
                          remark: remark.text,
                          id: existing?.id,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    remark.dispose();
  }

  Future<String?> _pickStudent(
    BuildContext context,
    ClassController ctrl,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('选择学生',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: ctrl.students.length,
                  itemBuilder: (_, i) {
                    final s = ctrl.students[i];
                    return ListTile(
                      title: Text(s.name),
                      subtitle: Text(
                        [
                          if (s.studentNo.isNotEmpty) s.studentNo,
                          if (s.groupName.isNotEmpty) s.groupName,
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.pop(ctx, s.id),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HighLowBarChart extends StatelessWidget {
  const _HighLowBarChart({required this.stats, required this.fullScore});

  final List<SubjectStat> stats;
  final double fullScore;

  @override
  Widget build(BuildContext context) {
    final subjects = [
      for (final s in stats)
        if (s.label != '总分' && s.count > 0) s,
    ];
    if (subjects.isEmpty) {
      return Center(
        child: Text('暂无数据', style: TextStyle(color: AppTheme.tertiaryLabel)),
      );
    }

    return BarChart(
      BarChartData(
        maxY: fullScore * 1.1,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: const BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v <= 0 ? '' : '${v.round()}',
                style: TextStyle(fontSize: 10, color: AppTheme.tertiaryLabel),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= subjects.length) {
                  return const SizedBox.shrink();
                }
                final label = subjects[i].label;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label.length > 2 ? label.substring(0, 2) : label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.separator.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < subjects.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                BarChartRodData(
                  toY: subjects[i].max,
                  width: 8,
                  color: AppTheme.blue,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: subjects[i].min,
                  width: 8,
                  color: const Color(0xFFFF9500),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.rank,
    required this.exam,
    required this.score,
    required this.onTap,
  });

  final int rank;
  final Exam exam;
  final ExamScore score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final stu = ctrl.studentById(score.studentId);
    final detail = exam.subjects
        .map((s) {
          final v = score.scoreOf(s);
          return v == null ? null : '$s ${ExamDetailScreen.fmt(v)}';
        })
        .whereType<String>()
        .join(' · ');

    return GroupedTile(
      title: stu?.name ?? '未知',
      subtitle: detail.isEmpty
          ? '总分 ${ExamDetailScreen.fmt(score.total)}'
          : detail,
      leading: RankBadge(rank: rank),
      trailing: Text(
        ExamDetailScreen.fmt(score.total),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
