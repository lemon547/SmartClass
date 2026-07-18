import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/class_features_screen.dart';
import 'package:smart_class/screens/classes/classes_screen.dart';
import 'package:smart_class/screens/duty/duty_screen.dart';
import 'package:smart_class/screens/groups/groups_screen.dart';
import 'package:smart_class/screens/homework/homework_screen.dart';
import 'package:smart_class/screens/lessons/lesson_progress_screen.dart';
import 'package:smart_class/screens/notes/notes_screen.dart';
import 'package:smart_class/screens/points/point_rules_screen.dart';
import 'package:smart_class/screens/points/points_screen.dart';
import 'package:smart_class/screens/points/settlements_screen.dart';
import 'package:smart_class/screens/reports/weekly_report_screen.dart';
import 'package:smart_class/screens/rewards/rewards_screen.dart';
import 'package:smart_class/screens/seating/seating_screen.dart';
import 'package:smart_class/screens/semesters/semesters_screen.dart';
import 'package:smart_class/screens/timetable/timetable_screen.dart';
import 'package:smart_class/screens/tools/fund_screen.dart';
import 'package:smart_class/services/file_export.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

/// 班级设置：只放别的 Tab 没有的本班工具
class ClassHubScreen extends StatelessWidget {
  const ClassHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final current = ctrl.currentClass;
    final classId = current?.id ?? '';
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 20, 4),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(AppIcons.chevronLeft),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        '班级设置',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(canPop ? 56 : 20, 0, 20, 0),
              child: Text(
                '切换班级与本班工具；考勤、点名、留痕、成绩请用底部 Tab',
                style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
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
                onSwitchClass: () => showClassSwitcherSheet(context),
                onClassFeatures: () =>
                    _push(context, const ClassFeaturesScreen()),
                onManageClasses: () => _push(context, const ClassesScreen()),
              ),
            if (ctrl.classes.isNotEmpty)
              ..._buildSections(context, ctrl, classId),
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
          items: [
            for (final f in visible)
              _HubGridTile(
                icon: f.icon,
                label: f.title,
                tint: f.tint,
                badge: f.badge?.call(ctrl),
                onTap: () => f.onTap(context, ctrl, classId),
              ),
          ],
        ),
      );
    }

    addSection('本班工具', [
      _HubFeature(
        id: ClassFeatureIds.seating,
        title: '座位表',
        icon: AppIcons.users,
        tint: const Color(0xFF34C759),
        badge: (c) => '${c.profile.seatRows}×${c.profile.seatCols}',
        onTap: (ctx, _, __) => _push(ctx, const SeatingScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.groups,
        title: '小组',
        icon: AppIcons.users,
        tint: AppTheme.blue,
        badge: (c) => c.groupNames.isEmpty ? null : '${c.groupNames.length} 组',
        onTap: (ctx, _, __) => _push(ctx, const GroupsScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.duty,
        title: '值日安排',
        icon: AppIcons.calendar,
        tint: const Color(0xFFFF9500),
        onTap: (ctx, _, __) => _push(ctx, const DutyScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.homework,
        title: '作业检查',
        icon: AppIcons.clipboardList,
        tint: const Color(0xFF5856D6),
        onTap: (ctx, _, __) => _push(ctx, const HomeworkScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.timetable,
        title: '班级课表',
        icon: AppIcons.grid,
        tint: const Color(0xFF32ADE6),
        onTap: (ctx, _, __) => _push(ctx, const TimetableScreen()),
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
        onTap: (ctx, _, __) => _push(ctx, const LessonProgressScreen()),
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

    addSection('积分（本班）', [
      _HubFeature(
        id: ClassFeatureIds.points,
        title: '积分排行',
        icon: AppIcons.trophy,
        tint: const Color(0xFFFF9500),
        onTap: (ctx, _, __) => _push(ctx, const PointsScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.points,
        title: '积分规则',
        icon: AppIcons.sliders,
        tint: AppTheme.blue,
        onTap: (ctx, _, __) => _push(ctx, const PointRulesScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.rewards,
        title: '积分兑换',
        icon: AppIcons.gift,
        tint: const Color(0xFFFF9500),
        onTap: (ctx, _, __) => _push(ctx, const RewardsScreen()),
      ),
      _HubFeature(
        id: ClassFeatureIds.settlements,
        title: '结算记录',
        icon: AppIcons.clock,
        tint: const Color(0xFFAF52DE),
        badge: (c) =>
            c.settlements.isEmpty ? null : '${c.settlements.length} 次',
        onTap: (ctx, _, __) => _push(ctx, const SettlementsScreen()),
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
    sections.add(const SizedBox(height: 20));
    sections.add(
      GroupedSection(
        header: '数据与存档',
        footer: '仅针对当前所选班级。',
        children: dataItems,
      ),
    );
    return sections;
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
                  '创建班级后，可在此管理座位、值日、班费等本班工具',
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? tint;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppTheme.blue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
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
