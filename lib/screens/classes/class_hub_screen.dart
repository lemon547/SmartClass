import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/classes/class_features_screen.dart';
import 'package:smart_class/screens/classes/classes_screen.dart';
import 'package:smart_class/screens/duty/duty_screen.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/groups/groups_screen.dart';
import 'package:smart_class/screens/homework/homework_screen.dart';
import 'package:smart_class/screens/lessons/lesson_progress_screen.dart';
import 'package:smart_class/screens/notes/notes_screen.dart';
import 'package:smart_class/screens/points/point_rules_screen.dart';
import 'package:smart_class/screens/points/points_screen.dart';
import 'package:smart_class/screens/points/settlements_screen.dart';
import 'package:smart_class/screens/reports/weekly_report_screen.dart';
import 'package:smart_class/screens/rewards/rewards_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/seating/seating_screen.dart';
import 'package:smart_class/screens/semesters/semesters_screen.dart';
import 'package:smart_class/screens/timetable/timetable_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/screens/tools/fund_screen.dart';
import 'package:smart_class/screens/work_logs/work_logs_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 班级中心：切换班级后展示该班全部功能入口
class ClassHubScreen extends StatelessWidget {
  const ClassHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final current = ctrl.currentClass;
    final classId = current?.id ?? '';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const LargeTitle('班级'),
            _ClassScopeHeader(
              classes: ctrl.classes,
              current: current,
              onSelectClass: (id) => ctrl.switchClass(id),
              onManageClasses: () => _push(context, const ClassesScreen()),
              onClassFeatures: () =>
                  _push(context, const ClassFeaturesScreen()),
            ),
            if (ctrl.classes.isEmpty) ...[
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '添加班级后，可在此管理考勤、成绩、授课进度等班务功能。各班功能可单独配置。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryLabel,
                    height: 1.45,
                  ),
                ),
              ),
            ] else ...[
              if (ctrl.isFeatureVisible(ClassFeatureIds.points)) ...[
                const SizedBox(height: 18),
                GroupedSection(
                  header: '积分',
                  children: [
                    GroupedTile(
                      title: '积分排行',
                      subtitle: '${ctrl.students.length} 名学生',
                      onTap: () => _push(context, const PointsScreen()),
                    ),
                    GroupedTile(
                      title: '积分规则',
                      subtitle: ctrl.pointPresets.isEmpty
                          ? '自定义加分 / 扣分项'
                          : '${ctrl.pointPresets.where((p) => p.delta >= 0).length} 条加分 · ${ctrl.pointPresets.where((p) => p.delta < 0).length} 条扣分',
                      onTap: () => _push(context, const PointRulesScreen()),
                    ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.settlements)) ...[
                      GroupedTile(
                        title: '结算并重新开始',
                        subtitle: '保存排行快照后清零',
                        onTap: () => _settle(context),
                      ),
                      GroupedTile(
                        title: '结算记录',
                        subtitle: ctrl.settlements.isEmpty
                            ? '暂无'
                            : '${ctrl.settlements.length} 次',
                        onTap: () => _push(context, const SettlementsScreen()),
                      ),
                    ],
                    GroupedTile(
                      title: '导出积分排行',
                      subtitle: 'CSV 保存到本机',
                      onTap: () async {
                        final path = await ctrl.exportRankingFile();
                        await Clipboard.setData(ClipboardData(text: path));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已导出：\n$path')),
                        );
                      },
                    ),
                    GroupedTile(
                      title: '清空全部积分',
                      titleColor: AppTheme.destructive,
                      onTap: () => _resetPoints(context),
                    ),
                  ],
                ),
              ],
              if ([
                ClassFeatureIds.attendance,
                ClassFeatureIds.rollCall,
                ClassFeatureIds.homework,
                ClassFeatureIds.duty,
              ].any(ctrl.isFeatureVisible)) ...[
                const SizedBox(height: 18),
                GroupedSection(
                  header: '日常工作',
                  children: [
                    if (ctrl.isFeatureVisible(ClassFeatureIds.attendance))
                      GroupedTile(
                        title: '考勤',
                        subtitle: '今日出勤登记',
                        onTap: () => _push(context, const AttendanceScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.rollCall))
                      GroupedTile(
                        title: '随机点名',
                        onTap: () => _push(context, const RollCallScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.homework))
                      GroupedTile(
                        title: '作业检查',
                        onTap: () => _push(context, const HomeworkScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.duty))
                      GroupedTile(
                        title: '值日安排',
                        onTap: () => _push(context, const DutyScreen()),
                      ),
                  ],
                ),
              ],
              if ([
                ClassFeatureIds.grades,
                ClassFeatureIds.workLogs,
                ClassFeatureIds.timetable,
                ClassFeatureIds.seating,
                ClassFeatureIds.lessonProgress,
              ].any(ctrl.isFeatureVisible)) ...[
                const SizedBox(height: 18),
                GroupedSection(
                  header: '教学管理',
                  children: [
                    if (ctrl.isFeatureVisible(ClassFeatureIds.grades))
                      GroupedTile(
                        title: '成绩分析',
                        subtitle: ctrl.exams.isEmpty
                            ? '期末 · 半期 · 月考存档'
                            : '共 ${ctrl.exams.length} 次考试',
                        onTap: () => _push(context, const GradesScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.lessonProgress))
                      GroupedTile(
                        title: '授课进度',
                        subtitle: ctrl.lessonCountForClass(classId) == 0
                            ? '课时进度 · PPT 课件存档'
                            : '共 ${ctrl.lessonCountForClass(classId)} 课 · ${ctrl.lessonFileCountForClass(classId)} 个课件',
                        onTap: () =>
                            _push(context, const LessonProgressScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.workLogs))
                      GroupedTile(
                        title: '工作留痕',
                        subtitle: ctrl.workLogs.isEmpty
                            ? '班会 · 谈话 · 家访等'
                            : '共 ${ctrl.workLogs.length} 条',
                        onTap: () => _push(context, const WorkLogsScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.timetable))
                      GroupedTile(
                        title: '班级课表',
                        subtitle: ctrl.timetable.isEmpty
                            ? '点格子填写科目'
                            : '已排 ${ctrl.timetable.where((s) => s.subject.trim().isNotEmpty).length} 节',
                        onTap: () => _push(context, const TimetableScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.seating))
                      GroupedTile(
                        title: '座位表',
                        subtitle:
                            '${ctrl.profile.seatRows}×${ctrl.profile.seatCols}',
                        onTap: () => _push(context, const SeatingScreen()),
                      ),
                  ],
                ),
              ],
              if ([
                ClassFeatureIds.groups,
                ClassFeatureIds.rewards,
                ClassFeatureIds.countdowns,
                ClassFeatureIds.fund,
                ClassFeatureIds.notes,
                ClassFeatureIds.weeklyReport,
              ].any(ctrl.isFeatureVisible)) ...[
                const SizedBox(height: 18),
                GroupedSection(
                  header: '班级事务',
                  children: [
                    if (ctrl.isFeatureVisible(ClassFeatureIds.groups))
                      GroupedTile(
                        title: '小组',
                        subtitle: ctrl.groupNames.isEmpty
                            ? '未设置'
                            : '${ctrl.groupNames.length} 个小组',
                        onTap: () => _push(context, const GroupsScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.rewards))
                      GroupedTile(
                        title: '积分兑换',
                        onTap: () => _push(context, const RewardsScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.countdowns))
                      GroupedTile(
                        title: '倒数日',
                        subtitle: ctrl.nearestCountdown == null
                            ? '可设置多个倒计时'
                            : '${ctrl.upcomingCountdowns.length} 个进行中',
                        onTap: () => _push(context, const CountdownScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.fund))
                      GroupedTile(
                        title: '班费',
                        subtitle: '余额 ${ctrl.fundBalance}',
                        onTap: () => _push(context, const FundScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.notes))
                      GroupedTile(
                        title: '班级记事',
                        onTap: () => _push(context, const NotesScreen()),
                      ),
                    if (ctrl.isFeatureVisible(ClassFeatureIds.weeklyReport))
                      GroupedTile(
                        title: '本周概况',
                        onTap: () =>
                            _push(context, const WeeklyReportScreen()),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              GroupedSection(
                header: '班级数据',
                footer: '学期存档与汇总导出均针对当前所选班级。',
                children: [
                  if (ctrl.isFeatureVisible(ClassFeatureIds.semesters))
                    GroupedTile(
                      title: '学期',
                      subtitle: ctrl.activeSemester == null
                          ? '按学期存档与新开'
                          : '当前：${ctrl.activeSemester!.title}',
                      onTap: () => _push(context, const SemestersScreen()),
                    ),
                  GroupedTile(
                    title: '导出班级学期汇总',
                    subtitle: 'Excel：概况、考勤、成绩、积分、留痕',
                    onTap: () async {
                      try {
                        final path =
                            await ctrl.exportClassSemesterReportFile();
                        await Clipboard.setData(ClipboardData(text: path));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已导出（路径已复制）：\n$path')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('导出失败：$e')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _resetPoints(BuildContext context) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('清空全部积分？'),
        content: const Text('所有学生积分归零，积分记录也会删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().resetAllPoints();
    }
  }

  Future<void> _settle(BuildContext context) async {
    final name = TextEditingController(
      text: '第${context.read<ClassController>().settlements.length + 1}阶段',
    );
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('结算并重新开始？'),
        content: Column(
          children: [
            const SizedBox(height: 8),
            const Text('将保存当前排行快照，然后清空积分与记录。'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: name,
              placeholder: '阶段名称',
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('结算'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().settleAndRestart(name.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已结算，积分重新开始')),
        );
      }
    }
  }
}

class _ClassScopeHeader extends StatelessWidget {
  const _ClassScopeHeader({
    required this.classes,
    required this.current,
    required this.onSelectClass,
    required this.onManageClasses,
    required this.onClassFeatures,
  });

  final List<ManagedClass> classes;
  final ManagedClass? current;
  final ValueChanged<String> onSelectClass;
  final VoidCallback onManageClasses;
  final VoidCallback onClassFeatures;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Material(
          color: AppTheme.fill,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onManageClasses,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, color: AppTheme.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '添加班级',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '创建班级后即可使用下方功能',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppTheme.tertiaryLabel),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final active = current ?? classes.first;
    final subtitleParts = <String>[
      active.roleLabel,
      if (active.subject.trim().isNotEmpty) active.subject.trim(),
      if (active.school.trim().isNotEmpty) active.school.trim(),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前班级',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryLabel,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in classes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.displayTitle),
                      selected: c.id == active.id,
                      onSelected: (_) {
                        if (c.id != active.id) onSelectClass(c.id);
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: AppTheme.fill,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.displayTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleParts.join(' · '),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      TextButton.icon(
                        onPressed: onClassFeatures,
                        icon: const Icon(Icons.tune, size: 18),
                        label: const Text('本班功能'),
                      ),
                      TextButton(
                        onPressed: onManageClasses,
                        child: const Text('管理班级'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
