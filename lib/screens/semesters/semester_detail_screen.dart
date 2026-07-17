import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/data_charts.dart';

class SemesterDetailScreen extends StatelessWidget {
  const SemesterDetailScreen({super.key, required this.semesterId});

  final String semesterId;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final semester = ctrl.semesterById(semesterId);
    if (semester == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('学期')),
        body: const Center(child: Text('学期不存在')),
      );
    }

    if (semester.isActive) {
      return _ActiveSemesterView(semester: semester);
    }
    return _ArchivedSemesterView(semester: semester);
  }
}

class _ActiveSemesterView extends StatelessWidget {
  const _ActiveSemesterView({required this.semester});

  final Semester semester;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final top = ctrl.rankedByPoints.take(8).toList();

    return Scaffold(
      appBar: AppBar(title: Text(semester.title)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 8),
          GroupedSection(
            header: '概况',
            children: [
              GroupedTile(title: '状态', trailing: const Text('进行中')),
              GroupedTile(
                title: '开始',
                trailing: Text(semester.startDate.isEmpty ? '—' : semester.startDate),
              ),
              if (semester.schoolYear.isNotEmpty)
                GroupedTile(title: '学年', trailing: Text(semester.schoolYear)),
              if (semester.term.isNotEmpty)
                GroupedTile(title: '学期', trailing: Text(semester.term)),
              GroupedTile(
                title: '学生',
                trailing: Text('${ctrl.students.length} 人'),
              ),
              GroupedTile(
                title: '考试存档',
                trailing: Text('${ctrl.exams.length} 次'),
              ),
              GroupedTile(
                title: '工作留痕',
                trailing: Text('${ctrl.workLogs.length} 条'),
              ),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 8),
            ChartCard(
              title: '当前积分 Top',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              '详细数据可在首页、积分、成绩、留痕等模块查看。结束学期后会生成只读存档。',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedSemesterView extends StatelessWidget {
  const _ArchivedSemesterView({required this.semester});

  final Semester semester;

  @override
  Widget build(BuildContext context) {
    final snap = semester.snapshotMap ?? {};
    final stats = (snap['stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final ranking = (snap['ranking'] as List?) ?? const [];
    final exams = (snap['exams'] as List?) ?? const [];
    final workLogs = (snap['work_logs'] as List?) ?? const [];
    final rankMaps = [
      for (final item in ranking) Map<String, dynamic>.from(item as Map),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(semester.title),
        actions: [
          IconButton(
            tooltip: '删除存档',
            onPressed: () => _delete(context),
            icon: Icon(AppIcons.trash, color: AppTheme.destructive),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 8),
          GroupedSection(
            header: '学期信息',
            children: [
              GroupedTile(title: '状态', trailing: const Text('已存档')),
              GroupedTile(
                title: '起止',
                subtitle:
                    '${semester.startDate.isEmpty ? '—' : semester.startDate} ~ ${semester.endDate.isEmpty ? '—' : semester.endDate}',
              ),
              if (semester.archivedAt != null)
                GroupedTile(
                  title: '存档时间',
                  trailing: Text(
                    DateFormat('yyyy/M/d HH:mm').format(semester.archivedAt!),
                  ),
                ),
              if (semester.note.isNotEmpty)
                GroupedTile(title: '备注', subtitle: semester.note),
            ],
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '数据概况',
            children: [
              GroupedTile(
                title: '学生',
                trailing: Text('${stats['studentCount'] ?? '—'} 人'),
              ),
              GroupedTile(
                title: '平均积分',
                trailing: Text(_num(stats['avgPoints'])),
              ),
              GroupedTile(
                title: '最高积分',
                trailing: Text('${stats['topPoints'] ?? '—'}'),
              ),
              GroupedTile(
                title: '考试',
                trailing: Text('${stats['examCount'] ?? 0} 次'),
              ),
              GroupedTile(
                title: '工作留痕',
                trailing: Text('${stats['workLogCount'] ?? 0} 条'),
              ),
              GroupedTile(
                title: '考勤记录',
                trailing: Text('${stats['attendanceCount'] ?? 0} 条'),
              ),
              GroupedTile(
                title: '积分流水',
                trailing: Text('${stats['pointRecordCount'] ?? 0} 条'),
              ),
            ],
          ),
          if (rankMaps.isNotEmpty) ...[
            const SizedBox(height: 8),
            ChartCard(
              title: '学期积分排行 Top 10',
              height: rankMaps.take(10).length * 28.0 + 8,
              child: HorizontalRankChart(
                items: [
                  for (final m in rankMaps.take(10))
                    ChartBarItem(
                      label: '${m['name'] ?? '?'}',
                      value: (m['points'] as num?)?.toDouble() ?? 0,
                    ),
                ],
              ),
            ),
            GroupedSection(
              header: '积分榜',
              children: [
                for (final raw in rankMaps.take(20))
                  GroupedTile(
                    title: '${raw['rank']}. ${raw['name'] ?? ''}',
                    subtitle: () {
                      final sub = [
                        if ((raw['studentNo'] as String?)?.isNotEmpty == true)
                          raw['studentNo'] as String,
                        if ((raw['groupName'] as String?)?.isNotEmpty == true)
                          raw['groupName'] as String,
                        if ((raw['role'] as String?)?.isNotEmpty == true)
                          raw['role'] as String,
                      ].join(' · ');
                      return sub.isEmpty ? null : sub;
                    }(),
                    trailing: Text('${raw['points'] ?? 0}'),
                  ),
              ],
            ),
          ],
          if (exams.isNotEmpty) ...[
            const SizedBox(height: 18),
            GroupedSection(
              header: '考试存档 (${exams.length})',
              children: [
                for (final raw in exams.take(30))
                  GroupedTile(
                    title: '${(raw as Map)['title'] ?? '考试'}',
                    subtitle: [
                      raw['category'],
                      raw['exam_date'],
                    ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                  ),
              ],
            ),
          ],
          if (workLogs.isNotEmpty) ...[
            const SizedBox(height: 18),
            GroupedSection(
              header: '工作留痕 (${workLogs.length})',
              children: [
                for (final raw in workLogs.take(30))
                  GroupedTile(
                    title: '${(raw as Map)['title'] ?? '记录'}',
                    subtitle: [
                      _workLogCategoryLabel(raw['category'] as String?),
                      raw['date'],
                    ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _num(Object? v) {
    if (v is num) {
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    }
    return '—';
  }

  String? _workLogCategoryLabel(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return WorkLogCategory.fromStorage(raw).label;
    } catch (_) {
      return raw;
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${semester.title}」存档？'),
        content: const Text('删除后无法恢复该学期快照。'),
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
    await context.read<ClassController>().deleteArchivedSemester(semester.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}
