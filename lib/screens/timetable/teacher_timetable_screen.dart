import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/lessons/lesson_progress_screen.dart';
import 'package:smart_class/screens/timetable/ai_timetable_import_screen.dart';
import 'package:smart_class/screens/timetable/timetable_periods_screen.dart';
import 'package:smart_class/screens/timetable/widgets/my_teaching_summary.dart';
import 'package:smart_class/screens/timetable/widgets/schedule_grid.dart';
import 'package:smart_class/screens/timetable/widgets/schedule_header.dart';
import 'package:smart_class/screens/timetable/widgets/schedule_tabs.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';
import 'package:smart_class/services/file_share.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

/// 课表中心：
/// - 班级课表：先选班级，编辑该班整张课表
/// - 我的授课：不切班，汇总所有班级中本人要上的课
class TeacherTimetableScreen extends StatefulWidget {
  const TeacherTimetableScreen({super.key, this.initialTab = 1});

  /// 0 = 班级课表，1 = 我的授课（默认）
  final int initialTab;

  @override
  State<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  static const _weekLabels = ['一', '二', '三', '四', '五', '六', '日'];
  static const _weekFull = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  static const _notesPrefsKey = 'timetable_cell_notes_v1';
  static const _todosPrefsKey = 'timetable_cell_todos_v1';
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
  String? _classSubjectFilter;
  final Map<String, String> _notes = {};
  final Set<String> _todos = {};
  final ScrollController _gridScroll = ScrollController();
  bool _canScrollMore = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 1);
    _gridScroll.addListener(_onGridScroll);
    _loadMarks();
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

  Future<void> _loadMarks() async {
    final prefs = await SharedPreferences.getInstance();
    final notesRaw = prefs.getString(_notesPrefsKey);
    final todosRaw = prefs.getStringList(_todosPrefsKey) ?? const [];
    if (!mounted) return;
    setState(() {
      _notes.clear();
      if (notesRaw != null && notesRaw.isNotEmpty) {
        final map = jsonDecode(notesRaw);
        if (map is Map) {
          for (final e in map.entries) {
            final v = '${e.value}'.trim();
            if (v.isNotEmpty) _notes['${e.key}'] = v;
          }
        }
      }
      _todos.clear();
      _todos.addAll(todosRaw);
    });
  }

  Future<void> _persistMarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesPrefsKey, jsonEncode(_notes));
    await prefs.setStringList(_todosPrefsKey, _todos.toList());
  }

  String _markKey({
    required String classId,
    required int weekday,
    required int period,
  }) =>
      '$classId|$weekday|$period';

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
      final filter = _classSubjectFilter?.trim();
      if (filter != null && filter.isNotEmpty) {
        lessons = lessons.where((l) => l.subject.trim() == filter).toList();
      }
    } else if (!_aggregateAll) {
      final id = ctrl.currentClass?.id;
      if (id != null) {
        lessons = lessons.where((l) => l.classId == id).toList();
      }
    }
    return lessons;
  }

  List<String> _subjectsInLessons(List<TodayTeachingLesson> lessons) {
    final seen = <String>{};
    final out = <String>[];
    for (final l in lessons) {
      final s = l.subject.trim();
      if (s.isEmpty || seen.contains(s)) continue;
      seen.add(s);
      out.add(s);
    }
    out.sort();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final isClassTab = _tab == 0;
    final classTitle = ctrl.currentClass?.displayTitle ?? '未选班级';
    final lessons = _visibleLessons(ctrl, isClassTab: isClassTab);
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
        '${DateFormat('M月d日').format(weekStart)}－${DateFormat('M月d日').format(weekEnd)}';
    final filterSubjects = _subjectsInLessons(ctrl.weekClassLessons);
    final subjectOptions = [
      if (ctrl.teachingSubject != null &&
          !_subjectPresets.contains(ctrl.teachingSubject))
        ctrl.teachingSubject!,
      ..._subjectPresets,
    ];

    final grid = <String, List<TodayTeachingLesson>>{};
    for (final l in lessons) {
      grid.putIfAbsent('${l.weekday}-${l.period}', () => []).add(l);
    }

    return Scaffold(
      backgroundColor: TtStyle.pageBg,
      appBar: AppBar(
        toolbarHeight: TtStyle.toolbarH,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(AppIcons.chevronLeft),
                onPressed: () => Navigator.maybePop(context),
                tooltip: '返回',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              )
            : null,
        title: Text(
          isClassTab ? '班级课表' : '我的授课',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: TtStyle.title,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '导出本周课表',
            icon: const Icon(AppIcons.share, color: TtStyle.accent),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => _showExportActions(
              context,
              markAsMine: !isClassTab,
              lessons: lessons,
              periods: periods,
              weekStart: weekStart,
              range: range,
              title: isClassTab
                  ? '$classTitle · 班级课表'
                  : '我的授课 · ${ctrl.teachingSubject ?? '未设科目'}',
            ),
          ),
          IconButton(
            tooltip: '新增课程',
            icon: const Icon(AppIcons.plus, color: TtStyle.accent),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => _openManualAdd(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScheduleTabs(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 4),
                if (isClassTab) ...[
                  ClassScheduleBar(
                    title: classTitle,
                    subjects: filterSubjects,
                    filterSubject: _classSubjectFilter,
                    onSwitchClass: () => showClassSwitcherSheet(context),
                    onFilterChanged: (v) =>
                        setState(() => _classSubjectFilter = v),
                  ),
                ] else ...[
                  MyTeachingSummary(
                    subject: ctrl.teachingSubject,
                    lessonCount: lessons.length,
                    aggregateAll: _aggregateAll,
                    subjectOptions: subjectOptions,
                    onSelectSubject: (s) async {
                      await ctrl.setTeachingSubject(s);
                      await ctrl.refreshAllTodayLessons();
                    },
                    onEditSubject: () => _editTeachingSubject(context, ctrl),
                    onToggleAggregate: (v) =>
                        setState(() => _aggregateAll = v),
                  ),
                ],
                ScheduleHeader(
                  rangeLabel: range,
                  secondaryLabel: isClassTab ? '调整课表' : null,
                  onSecondary: isClassTab
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TimetablePeriodsScreen(),
                            ),
                          )
                      : null,
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
                    : !isClassTab && lessons.isEmpty
                        ? _HintEmpty(
                            title: '今日暂无课程安排',
                            subtitle: _aggregateAll
                                ? '可在「班级课表」排课，或点右上角新增。'
                                : '当前班本周无该科目，可开启「汇总全部班级」。',
                            actionLabel: '添加一节',
                            onAction: () => _openManualAdd(context),
                          )
                        : NotificationListener<ScrollMetricsNotification>(
                            onNotification: (n) {
                              final max = n.metrics.maxScrollExtent;
                              final more =
                                  max > 8 && n.metrics.pixels < max - 8;
                              if (more != _canScrollMore) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted && more != _canScrollMore) {
                                    setState(() => _canScrollMore = more);
                                  }
                                });
                              }
                              return false;
                            },
                            child: Stack(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(4, 0, 4, 8),
                                  child: ScheduleGrid(
                                    periods: periods,
                                    weekFullLabels: _weekFull,
                                    weekStart: weekStart,
                                    todayWeekday: todayWd,
                                    verticalScroll: _gridScroll,
                                    lessonsAt: (wd, p) =>
                                        grid['$wd-$p'] ?? const [],
                                    showClassOnBlock: !isClassTab,
                                    hasTodo: (cell) => cell.any(
                                      (l) => _todos.contains(
                                        _markKey(
                                          classId: l.classId.isEmpty
                                              ? (ctrl.currentClass?.id ?? '')
                                              : l.classId,
                                          weekday: l.weekday,
                                          period: l.period,
                                        ),
                                      ),
                                    ),
                                    onTap: (wd, p, cellLessons) {
                                      _showLessonDetail(
                                        context,
                                        ctrl,
                                        weekday: wd,
                                        period: p,
                                        cellLessons: cellLessons,
                                        isClassTab: isClassTab,
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
    final classId = existing?.classId.isNotEmpty == true
        ? existing!.classId
        : (ctrl.currentClass?.id ?? '');
    final key = _markKey(classId: classId, weekday: weekday, period: period);
    final noteCtrl = TextEditingController(text: _notes[key] ?? '');
    var hasTodo = _todos.contains(key);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final periodLabel =
                ctrl.periodAt(period)?.displayLabel ?? '第$period节';
            final time = existing?.timeRange.isNotEmpty == true
                ? existing!.timeRange
                : (ctrl.periodAt(period)?.timeRange ?? '');
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing?.subject ?? '空闲时段',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: TtStyle.courseFg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '周${_weekLabels[weekday - 1]} · $periodLabel'
                    '${time.isEmpty ? '' : ' · $time'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: TtStyle.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (cellLessons.isEmpty)
                    Text(
                      ctrl.currentClass?.displayTitle ?? '',
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: TtStyle.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '添加备注 / 待办说明',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('待办红点标记', style: TextStyle(fontSize: 14)),
                    value: hasTodo,
                    activeThumbColor: TtStyle.todoDot,
                    onChanged: (v) => setSheet(() => hasTodo = v),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LessonProgressScreen(),
                              ),
                            );
                          },
                          child: const Text('备课'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final note = noteCtrl.text.trim();
                            setState(() {
                              if (note.isEmpty) {
                                _notes.remove(key);
                              } else {
                                _notes[key] = note;
                              }
                              if (hasTodo) {
                                _todos.add(key);
                              } else {
                                _todos.remove(key);
                              }
                            });
                            await _persistMarks();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('保存备注'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isClassTab)
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editClassCell(
                          context,
                          ctrl,
                          weekday,
                          period,
                          existing,
                        );
                      },
                      child: Text(existing == null ? '安排课程' : '修改课程'),
                    )
                  else if (cellLessons.isNotEmpty)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF3B30),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        for (final l in cellLessons) {
                          await ctrl.clearMyTeachingLesson(
                            classId: l.classId,
                            weekday: l.weekday,
                            period: l.period,
                          );
                        }
                      },
                      child: Text(
                        cellLessons.length > 1
                            ? '从我的授课中清除本格全部'
                            : '从我的授课中清除',
                      ),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openManualAdd(
                          context,
                          weekday: weekday,
                          period: period,
                        );
                      },
                      child: const Text('添加课程'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
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

  Future<void> _showExportActions(
    BuildContext context, {
    required bool markAsMine,
    required List<TodayTeachingLesson> lessons,
    required List<TimetablePeriod> periods,
    required DateTime weekStart,
    required String range,
    required String title,
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
                  markAsMine ? '分享 / 导出我的授课' : '分享 / 导出班级课表',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(AppIcons.fileSheet, color: TtStyle.accent),
                title: const Text('导出 Excel'),
                subtitle: const Text('生成本周课表表格并分享'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportExcel(
                    lessons: lessons,
                    periods: periods,
                    weekStart: weekStart,
                    range: range,
                    title: title,
                  );
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.share, color: TtStyle.accent),
                title: const Text('导出文本 / 图片备用'),
                subtitle: const Text('复制为可读文本；图片可用系统截图'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final text = _formatWeekText(
                    title: title,
                    range: range,
                    lessons: lessons,
                    periods: periods,
                    weekStart: weekStart,
                  );
                  await Share.share(text, subject: title);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.sparkles, color: TtStyle.accent),
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
              if (!markAsMine)
                ListTile(
                  leading: const Icon(AppIcons.clock, color: TtStyle.accent),
                  title: const Text('节次与作息'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TimetablePeriodsScreen(),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(AppIcons.plus, color: TtStyle.accent),
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

  String _formatWeekText({
    required String title,
    required String range,
    required List<TodayTeachingLesson> lessons,
    required List<TimetablePeriod> periods,
    required DateTime weekStart,
  }) {
    final buf = StringBuffer()
      ..writeln(title)
      ..writeln(range)
      ..writeln();
    for (final p in periods) {
      buf.writeln('${p.displayLabel} ${p.timeRange}');
      for (var d = 1; d <= 7; d++) {
        final day = weekStart.add(Duration(days: d - 1));
        final cell = lessons
            .where((l) => l.weekday == d && l.period == p.period)
            .toList();
        if (cell.isEmpty) continue;
        final names = cell
            .map((l) {
              final c = l.classTitle.trim();
              return c.isEmpty ? l.subject : '${l.subject}（$c）';
            })
            .join('、');
        buf.writeln('  ${_weekFull[d - 1]} ${day.month}.${day.day}：$names');
      }
      buf.writeln();
    }
    return buf.toString();
  }

  Future<void> _exportExcel({
    required List<TodayTeachingLesson> lessons,
    required List<TimetablePeriod> periods,
    required DateTime weekStart,
    required String range,
    required String title,
  }) async {
    try {
      final excel = xls.Excel.createExcel();
      const sheetName = '本周课表';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
          .value = xls.TextCellValue('$title（$range）');
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
          .value = xls.TextCellValue('节次');
      for (var d = 1; d <= 7; d++) {
        final day = weekStart.add(Duration(days: d - 1));
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: d, rowIndex: 1))
            .value = xls.TextCellValue(
              '${_weekFull[d - 1]} ${day.month}.${day.day}',
            );
      }
      for (var i = 0; i < periods.length; i++) {
        final p = periods[i];
        final row = i + 2;
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = xls.TextCellValue(
              '${p.displayLabel} ${p.timeRange}'.trim(),
            );
        for (var d = 1; d <= 7; d++) {
          final cell = lessons
              .where((l) => l.weekday == d && l.period == p.period)
              .map((l) {
                final c = l.classTitle.trim();
                return c.isEmpty ? l.subject : '${l.subject} $c';
              })
              .join(' / ');
          sheet
              .cell(
                xls.CellIndex.indexByColumnRow(columnIndex: d, rowIndex: row),
              )
              .value = xls.TextCellValue(cell);
        }
      }
      final bytes = excel.encode();
      if (bytes == null) throw StateError('encode failed');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/课表_${DateFormat('MMdd_HHmm').format(DateTime.now())}.xlsx';
      await File(path).writeAsBytes(bytes, flush: true);
      await FileShare.shareXlsx(filePath: path, subject: title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
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
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
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
