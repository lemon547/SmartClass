import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/home/widgets/home_todo_card.dart';
import 'package:smart_class/screens/leave/leave_screen.dart';
import 'package:smart_class/screens/points/quick_points_screen.dart';
import 'package:smart_class/screens/students/students_screen.dart';
import 'package:smart_class/screens/timetable/teacher_timetable_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/screens/work_logs/work_logs_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

const _cardRadius = 16.0;
const _sectionGap = 12.0;

/// 问候与日期按北京时间，避免模拟器时区不准
DateTime _chinaNow() =>
    DateTime.now().toUtc().add(const Duration(hours: 8));

String _todayLine() {
  final n = _chinaNow();
  const week = ['一', '二', '三', '四', '五', '六', '日'];
  return '${n.month}月${n.day}日 星期${week[n.weekday - 1]}';
}

String _greeting() {
  final h = _chinaNow().hour;
  if (h < 11) return '早上好~';
  if (h < 14) return '中午好~';
  if (h < 18) return '下午好~';
  return '晚上好~';
}

/// 今日工作台：授课 → 待办 → 提醒 → 工具
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final theme = context.watch<ThemeController>();
    final birthdays = ctrl.todayBirthdays;
    final nearest = ctrl.nearestCountdown;
    final lessons = ctrl.todayTeachingLessons;
    final pendingTodos = ctrl.todayTodos.where((t) => !t.done).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _WorkbenchHeader(
              dateLine: _todayLine(),
              greeting: _greeting(),
              lessonCount: lessons.length,
              todoCount: pendingTodos,
              onToggleTheme: () {
                final next = theme.mode == AppThemeMode.night
                    ? AppThemeMode.day
                    : AppThemeMode.night;
                theme.setMode(next);
              },
            ),
            const SizedBox(height: _sectionGap),
            const _ScheduleCard(),
            const SizedBox(height: _sectionGap),
            const HomeTodoCard(),
            if (nearest != null) ...[
              const SizedBox(height: _sectionGap),
              _ReminderCard(
                item: nearest,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CountdownScreen()),
                ),
              ),
            ] else if (ctrl.isFeatureVisible(ClassFeatureIds.countdowns)) ...[
              const SizedBox(height: _sectionGap),
              _EmptyReminderCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CountdownScreen()),
                ),
              ),
            ],
            if (birthdays.isNotEmpty) ...[
              const SizedBox(height: _sectionGap),
              _BirthdayBanner(
                names: birthdays.map((s) => s.name).join('、'),
              ),
            ],
            if (ctrl.isFeatureVisible(ClassFeatureIds.leave)) ...[
              const SizedBox(height: _sectionGap),
              _LeaveSummaryCard(
                active: ctrl.activeLeaveCount,
                overdue: ctrl.overdueLeaveCount,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LeaveScreen()),
                ),
              ),
            ],
            const SizedBox(height: _sectionGap),
            _HomeShortcuts(ctrl: ctrl),
            if (ctrl.students.isEmpty ||
                ctrl.countdowns.isEmpty ||
                ctrl.fundRecords.isEmpty) ...[
              const SizedBox(height: _sectionGap),
              GroupedSection(
                padding: EdgeInsets.zero,
                children: [
                  GroupedTile(
                    title: '填充演示数据',
                    subtitle: '倒数日、班费、学生、成绩等示例',
                    leading: Icon(AppIcons.users, color: AppTheme.blue),
                    onTap: () async {
                      await ctrl.seedDemo();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已填充演示数据')),
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
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(_cardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _WorkbenchHeader extends StatelessWidget {
  const _WorkbenchHeader({
    required this.dateLine,
    required this.greeting,
    required this.lessonCount,
    required this.todoCount,
    required this.onToggleTheme,
  });

  final String dateLine;
  final String greeting;
  final int lessonCount;
  final int todoCount;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dateLine,
                style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
              ),
            ),
            IconButton(
              tooltip: '切换主题',
              onPressed: onToggleTheme,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              icon: Icon(
                AppTheme.isDark
                    ? Icons.dark_mode_outlined
                    : Icons.wb_sunny_outlined,
                size: 20,
                color: AppTheme.secondaryLabel,
              ),
            ),
          ],
        ),
        Text(
          greeting,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppTheme.label,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _SummaryChip(label: '今日课程', value: '$lessonCount节'),
            _SummaryChip(label: '待办事项', value: '$todoCount项'),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.label,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.item, required this.onTap});

  final CountdownItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    final daysText = days == 0 ? '就是今天' : '距离开始还有 $days 天';

    return _HomeCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '重要提醒',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.tertiaryLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysText,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '查看',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(AppIcons.chevronRight, size: 16, color: AppTheme.blue),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HomeCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(AppIcons.hourglass, size: 18, color: AppTheme.blue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '添加重要提醒',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.label,
                  ),
                ),
              ),
              Icon(AppIcons.chevronRight, color: AppTheme.quaternaryLabel),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthdayBanner extends StatelessWidget {
  const _BirthdayBanner({required this.names});
  final String names;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9500).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Text(
        '今天是 $names 的生日，记得送上一句祝福',
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.secondaryLabel,
          height: 1.35,
        ),
      ),
    );
  }
}

class _LeaveSummaryCard extends StatelessWidget {
  const _LeaveSummaryCard({
    required this.active,
    required this.overdue,
    required this.onTap,
  });

  final int active;
  final int overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = overdue > 0
        ? '请假中 $active 人 · 逾期未销假 $overdue 人'
        : (active > 0 ? '请假中 $active 人' : '今日暂无请假');
    return _HomeCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                AppIcons.calendar,
                color: overdue > 0 ? const Color(0xFFFF3B30) : AppTheme.blue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '请假',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: overdue > 0
                            ? const Color(0xFFFF3B30)
                            : AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, color: AppTheme.tertiaryLabel, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard();

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _openTimetable() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TeacherTimetableScreen(initialTab: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final lessons = ctrl.todayTeachingLessons;

    return _HomeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
            child: Row(
              children: [
                const Text(
                  '今日授课',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '完整课表',
                  onPressed: _openTimetable,
                  icon: Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppTheme.tertiaryLabel,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              child: Column(
                children: [
                  Icon(AppIcons.calendar, size: 36, color: AppTheme.quaternaryLabel),
                  const SizedBox(height: 8),
                  Text(
                    '今日暂无课程',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ],
              ),
            )
          else
            for (final lesson in lessons) _LessonRow(lesson: lesson),
          if (lessons.isNotEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson});
  final TodayTeachingLesson lesson;

  @override
  Widget build(BuildContext context) {
    final done = lesson.isFinished;
    final active = lesson.isInProgress;
    final range = lesson.timeRange.isNotEmpty
        ? lesson.timeRange
        : (lesson.startTime.isNotEmpty
            ? (lesson.endTime.isNotEmpty
                ? '${lesson.startTime}-${lesson.endTime}'
                : lesson.startTime)
            : '');
    final location = lesson.location.trim();

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TeacherTimetableScreen(initialTab: 0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.periodLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? AppTheme.blue : AppTheme.tertiaryLabel,
                    ),
                  ),
                  if (range.isNotEmpty)
                    Text(
                      range,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.tertiaryLabel,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.subject,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: done ? AppTheme.tertiaryLabel : AppTheme.label,
                      decoration:
                          done ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  if (lesson.classTitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      lesson.classTitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(right: 4, top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '进行中',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _HomeShortcuts extends StatelessWidget {
  const _HomeShortcuts({required this.ctrl});
  final ClassController ctrl;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: AppIcons.users,
        label: '学生',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentsScreen()),
        ),
      ),
      if (ctrl.isFeatureVisible(ClassFeatureIds.attendance))
        (
          icon: AppIcons.attendance,
          label: '考勤',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AttendanceScreen()),
          ),
        ),
      if (ctrl.isFeatureVisible(ClassFeatureIds.points))
        (
          icon: AppIcons.plus,
          label: '加分',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const QuickPointsScreen(positive: true),
            ),
          ),
        ),
      if (ctrl.isFeatureVisible(ClassFeatureIds.grades))
        (
          icon: AppIcons.chart,
          label: '成绩',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GradesScreen()),
          ),
        ),
      (
        icon: AppIcons.traces,
        label: '留痕',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WorkLogsScreen()),
        ),
      ),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 4) {
      final chunk = items.sublist(i, (i + 4).clamp(0, items.length));
      rows.add(
        Row(
          children: [
            for (final it in chunk)
              Expanded(
                child: HomeShortcut(
                  icon: it.icon,
                  label: it.label,
                  onTap: it.onTap,
                ),
              ),
            for (var j = chunk.length; j < 4; j++) const Expanded(child: SizedBox()),
          ],
        ),
      );
    }

    return _HomeCard(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
            child: Text(
              '快捷入口',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.label,
              ),
            ),
          ),
          ...rows,
        ],
      ),
    );
  }
}
