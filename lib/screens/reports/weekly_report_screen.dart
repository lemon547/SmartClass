import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  Map<String, int>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await context.read<ClassController>().weekStats();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final attSlices = [
      for (final s in AttendanceStatus.values)
        ChartSlice(
          label: s.label,
          value: (_stats?[s.name] ?? 0).toDouble(),
          color: _attColor(s),
        ),
    ];
    final top = ctrl.rankedByPoints.take(5).toList();

    return Scaffold(
      appBar: PageAppBar(title: const Text('本周概况')),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 28),
              children: [
                ChartCard(
                  title: '本周考勤构成',
                  height: 180,
                  child: SimpleDonutChart(slices: attSlices),
                ),
                GroupedSection(
                  header: '本周考勤人次',
                  children: [
                    for (final s in AttendanceStatus.values)
                      GroupedTile(
                        title: s.label,
                        trailing: Text('${_stats?[s.name] ?? 0}'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                GroupedSection(
                  header: '班级概况',
                  children: [
                    GroupedTile(
                      title: '学生人数',
                      trailing: Text('${ctrl.students.length}'),
                    ),
                    GroupedTile(
                      title: '小组数',
                      trailing: Text('${ctrl.groupNames.length}'),
                    ),
                    GroupedTile(
                      title: '平均积分',
                      trailing: Text(
                        ctrl.students.isEmpty
                            ? '0'
                            : (ctrl.students
                                        .map((e) => e.points)
                                        .reduce((a, b) => a + b) /
                                    ctrl.students.length)
                                .toStringAsFixed(1),
                      ),
                    ),
                  ],
                ),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ChartCard(
                    title: '积分 Top 5',
                    height: top.length * 28.0 + 8,
                    child: HorizontalRankChart(
                      items: [
                        for (final s in top)
                          ChartBarItem(
                            label: s.name,
                            value: s.points.toDouble(),
                          ),
                      ],
                    ),
                  ),
                ],
                GroupedSection(
                  header: '积分 Top 5',
                  children: [
                    for (final s in top)
                      GroupedTile(
                        title: s.name,
                        trailing: Text('${s.points}'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    '数据仅统计本周一至周日已登记的考勤记录。',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _attColor(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => const Color(0xFF34C759),
        AttendanceStatus.late => const Color(0xFFFF9500),
        AttendanceStatus.leave => AppTheme.blue,
        AttendanceStatus.absent => AppTheme.destructive,
      };
}
