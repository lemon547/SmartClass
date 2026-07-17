import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/points/quick_points_screen.dart';
import 'package:smart_class/screens/roll_call/roll_call_screen.dart';
import 'package:smart_class/screens/timetable/timetable_screen.dart';
import 'package:smart_class/screens/tools/countdown_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';
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
    final title =
        ctrl.currentClass?.displayTitle ?? ctrl.profile.displayTitle;
    final birthdays = ctrl.todayBirthdays;
    final nearest = ctrl.nearestCountdown;
    final lessons = ctrl.todayTeachingLessons;
    final pendingTodos = ctrl.todos.where((t) => !t.done).length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _TodayHeader(
              dateLine: _todayLine(),
              classTitle: title,
              onSwitchClass: () => showClassSwitcherSheet(context),
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
            _ScheduleCard(lessons: lessons),
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
            if (pendingTodos == 0 && lessons.isEmpty) const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.dateLine,
    required this.classTitle,
    required this.onSwitchClass,
    required this.onToggleTheme,
  });

  final String dateLine;
  final String classTitle;
  final VoidCallback onSwitchClass;
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
              InkWell(
                onTap: onSwitchClass,
                borderRadius: BorderRadius.circular(6),
                child: Text(
                  '$dateLine · $classTitle',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.tertiaryLabel,
                  ),
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
  const _ScheduleCard({required this.lessons});

  final List<TodayTeachingLesson> lessons;

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
    final lessons = widget.lessons;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                const Text(
                  '今日课程',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TimetableScreen()),
                  ),
                  child: const Text('编辑'),
                ),
              ],
            ),
          ),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '今天没有你的课',
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TimetableScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                lesson.periodLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppTheme.blue : AppTheme.tertiaryLabel,
                ),
              ),
            ),
            Expanded(
              child: Text(
                lesson.detailLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: done ? AppTheme.tertiaryLabel : AppTheme.label,
                  decoration:
                      done ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
            if (lesson.timeRange.isNotEmpty)
              Text(
                lesson.timeRange,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.tertiaryLabel,
                ),
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

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final todos = ctrl.todos;
    final pending = todos.where((t) => !t.done).length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                  pending == 0 ? '暂无待办' : '$pending 项待办',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
              ],
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
                '还没有待办，上面输入一条试试',
                style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 14),
              ),
            )
          else
            for (final t in todos)
              Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppTheme.destructive,
                  child: const Icon(AppIcons.trash, color: Colors.white),
                ),
                onDismissed: (_) => ctrl.deleteTodo(t.id),
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
                          t.done ? AppIcons.circleCheck : AppIcons.circle,
                          size: 22,
                          color: t.done ? AppTheme.blue : AppTheme.quaternaryLabel,
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
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 6),
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
