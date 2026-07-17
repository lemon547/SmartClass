import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/classes/classes_screen.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/timetable/timetable_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

String _todayLabel() {
  final n = DateTime.now();
  const week = ['一', '二', '三', '四', '五', '六', '日'];
  return '${n.month}月${n.day}日 周${week[n.weekday - 1]}';
}

/// 首页：参考钉钉教师工作台「班级优先 + 概览卡片 + 快捷工具」
/// 与 iOS 分组列表的信息层级，不另造视觉风格。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final present = ctrl.selectedDate == ctrl.todayKey
        ? ctrl.countStatus(AttendanceStatus.present)
        : null;
    final leave = ctrl.selectedDate == ctrl.todayKey
        ? ctrl.countStatus(AttendanceStatus.leave)
        : null;
    final top = ctrl.rankedByPoints.take(5).toList();
    final todayDuty = ctrl.dutyList
        .where((d) => d.weekday == DateTime.now().weekday)
        .toList();
    final birthdays = ctrl.todayBirthdays;
    final upcoming = ctrl.upcomingCountdowns.take(3).toList();
    final todayCourses = ctrl.todaySubjects;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            PaddiHomeAccent(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _todayLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showClassSwitcher(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              ctrl.profile.displayTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontSize: 28,
                                    height: 1.15,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more,
                            color: AppTheme.tertiaryLabel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        ctrl.currentClass?.roleLabel ?? '班主任',
                        if (ctrl.activeSemester != null)
                          ctrl.activeSemester!.title,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            // 班级概览卡
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    QuietStat(
                      label: '学生',
                      value: '${ctrl.students.length}',
                      center: true,
                    ),
                    SizedBox(
                      height: 36,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: AppTheme.separator,
                      ),
                    ),
                    QuietStat(
                      label: '出勤',
                      value: '${present ?? '—'}',
                      center: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const AttendanceScreen()),
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: AppTheme.separator,
                      ),
                    ),
                    QuietStat(
                      label: '请假',
                      value: '${leave ?? '—'}',
                      center: true,
                    ),
                  ],
                ),
              ),
            ),
            if (birthdays.isNotEmpty) ...[
              const SizedBox(height: 16),
              GroupedSection(
                header: '今日提醒',
                children: [
                  GroupedTile(
                    title: '今日生日',
                    subtitle: birthdays.map((s) => s.name).join('、'),
                    leading: Icon(AppIcons.cake, color: AppTheme.blue),
                  ),
                ],
              ),
            ],
            if (ctrl.isFeatureVisible(ClassFeatureIds.countdowns)) ...[
            const SizedBox(height: 16),
            GroupedSection(
              header: '倒数日',
              footer: upcoming.isEmpty ? '可添加考试、放假等多个日期' : null,
              children: [
                if (upcoming.isEmpty)
                  GroupedTile(
                    title: '添加倒数日',
                    subtitle: '支持设置多个倒计时',
                    leading: Icon(AppIcons.hourglass, color: AppTheme.blue),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CountdownScreen()),
                    ),
                  )
                else ...[
                  for (final c in upcoming)
                    GroupedTile(
                      title: c.title,
                      subtitle: c.targetDate,
                      leading: _DaysChip(days: c.daysLeft),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CountdownScreen()),
                      ),
                    ),
                  if (ctrl.upcomingCountdowns.length > 3 ||
                      ctrl.countdowns.length > upcoming.length)
                    GroupedTile(
                      title: '查看全部',
                      subtitle: '共 ${ctrl.countdowns.length} 个',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const CountdownScreen()),
                      ),
                    ),
                ],
              ],
            ),
            ],
            const SizedBox(height: 16),
            GroupedSection(
              header: '今日课程',
              children: [
                if (todayCourses.isEmpty)
                  GroupedTile(
                    title: '今天暂无课程',
                    subtitle: '去课程表里填写本周安排',
                    leading: Icon(AppIcons.book, color: AppTheme.blue),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TimetableScreen()),
                    ),
                  )
                else
                  GroupedTile(
                    title: todayCourses.join(' · '),
                    subtitle: '共 ${todayCourses.length} 节 · 点按打开课程表',
                    leading: Icon(AppIcons.book, color: AppTheme.blue),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const TimetableScreen()),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // 快捷工具：按本班功能显隐
            Builder(
              builder: (context) {
                final shortcuts = <Widget>[];
                void add({
                  required String id,
                  required IconData icon,
                  required String label,
                  required Color tint,
                  String? sticker,
                  required VoidCallback onTap,
                }) {
                  if (!ctrl.isFeatureVisible(id)) return;
                  shortcuts.add(
                    Expanded(
                      child: HomeShortcut(
                        icon: icon,
                        label: label,
                        tint: tint,
                        sticker: sticker,
                        onTap: onTap,
                      ),
                    ),
                  );
                }

                add(
                  id: ClassFeatureIds.rollCall,
                  icon: AppIcons.dices,
                  label: '点名',
                  tint: AppTheme.blue,
                  sticker: MascotAssets.emote,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RollCallScreen()),
                  ),
                );
                add(
                  id: ClassFeatureIds.attendance,
                  icon: AppIcons.attendance,
                  label: '考勤',
                  tint: const Color(0xFF32ADE6),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                  ),
                );
                add(
                  id: ClassFeatureIds.points,
                  icon: AppIcons.circlePlus,
                  label: '加分',
                  tint: const Color(0xFF34C759),
                  sticker: MascotAssets.wave,
                  onTap: () => _quickPoints(context, true),
                );
                add(
                  id: ClassFeatureIds.grades,
                  icon: AppIcons.chart,
                  label: '成绩',
                  tint: const Color(0xFF5856D6),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GradesScreen()),
                  ),
                );

                if (shortcuts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 2),
                          child: Text(
                            '常用工具',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.tertiaryLabel,
                            ),
                          ),
                        ),
                        Row(children: shortcuts),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (ctrl.students.isEmpty) ...[
              const SizedBox(height: 12),
              GroupedSection(
                children: [
                  GroupedTile(
                    title: '填充演示数据',
                    subtitle: '含小组与奖品示例，快速体验',
                    leading: Icon(AppIcons.users, color: AppTheme.blue),
                    onTap: () => ctrl.seedDemo(),
                  ),
                ],
              ),
            ],
            if (ctrl.isFeatureVisible(ClassFeatureIds.points)) ...[
            const SizedBox(height: 16),
            GroupedSection(
              header: '积分榜',
              footer: top.isEmpty ? '添加学生后显示排行' : '显示前 ${top.length} 名',
              children: [
                if (top.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: PaddiEmptyHint(message: '暂无数据'),
                    ),
                  )
                else
                  for (var i = 0; i < top.length; i++)
                    GroupedTile(
                      title: top[i].name,
                      subtitle: [
                        if (top[i].role.isNotEmpty) top[i].role,
                        if (top[i].groupName.isNotEmpty) top[i].groupName,
                      ].isEmpty
                          ? null
                          : [
                              if (top[i].role.isNotEmpty) top[i].role,
                              if (top[i].groupName.isNotEmpty)
                                top[i].groupName,
                            ].join(' · '),
                      leading: RankBadge(rank: i + 1),
                      trailing: Text(
                        '${top[i].points}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: i == 0 ? AppTheme.blue : AppTheme.secondaryLabel,
                        ),
                      ),
                    ),
              ],
            ),
            ],
            if (ctrl.isFeatureVisible(ClassFeatureIds.duty) &&
                todayDuty.isNotEmpty) ...[
              const SizedBox(height: 16),
              GroupedSection(
                header: '今日值日',
                children: [
                  for (final d in todayDuty)
                    GroupedTile(
                      title: ctrl.studentById(d.studentId)?.name ?? '未知',
                      subtitle: d.task,
                      leading: Icon(AppIcons.clipboardList,
                          color: AppTheme.blue, size: 22),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _quickPoints(BuildContext context, bool positive) async {
    final ctrl = context.read<ClassController>();
    if (ctrl.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加学生')),
      );
      return;
    }
    final presets = ctrl.pointPresets
        .where((p) => positive ? p.delta >= 0 : p.delta < 0)
        .toList();
    final fallback = positive
        ? const PointReasonPreset(reason: '表扬', delta: 2)
        : const PointReasonPreset(reason: '提醒', delta: -1);
    final list = presets.isEmpty ? [fallback] : presets;
    String? studentId = ctrl.students.first.id;
    var selected = list.first;
    var amount = selected.delta.abs().clamp(1, 99);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.quaternaryLabel,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    positive ? '快速加分' : '快速扣分',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: studentId,
                    items: [
                      for (final s in ctrl.students)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => studentId = v),
                    decoration: const InputDecoration(labelText: '学生'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in list)
                        ChoiceChip(
                          label: Text(
                            '${p.reason} ${p.delta > 0 ? '+' : ''}${p.delta}',
                          ),
                          selected: selected.reason == p.reason,
                          onSelected: (_) => setState(() {
                            selected = p;
                            amount = p.delta.abs().clamp(1, 99);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('分值', style: TextStyle(fontSize: 17)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() {
                          if (amount > 1) amount--;
                        }),
                        icon: const Icon(AppIcons.circleMinus),
                      ),
                      Text('$amount',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w600)),
                      IconButton(
                        onPressed: () => setState(() => amount++),
                        icon: const Icon(AppIcons.circlePlus),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: studentId == null
                        ? null
                        : () async {
                            await ctrl.adjustPoints(
                              studentId: studentId!,
                              delta: positive ? amount : -amount,
                              reason: selected.reason,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('确认'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
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
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ClassesScreen()),
                      );
                    },
                    child: const Text('管理'),
                  ),
                ],
              ),
            ),
            for (final c in ctrl.classes)
              ListTile(
                title: Text(c.displayTitle),
                subtitle: Text(c.roleLabel),
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

class _DaysChip extends StatelessWidget {
  const _DaysChip({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final urgent = days <= 7;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: urgent
            ? AppTheme.blue.withValues(alpha: 0.12)
            : AppTheme.fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            days == 0 ? '今' : '$days',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.05,
              color: urgent ? AppTheme.blue : AppTheme.label,
            ),
          ),
          Text(
            '天',
            style: TextStyle(
              fontSize: 10,
              color: urgent ? AppTheme.blue : AppTheme.tertiaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}
