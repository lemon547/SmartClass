import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:smart_class/services/file_export.dart';
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
import 'package:smart_class/theme/app_icons.dart';
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
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                '班级',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (ctrl.classes.isEmpty)
              _EmptyClassCard(
                onAdd: () => _push(context, const ClassesScreen()),
              )
            else
              _ClassHeroCard(
                current: current!,
                studentCount: ctrl.students.length,
                groupCount: ctrl.groupNames.length,
                examCount: ctrl.exams.length,
                onSwitchClass: () => _showClassSwitcher(context),
                onClassFeatures: () =>
                    _push(context, const ClassFeaturesScreen()),
                onManageClasses: () => _push(context, const ClassesScreen()),
              ),
            if (ctrl.classes.isNotEmpty) ...[
              if (ctrl.isFeatureVisible(ClassFeatureIds.points)) ...[
                const SizedBox(height: 20),
                _PointsHighlight(
                  ctrl: ctrl,
                  onRanking: () => _push(context, const PointsScreen()),
                  onMore: () => _showPointsTools(context),
                ),
              ],
              ..._buildSections(context, ctrl, classId),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    ClassController ctrl,
    String classId,
  ) {
    final sections = <Widget>[];

    void addSection(String header, List<_HubFeature> items) {
      final visible = items.where((f) => ctrl.isFeatureVisible(f.id)).toList();
      if (visible.isEmpty) return;
      sections.add(const SizedBox(height: 20));
      sections.add(
        _FeatureGridSection(
          header: header,
          items: visible
              .map(
                (f) => _HubGridTile(
                  icon: f.icon,
                  label: f.title,
                  tint: f.tint,
                  badge: f.badge?.call(ctrl),
                  onTap: () => f.onTap(context, ctrl, classId),
                ),
              )
              .toList(),
        ),
      );
    }

    addSection('日常教学', [
      _HubFeature(
        id: ClassFeatureIds.attendance,
        title: '考勤',
        icon: AppIcons.attendance,
        tint: const Color(0xFF32ADE6),
        badge: (_) => '今日登记',
        onTap: (ctx, _, __) => _push(ctx, const AttendanceScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.rollCall,
        title: '随机点名',
        icon: AppIcons.dices,
        tint: AppTheme.blue,
        onTap: (ctx, _, __) => _push(ctx, const RollCallScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.homework,
        title: '作业检查',
        icon: AppIcons.clipboardList,
        tint: const Color(0xFF5856D6),
        onTap: (ctx, _, __) => _push(ctx, const HomeworkScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.duty,
        title: '值日安排',
        icon: AppIcons.calendar,
        tint: const Color(0xFFFF9500),
        onTap: (ctx, _, __) => _push(ctx, const DutyScreen()),
      ),
    ]);

    addSection('教学管理', [
      _HubFeature(
        id: ClassFeatureIds.grades,
        title: '成绩分析',
        icon: AppIcons.chart,
        tint: const Color(0xFF5856D6),
        badge: (c) =>
            c.exams.isEmpty ? null : '${c.exams.length} 次考试',
        onTap: (ctx, _, __) => _push(ctx, const GradesScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.lessonProgress,
        title: '授课进度',
        icon: AppIcons.book,
        tint: AppTheme.blue,
        badge: (c) {
          final n = c.lessonCountForClass(classId);
          return n == 0 ? null : '$n 课';
        },
        onTap: (ctx, _, id) =>
            _push(ctx, const LessonProgressScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.timetable,
        title: '班级课表',
        icon: AppIcons.grid,
        tint: const Color(0xFF32ADE6),
        onTap: (ctx, _, __) => _push(ctx, const TimetableScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.seating,
        title: '座位表',
        icon: AppIcons.users,
        tint: const Color(0xFF34C759),
        badge: (c) => '${c.profile.seatRows}×${c.profile.seatCols}',
        onTap: (ctx, _, __) => _push(ctx, const SeatingScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.workLogs,
        title: '工作留痕',
        icon: AppIcons.notebook,
        tint: const Color(0xFFFF9500),
        badge: (c) =>
            c.workLogs.isEmpty ? null : '${c.workLogs.length} 条',
        onTap: (ctx, _, __) => _push(ctx, const WorkLogsScreen()),
      ),
    ]);

    addSection('班级生活', [
      _HubFeature(
        id: ClassFeatureIds.groups,
        title: '小组',
        icon: AppIcons.users,
        tint: AppTheme.blue,
        badge: (c) =>
            c.groupNames.isEmpty ? null : '${c.groupNames.length} 组',
        onTap: (ctx, _, __) => _push(ctx, const GroupsScreen()),
      ),
      if (!ctrl.isFeatureVisible(ClassFeatureIds.points))
        _HubFeature(
          id: ClassFeatureIds.rewards,
          title: '积分兑换',
          icon: AppIcons.gift,
          tint: const Color(0xFFFF9500),
          onTap: (ctx, _, __) => _push(ctx, const RewardsScreen()),
        ),
      _HubFeature(
        id: ClassFeatureIds.countdowns,
        title: '倒数日',
        icon: AppIcons.hourglass,
        tint: const Color(0xFF5856D6),
        badge: (c) {
          final n = c.upcomingCountdowns.length;
          return n == 0 ? null : '$n 个';
        },
        onTap: (ctx, _, __) => _push(ctx, const CountdownScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.fund,
        title: '班费',
        icon: AppIcons.wallet,
        tint: const Color(0xFF34C759),
        badge: (c) => '¥${c.fundBalance}',
        onTap: (ctx, _, __) => _push(ctx, const FundScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.notes,
        title: '班级记事',
        icon: AppIcons.notebook,
        tint: const Color(0xFF32ADE6),
        onTap: (ctx, _, __) => _push(ctx, const NotesScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.weeklyReport,
        title: '本周概况',
        icon: AppIcons.clipboardList,
        tint: AppTheme.blue,
        onTap: (ctx, _, __) => _push(ctx, const WeeklyReportScreen()),
      ),
    ]);

    final dataItems = <Widget>[];
    if (ctrl.isFeatureVisible(ClassFeatureIds.semesters)) {
      dataItems.add(
        GroupedTile(
          leading: Icon(AppIcons.calendar, color: AppTheme.blue, size: 22),
          title: '学期存档',
          subtitle: ctrl.activeSemester == null
              ? '按学期存档与新开'
              : '当前：${ctrl.activeSemester!.title}',
          onTap: () => _push(context, const SemestersScreen()),
        ),
      );
    }
    dataItems.add(
      GroupedTile(
        leading: Icon(AppIcons.fileSheet, color: AppTheme.blue, size: 22),
        title: '导出学期汇总',
        subtitle: 'Excel：概况、考勤、成绩、积分、留痕',
        onTap: () async {
          try {
            final saved = await FileExport.saveGenerated(
              () => ctrl.exportClassSemesterReportFile(),
              dialogTitle: '保存学期汇总',
            );
            if (!context.mounted) return;
            FileExport.showSavedSnackBar(context, saved);
          } catch (e) {
            FileExport.showErrorSnackBar(context, e);
          }
        },
      ),
    );
    if (dataItems.isNotEmpty) {
      sections.add(const SizedBox(height: 20));
      sections.add(
        GroupedSection(
          header: '数据与存档',
          footer: '学期存档与汇总导出均针对当前所选班级。',
          children: dataItems,
        ),
      );
    }

    return sections;
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _showClassSwitcher(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Text('切换班级', style: Theme.of(ctx).textTheme.titleMedium),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _push(context, const ClassesScreen());
                      },
                      child: const Text('管理'),
                    ),
                  ],
                ),
              ),
              for (final c in ctrl.classes)
                ListTile(
                  title: Text(c.displayTitle),
                  subtitle: Text(
                    [
                      if (c.school.trim().isNotEmpty) c.school.trim(),
                      c.roleLabel,
                    ].join(' · '),
                  ),
                  trailing: c.id == ctrl.currentClass?.id
                      ? Icon(Icons.check, color: AppTheme.blue)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ctrl.switchClass(c.id);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPointsTools(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '积分工具',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
              ),
              if (ctrl.isFeatureVisible(ClassFeatureIds.settlements)) ...[
                ListTile(
                  leading: Icon(AppIcons.trophy, color: AppTheme.blue),
                  title: const Text('结算并重新开始'),
                  subtitle: const Text('保存排行快照后清零'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _settle(context);
                  },
                ),
                ListTile(
                  leading: Icon(AppIcons.clock, color: AppTheme.blue),
                  title: const Text('结算记录'),
                  subtitle: Text(
                    ctrl.settlements.isEmpty
                        ? '暂无'
                        : '${ctrl.settlements.length} 次',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _push(context, const SettlementsScreen());
                  },
                ),
              ],
              ListTile(
                leading: Icon(AppIcons.download, color: AppTheme.blue),
                title: const Text('导出积分排行'),
                subtitle: const Text('CSV 保存到本机'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final saved = await FileExport.saveGenerated(
                      () => ctrl.exportRankingFile(),
                      dialogTitle: '保存积分排行',
                    );
                    if (!context.mounted) return;
                    FileExport.showSavedSnackBar(context, saved);
                  } catch (e) {
                    FileExport.showErrorSnackBar(context, e);
                  }
                },
              ),
              ListTile(
                leading: Icon(AppIcons.trash, color: AppTheme.destructive),
                title: Text(
                  '清空全部积分',
                  style: TextStyle(color: AppTheme.destructive),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _resetPoints(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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

class _HubFeature {
  const _HubFeature({
    required this.id,
    required this.title,
    required this.icon,
    required this.tint,
    required this.onTap,
    this.badge,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color tint;
  final String? Function(ClassController ctrl)? badge;
  final void Function(
    BuildContext context,
    ClassController ctrl,
    String classId,
  ) onTap;
}

class _EmptyClassCard extends StatelessWidget {
  const _EmptyClassCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onAdd,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(AppIcons.classes, color: AppTheme.blue, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  '添加班级',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '创建班级后即可使用考勤、成绩、授课进度等班务功能',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.secondaryLabel,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassHeroCard extends StatelessWidget {
  const _ClassHeroCard({
    required this.current,
    required this.studentCount,
    required this.groupCount,
    required this.examCount,
    required this.onSwitchClass,
    required this.onClassFeatures,
    required this.onManageClasses,
  });

  final ManagedClass current;
  final int studentCount;
  final int groupCount;
  final int examCount;
  final VoidCallback onSwitchClass;
  final VoidCallback onClassFeatures;
  final VoidCallback onManageClasses;

  @override
  Widget build(BuildContext context) {
    final school = current.school.trim();
    final initial = school.isNotEmpty
        ? school.substring(0, 1)
        : current.displayTitle.substring(0, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                onTap: onSwitchClass,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    current.displayTitle,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.expand_more,
                                  size: 22,
                                  color: AppTheme.tertiaryLabel,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final tag in current.roleTags)
                                  _RoleChip(label: tag),
                              ],
                            ),
                            if (school.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                school,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.tertiaryLabel,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, color: AppTheme.separator),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _HeroStat(value: '$studentCount', label: '学生'),
                  _HeroStat(value: '$groupCount', label: '小组'),
                  _HeroStat(value: '$examCount', label: '考试'),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.separator),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _HeroAction(
                      icon: AppIcons.sliders,
                      label: '本班功能',
                      onTap: onClassFeatures,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppTheme.separator,
                  ),
                  Expanded(
                    child: _HeroAction(
                      icon: AppIcons.settings,
                      label: '管理班级',
                      onTap: onManageClasses,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: AppTheme.secondaryLabel),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppTheme.blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsHighlight extends StatelessWidget {
  const _PointsHighlight({
    required this.ctrl,
    required this.onRanking,
    required this.onMore,
  });

  final ClassController ctrl;
  final VoidCallback onRanking;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final top = ctrl.rankedByPoints.take(3).toList();
    final addCount =
        ctrl.pointPresets.where((p) => p.delta >= 0).length;
    final subCount =
        ctrl.pointPresets.where((p) => p.delta < 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Text(
                  '积分',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.tertiaryLabel,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onMore,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('更多'),
                ),
              ],
            ),
          ),
          Material(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                InkWell(
                  onTap: onRanking,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            AppIcons.trophy,
                            color: Color(0xFFFF9500),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '积分排行',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                top.isEmpty
                                    ? '${ctrl.students.length} 名学生'
                                    : top
                                        .map((s) => '${s.name} ${s.points}')
                                        .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRight,
                          size: 18,
                          color: AppTheme.tertiaryLabel,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppTheme.separator),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HubGridTile(
                          icon: AppIcons.sliders,
                          label: '积分规则',
                          tint: AppTheme.blue,
                          badge: ctrl.pointPresets.isEmpty
                              ? null
                              : '$addCount+ · $subCount−',
                          compact: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PointRulesScreen(),
                            ),
                          ),
                        ),
                      ),
                      if (ctrl.isFeatureVisible(ClassFeatureIds.rewards))
                        Expanded(
                          child: _HubGridTile(
                            icon: AppIcons.gift,
                            label: '积分兑换',
                            tint: const Color(0xFFFF9500),
                            compact: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RewardsScreen(),
                              ),
                            ),
                          ),
                        ),
                      if (ctrl.isFeatureVisible(ClassFeatureIds.settlements))
                        Expanded(
                          child: _HubGridTile(
                            icon: AppIcons.clock,
                            label: '结算',
                            tint: const Color(0xFF5856D6),
                            badge: ctrl.settlements.isEmpty
                                ? null
                                : '${ctrl.settlements.length}',
                            compact: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettlementsScreen(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureGridSection extends StatelessWidget {
  const _FeatureGridSection({
    required this.header,
    required this.items,
  });

  final String header;
  final List<_HubGridTile> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.tertiaryLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const cols = 4;
                const spacing = 4.0;
                final cellW =
                    (constraints.maxWidth - spacing * (cols - 1)) / cols;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final item in items)
                      SizedBox(width: cellW, child: item),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HubGridTile extends StatelessWidget {
  const _HubGridTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tint,
    this.badge,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;
  final String? badge;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppTheme.blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: compact ? 6 : 10,
          horizontal: 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 40 : 48,
              height: compact ? 40 : 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(compact ? 12 : 14),
              ),
              child: Icon(icon, size: compact ? 20 : 24, color: color),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.label,
              ),
            ),
            if (badge != null && badge!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                badge!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
