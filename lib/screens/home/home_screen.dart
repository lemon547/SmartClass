import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/points/quick_points_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/timetable/teacher_timetable_screen.dart';
import 'package:smart_class/screens/todos/todos_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

String _todayLine() {
  final n = DateTime.now();
  const week = ['一', '二', '三', '四', '五', '六', '日'];
  return '${n.month}月${n.day}日 星期${week[n.weekday - 1]}';
}

/// 今日：倒计时 / 生日 / 课程 / 待办（参考教师工作台「今日」页）
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final theme = context.watch<ThemeController>();
    final birthdays = ctrl.todayBirthdays;
    final nearest = ctrl.nearestCountdown;
    final pendingTodos = ctrl.todayTodos.where((t) => !t.done).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _TodayHeader(
              dateLine: _todayLine(),
              onToggleTheme: () {
                final next = theme.mode == AppThemeMode.night
                    ? AppThemeMode.day
                    : AppThemeMode.night;
                theme.setMode(next);
              },
            ),
            const SizedBox(height: 14),
            if (nearest != null) ...[
              _CountdownHero(
                item: nearest,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CountdownScreen()),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (ctrl.isFeatureVisible(ClassFeatureIds.countdowns)) ...[
              _EmptyCountdownCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CountdownScreen()),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (birthdays.isNotEmpty) ...[
              _BirthdayBanner(
                names: birthdays.map((s) => s.name).join('、'),
              ),
              const SizedBox(height: 12),
            ],
            const _ScheduleCard(),
            const SizedBox(height: 12),
            const _TodoCard(),
            const SizedBox(height: 12),
            _HomeShortcuts(ctrl: ctrl),
            if (ctrl.students.isEmpty ||
                ctrl.countdowns.isEmpty ||
                ctrl.fundRecords.isEmpty) ...[
              const SizedBox(height: 12),
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
            if (pendingTodos == 0 && ctrl.todayTeachingLessons.isEmpty)
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.dateLine,
    required this.onToggleTheme,
  });

  final String dateLine;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLine,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '今日',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 34,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '切换主题',
          onPressed: onToggleTheme,
          icon: Icon(
            AppTheme.isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
            color: AppTheme.secondaryLabel,
          ),
        ),
      ],
    );
  }
}

class _CountdownHero extends StatelessWidget {
  const _CountdownHero({required this.item, required this.onTap});

  final CountdownItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF3B30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      days == 0 ? '就是今天' : '距 ${item.targetDate}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '坚持就是胜利',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                days == 0 ? '今天' : '$days',
                style: TextStyle(
                  fontSize: days == 0 ? 28 : 42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.2,
                  height: 1,
                  color: AppTheme.label,
                ),
              ),
              if (days > 0) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '天',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCountdownCard extends StatelessWidget {
  const _EmptyCountdownCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(AppIcons.hourglass, color: AppTheme.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '添加倒数日',
                  style: TextStyle(
                    fontSize: 16,
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFFF9500),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '今天是 $names 的生日，记得送上一句祝福',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryLabel,
                height: 1.35,
              ),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final lessons = ctrl.todayTeachingLessons;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Text(
                  '今日授课',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const TeacherTimetableScreen(initialTab: 1),
                    ),
                  ),
                  child: const Text('课表', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '今天没有需要你上的课',
                  style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 15),
                ),
              ),
            )
          else
            for (final lesson in lessons) _LessonRow(lesson: lesson),
          const SizedBox(height: 6),
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
    final time = lesson.startTime.isNotEmpty
        ? lesson.startTime
        : (lesson.timeRange.contains('-')
            ? lesson.timeRange.split('-').first.trim()
            : lesson.timeRange);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TeacherTimetableScreen(initialTab: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 70,
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
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.tertiaryLabel,
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
                      decoration: done
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
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
                ],
              ),
            ),
            if (active)
              Container(
                margin: const EdgeInsets.only(right: 4),
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
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppTheme.quaternaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoCard extends StatefulWidget {
  const _TodoCard();

  @override
  State<_TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<_TodoCard> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(ClassController ctrl) async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await ctrl.addTodo(text);
  }

  void _openAll() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TodosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final todos = ctrl.todayTodos;
    final pending = todos.where((t) => !t.done).length;
    final preview = todos.take(6).toList();
    final hasMore = todos.length > preview.length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _openAll,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
              child: Row(
                children: [
                  const Text(
                    '待办事项',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    pending == 0 ? '今日暂无' : '今日 $pending 项',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.tertiaryLabel,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(ctrl),
              decoration: InputDecoration(
                hintText: '记一条待办，回车保存',
                prefixIcon: Icon(AppIcons.circlePlus, color: AppTheme.blue),
              ),
            ),
          ),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Text(
                '还没有今日待办，上面输入一条试试',
                style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 14),
              ),
            )
          else
            Column(
              children: [
                SlidableAutoCloseBehavior(
                  child: Column(
                    children: [
                      for (final t in preview)
                        AppleDeleteSlidable(
                          itemKey: ValueKey(t.id),
                          onDelete: () => ctrl.deleteTodo(t.id),
                          child: InkWell(
                            onTap: () => ctrl.toggleTodo(t.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    t.done
                                        ? AppIcons.circleCheck
                                        : AppIcons.circle,
                                    size: 22,
                                    color: t.done
                                        ? AppTheme.blue
                                        : AppTheme.quaternaryLabel,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: t.done
                                            ? AppTheme.tertiaryLabel
                                            : AppTheme.label,
                                        decoration: t.done
                                            ? TextDecoration.lineThrough
                                            : TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  if (!t.isCreatedToday && !t.done)
                                    Text(
                                      '往日',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.quaternaryLabel,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _openAll,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasMore ? '查看全部待办与历史' : '查看全部与历史',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          AppIcons.chevronRight,
                          size: 16,
                          color: AppTheme.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _HomeShortcuts extends StatelessWidget {
  const _HomeShortcuts({required this.ctrl});

  final ClassController ctrl;

  @override
  Widget build(BuildContext context) {
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
      onTap: () => QuickPointsScreen.open(context, positive: true),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 2),
            child: Text(
              '常用工具',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ),
          Row(children: shortcuts),
        ],
      ),
    );
  }
}
