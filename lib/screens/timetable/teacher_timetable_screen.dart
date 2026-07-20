import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/timetable/ai_timetable_import_screen.dart';
import 'package:smart_class/screens/timetable/timetable_periods_screen.dart';
import 'package:smart_class/screens/timetable/widgets/my_teaching_summary.dart';
import 'package:smart_class/screens/timetable/widgets/schedule_grid.dart';
import 'package:smart_class/screens/timetable/widgets/schedule_tabs.dart';
import 'package:smart_class/screens/timetable/widgets/today_lesson_list.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

enum _LessonDetailAction { edit, add }

/// 课表中心（归属「教学」）：
/// - 我的课表：汇总各班本人要上的课（默认）
/// - 班级课表：编辑当前班整张课表
class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({
    super.key,
    this.initialTab = 0,
    this.embedded = false,
  });

  /// 0 = 我的课表，1 = 班级课表
  final int initialTab;

  /// 嵌在其他页面内时隐藏外层 AppBar（教学 Tab 为入口页，一般 push 打开）
  final bool embedded;

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
  static const _weekFull = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const _subjectPresets = [
    '语文',
    '数学',
    '英语',
    '物理',
    '化学',
    '生物',
    '历史',
    '地理',
    '政治',
    '体育',
    '音乐',
    '美术',
    '班会',
  ];

  late int _tab;
  bool _aggregateAll = true;
  /// 班级课表：仅显示本人授课科目
  bool _classMineOnly = false;
  int _scrollEpoch = 0;
  final ScrollController _gridScroll = ScrollController();
  bool _canScrollMore = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
    _gridScroll.addListener(_onGridScroll);
  }

  @override
  void dispose() {
    _gridScroll.removeListener(_onGridScroll);
    _gridScroll.dispose();
    super.dispose();
  }

  void _onGridScroll() {
    if (!_gridScroll.hasClients) return;
    final max = _gridScroll.position.maxScrollExtent;
    final more = max > 8 && _gridScroll.offset < max - 8;
    if (more != _canScrollMore) {
      setState(() => _canScrollMore = more);
    }
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

  List<TodayTeachingLesson> _visibleLessons(
    ClassController ctrl, {
    required bool isClassTab,
  }) {
    var lessons =
        isClassTab ? [...ctrl.weekClassLessons] : [...ctrl.weekMyLessons];
    if (isClassTab) {
      if (_classMineOnly) {
        final mine = ctrl.teachingSubject?.trim();
        if (mine != null && mine.isNotEmpty) {
          lessons = lessons.where((l) => l.subject.trim() == mine).toList();
        } else {
          lessons = [];
        }
      }
    } else if (!_aggregateAll) {
      final id = ctrl.currentClass?.id;
      if (id != null) {
        lessons = lessons.where((l) => l.classId == id).toList();
      }
    }
    return lessons;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final isClassTab = _tab == 1;
    final classTitle = ctrl.currentClass?.displayTitle ?? '未选班级';
    final lessons = _visibleLessons(ctrl, isClassTab: isClassTab);
    final periods = isClassTab
        ? (ctrl.timetablePeriods.isEmpty
            ? TimetablePeriod.defaults()
            : ctrl.timetablePeriods)
        : _periodsForMyView(lessons);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayWd = today.weekday;
    final thisWeekStart = todayDate.subtract(Duration(days: todayWd - 1));
    final weekStart = thisWeekStart;
    final highlightWeekday = todayWd;
    final todayLabel = '${today.month}月${today.day}日';
    final todayLessons =
        lessons.where((l) => l.weekday == todayWd).toList();

    final grid = <String, List<TodayTeachingLesson>>{};
    for (final l in lessons) {
      grid.putIfAbsent('${l.weekday}-${l.period}', () => []).add(l);
    }

    final moreBtn = IconButton(
      tooltip: '更多',
      icon: const Icon(AppIcons.moreVert, color: TtStyle.accent),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: () => _showMoreActions(
        context,
        isClassTab: isClassTab,
      ),
    );

    return Scaffold(
      backgroundColor: TtStyle.pageBg,
      appBar: widget.embedded
          ? null
          : AppBar(
              toolbarHeight: TtStyle.toolbarH,
              centerTitle: true,
              automaticallyImplyLeading: false,
              // 与 Scaffold 白底一致，避免顶栏灰、内容白两截色
              backgroundColor: TtStyle.pageBg,
              surfaceTintColor: Colors.transparent,
              foregroundColor: TtStyle.accent,
              iconTheme: const IconThemeData(color: TtStyle.accent, size: 22),
              leadingWidth: 56,
              leading: Navigator.canPop(context)
                  ? IconButton(
                      icon: const Icon(AppIcons.chevronLeft),
                      onPressed: () => Navigator.maybePop(context),
                      tooltip: '返回',
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                    )
                  : null,
              title: const Text(
                '课程安排',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: TtStyle.title,
                ),
              ),
              actions: [moreBtn],
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ScheduleTabs(
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                    ),
                    if (widget.embedded) moreBtn,
                  ],
                ),
                if (isClassTab)
                  ClassScheduleBar(
                    title: classTitle,
                    mineOnly: _classMineOnly,
                    onSwitchClass: () => showClassSwitcherSheet(context),
                    onMineOnlyChanged: (v) =>
                        setState(() => _classMineOnly = v),
                  ),
              ],
            ),
          ),
          Expanded(
            child: isClassTab && ctrl.currentClass == null
                ? _HintEmpty(
                    title: '请先选择班级',
                    subtitle: '选定班级后再编辑该班课程与作息。',
                    actionLabel: '选择班级',
                    onAction: () => showClassSwitcherSheet(context),
                  )
                : !isClassTab &&
                        lessons.isEmpty &&
                        ctrl.teachingSubject == null
                    ? _HintEmpty(
                        title: '先设置授课科目',
                        subtitle: '设置后会汇总各班同名科目课程。',
                        actionLabel: '设置科目',
                        onAction: () => _editTeachingSubject(context, ctrl),
                      )
                    : !isClassTab
                        ? _buildMyDayAndWeek(
                            ctrl: ctrl,
                            todayLessons: todayLessons,
                            todayLabel: todayLabel,
                            weekLessons: lessons,
                            weekStart: thisWeekStart,
                            todayWeekday: todayWd,
                          )
                        : lessons.isEmpty
                            ? _HintEmpty(
                                title: '本周暂无课程安排',
                                subtitle: '可点右上角 ⋮ 添加，或先在班级课表排课。',
                              )
                            : NotificationListener<ScrollMetricsNotification>(
                                onNotification: (n) {
                                  final max = n.metrics.maxScrollExtent;
                                  final more =
                                      max > 8 && n.metrics.pixels < max - 8;
                                  if (more != _canScrollMore) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted &&
                                          more != _canScrollMore) {
                                        setState(
                                          () => _canScrollMore = more,
                                        );
                                      }
                                    });
                                  }
                                  return false;
                                },
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        0,
                                        4,
                                        8,
                                      ),
                                      child: ScheduleGrid(
                                        periods: periods,
                                        weekFullLabels: _weekFull,
                                        weekStart: weekStart,
                                        todayWeekday: highlightWeekday,
                                        verticalScroll: _gridScroll,
                                        scrollEpoch: _scrollEpoch,
                                        lessonsAt: (wd, p) =>
                                            grid['$wd-$p'] ?? const [],
                                        showClassOnBlock: false,
                                        hasTodo: (_) => false,
                                        onTap: (wd, p, cellLessons) {
                                          _showLessonDetail(
                                            context,
                                            ctrl,
                                            weekday: wd,
                                            period: p,
                                            cellLessons: cellLessons,
                                            isClassTab: true,
                                          );
                                        },
                                      ),
                                    ),
                                    if (_canScrollMore)
                                      const Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: _ScrollHintBar(),
                                      ),
                                  ],
                                ),
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyDayAndWeek({
    required ClassController ctrl,
    required List<TodayTeachingLesson> todayLessons,
    required String todayLabel,
    required List<TodayTeachingLesson> weekLessons,
    required DateTime weekStart,
    required int todayWeekday,
  }) {
    return MyScheduleList(
      todayLessons: todayLessons,
      todayLabel: todayLabel,
      weekLessons: weekLessons,
      weekStart: weekStart,
      todayWeekday: todayWeekday,
      onTapLesson: (lesson) {
        _showLessonDetail(
          context,
          ctrl,
          weekday: lesson.weekday,
          period: lesson.period,
          cellLessons: [lesson],
          isClassTab: false,
        );
      },
    );
  }

  Future<void> _showMoreActions(
    BuildContext context, {
    required bool isClassTab,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(AppIcons.sparkles, color: TtStyle.accent),
                title: const Text('AI智能导入课表'),
                subtitle: const Text('微信/本机文件或照片，OCR+AI'),
                onTap: () {
                  Navigator.pop(ctx);
                  AiTimetableImportScreen.push(
                    context,
                    markAsMine: !isClassTab,
                  );
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.plus, color: TtStyle.accent),
                title: const Text('添加课程'),
                subtitle: const Text('手动新增一节课'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openManualAdd(context);
                },
              ),
              if (isClassTab)
                ListTile(
                  leading: const Icon(AppIcons.clock, color: TtStyle.accent),
                  title: const Text('调整课表'),
                  subtitle: const Text('修改节次与作息时间'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TimetablePeriodsScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showLessonDetail(
    BuildContext context,
    ClassController ctrl, {
    required int weekday,
    required int period,
    required List<TodayTeachingLesson> cellLessons,
    required bool isClassTab,
  }) async {
    if (!isClassTab && cellLessons.isEmpty) {
      await _openManualAdd(context, weekday: weekday, period: period);
      return;
    }

    final existing = cellLessons.isEmpty ? null : cellLessons.first;

    // 先关弹层再开下一页，避免叠层触发 InheritedWidget 断言
    final action = await showDialog<_LessonDetailAction>(
      context: context,
      builder: (ctx) {
        final periodLabel =
            ctrl.periodAt(period)?.displayLabel ?? '第$period节';
        final time = existing?.timeRange.isNotEmpty == true
            ? existing!.timeRange
            : (ctrl.periodAt(period)?.timeRange ?? '');
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing?.subject ?? '空闲时段',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: TtStyle.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '周${_weekLabels[weekday - 1]} · $periodLabel'
                  '${time.isEmpty ? '' : ' · $time'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: TtStyle.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (cellLessons.isEmpty)
                  Text(
                    ctrl.currentClass?.displayTitle ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: TtStyle.title,
                    ),
                  )
                else
                  for (final l in cellLessons) ...[
                    Text(
                      l.classTitle.isEmpty ? '—' : l.classTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: TtStyle.title,
                      ),
                    ),
                    if (l.location.trim().isNotEmpty)
                      Text(
                        l.location.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: TtStyle.muted,
                        ),
                      ),
                    const SizedBox(height: 2),
                  ],
                if (isClassTab) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        Navigator.pop(ctx, _LessonDetailAction.edit),
                    child: Text(existing == null ? '安排课程' : '调整课程'),
                  ),
                ] else if (cellLessons.isEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () =>
                        Navigator.pop(ctx, _LessonDetailAction.add),
                    child: const Text('添加课程'),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('关闭'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    switch (action) {
      case _LessonDetailAction.edit:
        await _editClassCell(this.context, ctrl, weekday, period, existing);
      case _LessonDetailAction.add:
        await _openManualAdd(this.context, weekday: weekday, period: period);
      case null:
        break;
    }
  }

  Future<void> _editTeachingSubject(
    BuildContext context,
    ClassController ctrl,
  ) async {
    final text = TextEditingController(text: ctrl.teachingSubject ?? '');
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
                  for (final s in _subjectPresets)
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
    final presets = <String>{
      if (ctrl.teachingSubject != null) ctrl.teachingSubject!,
      ..._subjectPresets,
      '自习',
    }.toList();

    final saved = await showModalBottomSheet<String?>(
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
                onPressed: () => Navigator.pop(ctx, text.text.trim()),
                child: const Text('保存'),
              ),
              if (existing != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, ''),
                  child: const Text('清除本格'),
                ),
              ],
            ],
          ),
        );
      },
    );
    text.dispose();
    if (!mounted || saved == null) return;
    await ctrl.setTimetableSlot(
      weekday: weekday,
      period: period,
      subject: saved.isEmpty ? null : saved,
    );
    await ctrl.refreshAllTodayLessons();
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
}

class _ScrollHintBar extends StatelessWidget {
  const _ScrollHintBar();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_down, size: 16, color: TtStyle.muted),
            SizedBox(width: 2),
            Text(
              '下滑查看更多课时',
              style: TextStyle(fontSize: 11, color: TtStyle.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintEmpty extends StatelessWidget {
  const _HintEmpty({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.calendar, size: 48, color: TtStyle.emptyHint),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: TtStyle.title,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: TtStyle.secondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
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
