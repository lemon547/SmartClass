import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/timetable/ai_timetable_import_screen.dart';
import 'package:smart_class/screens/timetable/timetable_periods_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

/// 课表中心：
/// - 班级课表：先选班级，编辑该班整张课表
/// - 我的授课：不切班，汇总所有班级中本人要上的课
class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key, this.initialTab = 0});

  /// 0 = 班级课表，1 = 我的授课
  final int initialTab;

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  /// 浅底深字，比实色白字更耐看
  static const _tints = <(Color bg, Color fg)>[
    (Color(0xFFE8F1FF), Color(0xFF2B5EA8)),
    (Color(0xFFE6F7EF), Color(0xFF1F7A55)),
    (Color(0xFFFFF0E6), Color(0xFFB85C1A)),
    (Color(0xFFF1ECFF), Color(0xFF5B45B0)),
    (Color(0xFFE6F6FA), Color(0xFF1C7388)),
    (Color(0xFFFFF6DB), Color(0xFF8A6A00)),
    (Color(0xFFFFEBF1), Color(0xFFA33D64)),
    (Color(0xFFEEF1F5), Color(0xFF3D526A)),
  ];

  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
  }

  (Color, Color) _tintFor(String subject) {
    final i = subject.trim().hashCode.abs() % _tints.length;
    return _tints[i];
  }

  /// 我的授课：用默认节次骨架，覆盖到实际最大节次
  List<TimetablePeriod> _periodsForMyView(List<TodayTeachingLesson> lessons) {
    final defaults = TimetablePeriod.defaults();
    var maxPeriod = defaults.length;
    for (final l in lessons) {
      if (l.period > maxPeriod) maxPeriod = l.period;
    }
    final byP = {for (final p in defaults) p.period: p};
    return [
      for (var i = 1; i <= maxPeriod; i++)
        byP[i] ?? TimetablePeriod(period: i, label: '第$i节'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final isClassTab = _tab == 0;
    final classTitle = ctrl.currentClass?.displayTitle ?? '未选班级';
    final lessons = isClassTab ? ctrl.weekClassLessons : ctrl.weekMyLessons;
    final periods = isClassTab
        ? (ctrl.timetablePeriods.isEmpty
            ? TimetablePeriod.defaults()
            : ctrl.timetablePeriods)
        : _periodsForMyView(lessons);
    final today = DateTime.now();
    final todayWd = today.weekday;
    final weekStart = today.subtract(Duration(days: todayWd - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final range =
        '${DateFormat('M月d日').format(weekStart)} — ${DateFormat('M月d日').format(weekEnd)}';

    final grid = <String, TodayTeachingLesson>{};
    for (final l in lessons) {
      // 同格多班时保留第一节，格子上会显示班级名
      grid.putIfAbsent('${l.weekday}-${l.period}', () => l);
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: Text(isClassTab ? '班级课表' : '我的授课'),
        actions: [
          if (isClassTab)
            IconButton(
              tooltip: '节次与作息',
              icon: const Icon(AppIcons.clock),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TimetablePeriodsScreen(),
                ),
              ),
            ),
          if (isClassTab)
            IconButton(
              tooltip: '导入',
              icon: const Icon(AppIcons.upload),
              onPressed: () => _showImportActions(context, markAsMine: false),
            ),
          if (!isClassTab)
            IconButton(
              tooltip: '导入我的授课',
              icon: const Icon(AppIcons.upload),
              onPressed: () => _showImportActions(context, markAsMine: true),
            ),
          IconButton(
            tooltip: isClassTab ? '添加' : '添加我的课',
            icon: const Icon(AppIcons.plus),
            onPressed: () => _openManualAdd(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Column(
              children: [
                _ModeTabs(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 8),
                if (isClassTab) ...[
                  _ClassBar(
                    title: classTitle,
                    onTap: () => showClassSwitcherSheet(context),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  _MyTeachingBar(
                    subject: ctrl.teachingSubject,
                    lessonCount: lessons.length,
                    onSetSubject: () => _editTeachingSubject(context, ctrl),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Text(
                      range,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryLabel,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (isClassTab)
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TimetablePeriodsScreen(),
                          ),
                        ),
                        child: Text(
                          '改作息',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        '汇总全部班级',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.tertiaryLabel,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: isClassTab && ctrl.currentClass == null
                ? _HintEmpty(
                    title: '请先选择班级',
                    subtitle: '班级课表需先选定班级，再编辑该班课程与作息。',
                    actionLabel: '选择班级',
                    onAction: () => showClassSwitcherSheet(context),
                  )
                : !isClassTab &&
                        lessons.isEmpty &&
                        ctrl.teachingSubject == null
                    ? _HintEmpty(
                        title: '先设置我的授课科目',
                        subtitle: '设置后会汇总所有班级课表里该科目的课程。',
                        actionLabel: '设置科目',
                        onAction: () => _editTeachingSubject(context, ctrl),
                      )
                    : !isClassTab && lessons.isEmpty
                        ? _HintEmpty(
                            title: '暂无本人授课',
                            subtitle:
                                '可在「班级课表」里排课，或点右上角添加并标记为我的课。',
                            actionLabel: '添加一节',
                            onAction: () => _openManualAdd(context),
                          )
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                            child: _ScheduleGrid(
                              periods: periods,
                              weekLabels: _weekLabels,
                              weekStart: weekStart,
                              todayWeekday: todayWd,
                              lessonAt: (wd, p) => grid['$wd-$p'],
                              tintFor: _tintFor,
                              showClassOnBlock: !isClassTab,
                              mineSubjects: ctrl.teachingSubject == null
                                  ? const <String>{}
                                  : {ctrl.teachingSubject!.trim()},
                              onTap: (wd, p, lesson) {
                                if (isClassTab) {
                                  _editClassCell(
                                    context,
                                    ctrl,
                                    wd,
                                    p,
                                    lesson,
                                  );
                                } else if (lesson != null) {
                                  _showMyLessonSheet(context, ctrl, lesson);
                                } else {
                                  _openManualAdd(
                                    context,
                                    weekday: wd,
                                    period: p,
                                  );
                                }
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTeachingSubject(
    BuildContext context,
    ClassController ctrl,
  ) async {
    final text = TextEditingController(text: ctrl.teachingSubject ?? '');
    final presets = ['语文', '数学', '英语', '物理', '化学', '生物', '历史', '地理', '政治', '体育'];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '我的授课科目',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '跨班汇总时，会找出所有班级课表里同名科目。',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: text,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '如：语文',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in presets)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => text.text = s,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final v = text.text.trim();
                  Navigator.pop(ctx);
                  if (v.isEmpty) {
                    await ctrl.clearTeachingSubject();
                  } else {
                    await ctrl.setTeachingSubject(v);
                  }
                  await ctrl.refreshAllTodayLessons();
                },
                child: const Text('保存'),
              ),
              if (ctrl.teachingSubject != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ctrl.clearTeachingSubject();
                    await ctrl.refreshAllTodayLessons();
                  },
                  child: const Text('清除'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _editClassCell(
    BuildContext context,
    ClassController ctrl,
    int weekday,
    int period,
    TodayTeachingLesson? existing,
  ) async {
    final text = TextEditingController(text: existing?.subject ?? '');
    final presets = [
      if (ctrl.teachingSubject != null) ctrl.teachingSubject!,
      ...const ['语文', '数学', '英语', '物理', '化学', '体育', '班会', '自习'],
    ].toSet().toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '周${_weekLabels[weekday - 1]} · ${ctrl.periodAt(period)?.displayLabel ?? '第$period节'}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                ctrl.currentClass?.displayTitle ?? '',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: text,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '输入科目，留空可清除',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in presets)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => text.text = s,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final v = text.text.trim();
                  Navigator.pop(ctx);
                  await ctrl.setTimetableSlot(
                    weekday: weekday,
                    period: period,
                    subject: v.isEmpty ? null : v,
                  );
                  await ctrl.refreshAllTodayLessons();
                },
                child: const Text('保存'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ctrl.setTimetableSlot(
                      weekday: weekday,
                      period: period,
                      subject: null,
                    );
                    await ctrl.refreshAllTodayLessons();
                  },
                  child: const Text('清除本格'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMyLessonSheet(
    BuildContext context,
    ClassController ctrl,
    TodayTeachingLesson lesson,
  ) async {
    final tint = _tintFor(lesson.subject);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lesson.subject,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: tint.$2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '周${_weekLabels[lesson.weekday - 1]} · ${lesson.scheduleLabel}',
                style: TextStyle(fontSize: 14, color: AppTheme.secondaryLabel),
              ),
              const SizedBox(height: 12),
              Text(
                lesson.classTitle.isEmpty ? '—' : lesson.classTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF3B30),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ctrl.clearMyTeachingLesson(
                    classId: lesson.classId,
                    weekday: lesson.weekday,
                    period: lesson.period,
                  );
                },
                child: const Text('从我的授课中清除'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openManualAdd(
    BuildContext context, {
    int? weekday,
    int? period,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ManualAddLessonScreen(
          initialWeekday: weekday,
          initialPeriod: period,
        ),
      ),
    );
  }

  Future<void> _showImportActions(
    BuildContext context, {
    required bool markAsMine,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  markAsMine ? '导入我的授课' : '导入班级课表',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: Icon(AppIcons.sparkles, color: AppTheme.blue),
                title: const Text('AI 智能导入'),
                subtitle: const Text('微信/本机文件或照片，OCR+AI'),
                onTap: () {
                  Navigator.pop(ctx);
                  AiTimetableImportScreen.push(
                    context,
                    markAsMine: markAsMine,
                  );
                },
              ),
              ListTile(
                leading: Icon(AppIcons.plus, color: AppTheme.blue),
                title: const Text('手动添加一节'),
                subtitle: Text(
                  markAsMine ? '写入指定班级并标记本人授课' : '写入当前所选班级',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openManualAdd(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassBar extends StatelessWidget {
  const _ClassBar({required this.title, required this.onTap});
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Icon(AppIcons.classes, size: 18, color: AppTheme.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前班级',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '切换',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w600,
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

class _MyTeachingBar extends StatelessWidget {
  const _MyTeachingBar({
    required this.subject,
    required this.lessonCount,
    required this.onSetSubject,
  });

  final String? subject;
  final int lessonCount;
  final VoidCallback onSetSubject;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onSetSubject,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(AppIcons.notebook, size: 18, color: AppTheme.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject == null ? '尚未设置授课科目' : '我的科目 · $subject',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subject == null
                          ? '点此设置后，汇总所有班该科目课程'
                          : '本周共 $lessonCount 节 · 跨全部班级',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                subject == null ? '设置' : '更换',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w600,
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

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Seg(
              label: '班级课表',
              selected: index == 0,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _Seg(
              label: '我的授课',
              selected: index == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: selected ? 0.5 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppTheme.blue : AppTheme.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }
}

class _HintEmpty extends StatelessWidget {
  const _HintEmpty({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.calendar, size: 40, color: AppTheme.quaternaryLabel),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryLabel,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _ScheduleGrid extends StatelessWidget {
  const _ScheduleGrid({
    required this.periods,
    required this.weekLabels,
    required this.weekStart,
    required this.todayWeekday,
    required this.lessonAt,
    required this.tintFor,
    required this.showClassOnBlock,
    required this.mineSubjects,
    required this.onTap,
  });

  final List<TimetablePeriod> periods;
  final List<String> weekLabels;
  final DateTime weekStart;
  final int todayWeekday;
  final TodayTeachingLesson? Function(int weekday, int period) lessonAt;
  final (Color, Color) Function(String subject) tintFor;
  final bool showClassOnBlock;
  final Set<String> mineSubjects;
  final void Function(int weekday, int period, TodayTeachingLesson? lesson)
      onTap;

  static const _periodW = 40.0;
  static const _headH = 36.0;
  static const _cellH = 48.0;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.separator.withValues(alpha: 0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            SizedBox(
              height: _headH,
              child: Row(
                children: [
                  SizedBox(
                    width: _periodW,
                    child: Center(
                      child: Text(
                        '节',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.tertiaryLabel,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  for (var d = 1; d <= 7; d++)
                    Expanded(
                      child: ColoredBox(
                        color: d == todayWeekday
                            ? AppTheme.blue.withValues(alpha: 0.08)
                            : Colors.transparent,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekLabels[d - 1],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: d == todayWeekday
                                    ? AppTheme.blue
                                    : AppTheme.secondaryLabel,
                              ),
                            ),
                            Text(
                              '${weekStart.add(Duration(days: d - 1)).day}',
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.1,
                                color: d == todayWeekday
                                    ? AppTheme.blue
                                    : AppTheme.tertiaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: AppTheme.separator),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: periods.length,
                itemBuilder: (context, i) {
                  final row = periods[i];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: _cellH,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: _periodW,
                              child: _PeriodSide(period: row),
                            ),
                            for (var d = 1; d <= 7; d++)
                              Expanded(
                                child: _Cell(
                                  lesson: lessonAt(d, row.period),
                                  isTodayCol: d == todayWeekday,
                                  tintFor: tintFor,
                                  showClass: showClassOnBlock,
                                  isMine: (s) =>
                                      mineSubjects.contains(s.trim()),
                                  onTap: () => onTap(
                                    d,
                                    row.period,
                                    lessonAt(d, row.period),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppTheme.separator.withValues(alpha: 0.45),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSide extends StatelessWidget {
  const _PeriodSide({required this.period});
  final TimetablePeriod period;

  @override
  Widget build(BuildContext context) {
    final start = period.startTime.trim();
    final end = period.endTime.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${period.period}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: AppTheme.label,
            ),
          ),
          if (start.isNotEmpty)
            Text(
              start,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.15,
                color: AppTheme.tertiaryLabel,
              ),
            ),
          if (end.isNotEmpty)
            Text(
              end,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 8.5,
                height: 1.15,
                color: AppTheme.quaternaryLabel,
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.lesson,
    required this.isTodayCol,
    required this.tintFor,
    required this.showClass,
    required this.isMine,
    required this.onTap,
  });

  final TodayTeachingLesson? lesson;
  final bool isTodayCol;
  final (Color, Color) Function(String subject) tintFor;
  final bool showClass;
  final bool Function(String subject) isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = lesson;
    return Material(
      color: isTodayCol
          ? AppTheme.blue.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: l == null
              ? const SizedBox.expand()
              : Builder(
                  builder: (context) {
                    final tint = tintFor(l.subject);
                    final mine = isMine(l.subject);
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint.$1,
                        borderRadius: BorderRadius.circular(5),
                        border: mine
                            ? Border.all(color: AppTheme.blue, width: 1.2)
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l.subject,
                            maxLines: showClass ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tint.$2,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          if (showClass && l.classTitle.isNotEmpty)
                            Text(
                              l.classTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: tint.$2.withValues(alpha: 0.8),
                                fontSize: 8.5,
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _ManualAddLessonScreen extends StatefulWidget {
  const _ManualAddLessonScreen({
    this.initialWeekday,
    this.initialPeriod,
  });

  final int? initialWeekday;
  final int? initialPeriod;

  @override
  State<_ManualAddLessonScreen> createState() => _ManualAddLessonScreenState();
}

class _ManualAddLessonScreenState extends State<_ManualAddLessonScreen> {
  String? _classId;
  late int _weekday;
  late int _period;
  final _subject = TextEditingController();
  bool _saving = false;

  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _weekday = widget.initialWeekday ?? DateTime.now().weekday;
    _period = widget.initialPeriod ?? 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<ClassController>();
      setState(() {
        _classId = ctrl.currentClass?.id ??
            (ctrl.classes.isEmpty ? null : ctrl.classes.first.id);
        _subject.text = ctrl.teachingSubject ??
            ctrl.currentClass?.subject.trim() ??
            '';
      });
    });
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final classId = _classId;
    final subject = _subject.text.trim();
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择班级')),
      );
      return;
    }
    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写科目')),
      );
      return;
    }
    setState(() => _saving = true);
    final ctrl = context.read<ClassController>();
    await ctrl.addMyTeachingLesson(
      classId: classId,
      weekday: _weekday,
      period: _period,
      subject: subject,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已添加到课表')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final classes = ctrl.classes;
    final periods = ctrl.timetablePeriods.isEmpty
        ? TimetablePeriod.defaults()
        : ctrl.timetablePeriods;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: const Text('添加课程'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('班级', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _classId != null &&
                        classes.any((c) => c.id == _classId)
                    ? _classId
                    : null,
                hint: const Text('选择班级'),
                items: [
                  for (final c in classes)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(c.displayTitle),
                    ),
                ],
                onChanged: (v) => setState(() => _classId = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('星期', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                ChoiceChip(
                  label: Text('周${_weekLabels[d - 1]}'),
                  selected: _weekday == d,
                  onSelected: (_) => setState(() => _weekday = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('节次', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in periods)
                ChoiceChip(
                  label: Text(p.displayLabel),
                  selected: _period == p.period,
                  onSelected: (_) => setState(() => _period = p.period),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('科目', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 6),
          TextField(
            controller: _subject,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(20)],
            decoration: const InputDecoration(hintText: '如：语文、数学、班会'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final s in const ['语文', '数学', '英语', '物理', '化学', '班会'])
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() => _subject.text = s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
