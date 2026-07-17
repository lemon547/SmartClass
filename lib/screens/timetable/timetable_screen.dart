import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 课程表：周一到周日固定；节次名称、时间可自定义；可标记本人授课科目
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  static const _days = ['一', '二', '三', '四', '五', '六', '日'];

  static const _palette = <Color>[
    Color(0xFF5AC8FA),
    Color(0xFF34C759),
    Color(0xFFFF9500),
    Color(0xFFFF2D55),
    Color(0xFF30B0C7),
    Color(0xFF007AFF),
    Color(0xFFFFCC00),
    Color(0xFFAF52DE),
  ];

  static Color colorFor(String subject) {
    if (subject.isEmpty) return AppTheme.fill;
    final i = subject.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    return _palette[i];
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final today = DateTime.now().weekday;
    final periods = ctrl.timetablePeriods;
    final filled =
        ctrl.timetable.where((s) => s.subject.trim().isNotEmpty).length;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('班级课表'),
        actions: [
          IconButton(
            tooltip: '添加一节',
            onPressed: () => ctrl.addTimetablePeriod(),
            icon: const Icon(AppIcons.plus),
          ),
          if (periods.length > 1)
            IconButton(
              tooltip: '删除最后一节',
              onPressed: () => _deleteLastPeriod(context, ctrl),
              icon: Icon(AppIcons.trash, color: AppTheme.destructive),
            ),
          if (filled > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$filled 节',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.tertiaryLabel,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '星期固定；点左侧可改节次名与时间；蓝框为本人授课',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _MySubjectsBar(
              subjects: ctrl.teachingSubjects,
              onAdd: () => _addTeachingSubject(context, ctrl),
              onRemove: ctrl.removeTeachingSubject,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayW =
                    ((constraints.maxWidth - 56) / 7).clamp(44.0, 72.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _TimetableGrid(
                      dayWidth: dayW,
                      todayWeekday: today,
                      periods: periods,
                      subjectAt: ctrl.subjectAt,
                      isMySubject: ctrl.isMyTeachingSubject,
                      onTapCell: (w, p) => _editCell(context, w, p),
                      onTapPeriod: (p) => _editPeriod(context, p),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _deleteLastPeriod(
    BuildContext context,
    ClassController ctrl,
  ) async {
    try {
      await ctrl.deleteLastTimetablePeriod();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  static Future<void> _addTeachingSubject(
    BuildContext context,
    ClassController ctrl,
  ) async {
    final text = TextEditingController();
    final presets = [
      ...ctrl.teachingSubjects,
      ...const ['语文', '数学', '英语', '物理', '化学', '体育', '班会'],
    ].toSet().toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('添加授课科目', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                decoration: const InputDecoration(
                  labelText: '科目名称',
                  hintText: '如语文、数学',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in presets)
                    if (!ctrl.teachingSubjects.contains(s))
                      ActionChip(
                        label: Text(s),
                        onPressed: () => text.text = s,
                      ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ctrl.addTeachingSubject(text.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('添加'),
              ),
            ],
          ),
        );
      },
    );
  }

  static Future<void> _editPeriod(BuildContext context, int period) async {
    final ctrl = context.read<ClassController>();
    final row = ctrl.periodAt(period) ??
        TimetablePeriod(period: period, label: '第$period节');
    final label = TextEditingController(text: row.label);
    var start = row.startTime;
    var end = row.endTime;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '编辑第 $period 节',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: label,
                    decoration: const InputDecoration(
                      labelText: '节次名称',
                      hintText: '如第1节、早读、午休',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开始时间'),
                    subtitle: Text(start.isEmpty ? '未设置' : start),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: _parseTime(start),
                      );
                      if (t != null) {
                        setLocal(() => start = _formatTime(t));
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('结束时间'),
                    subtitle: Text(end.isEmpty ? '未设置' : end),
                    trailing: const Icon(Icons.schedule_outlined),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: ctx,
                        initialTime: _parseTime(end),
                      );
                      if (t != null) {
                        setLocal(() => end = _formatTime(t));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await ctrl.saveTimetablePeriod(
                        TimetablePeriod(
                          period: period,
                          label: label.text.trim(),
                          startTime: start,
                          endTime: end,
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 8;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  static String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  static Future<void> _editCell(
    BuildContext context,
    int weekday,
    int period,
  ) async {
    final ctrl = context.read<ClassController>();
    final row = ctrl.periodAt(period);
    final periodLabel = row?.displayLabel ?? '第 $period 节';
    final timeLabel = row?.timeRange ?? '';
    final text = TextEditingController(
      text: ctrl.subjectAt(weekday, period) ?? '',
    );
    final mySubjects = ctrl.teachingSubjects;
    final presets = [
      ...mySubjects,
      ...const [
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
        '自习',
      ],
    ].toSet().toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '周${_days[weekday - 1]} · $periodLabel',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              if (timeLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.secondaryLabel,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                decoration: const InputDecoration(
                  hintText: '科目名称',
                  labelText: '科目',
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
              ),
              if (mySubjects.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '我的授课',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in mySubjects)
                      ActionChip(
                        label: Text(s),
                        onPressed: () => text.text = s,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in presets)
                    if (!mySubjects.contains(s))
                      ActionChip(
                        label: Text(s),
                        onPressed: () => text.text = s,
                      ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if ((ctrl.subjectAt(weekday, period) ?? '').isNotEmpty)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await ctrl.setTimetableSlot(
                            weekday: weekday,
                            period: period,
                            subject: '',
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(
                          '清除',
                          style: TextStyle(color: AppTheme.destructive),
                        ),
                      ),
                    ),
                  if ((ctrl.subjectAt(weekday, period) ?? '').isNotEmpty)
                    const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () async {
                        await ctrl.setTimetableSlot(
                          weekday: weekday,
                          period: period,
                          subject: text.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MySubjectsBar extends StatelessWidget {
  const _MySubjectsBar({
    required this.subjects,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> subjects;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.fill,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '我的授课科目',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryLabel,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(AppIcons.plus, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
            if (subjects.isEmpty)
              Text(
                '添加后，课程表中对应格子会高亮显示',
                style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subjects)
                    InputChip(
                      label: Text(s),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => onRemove(s),
                      selected: true,
                      selectedColor: AppTheme.blue.withValues(alpha: 0.15),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({
    required this.dayWidth,
    required this.todayWeekday,
    required this.periods,
    required this.subjectAt,
    required this.isMySubject,
    required this.onTapCell,
    required this.onTapPeriod,
  });

  final double dayWidth;
  final int todayWeekday;
  final List<TimetablePeriod> periods;
  final String? Function(int weekday, int period) subjectAt;
  final bool Function(String? subject) isMySubject;
  final void Function(int weekday, int period) onTapCell;
  final void Function(int period) onTapPeriod;

  static const _days = TimetableScreen._days;

  @override
  Widget build(BuildContext context) {
    const periodW = 52.0;
    const cellH = 56.0;
    const headH = 36.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.separator.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: headH,
            child: Row(
              children: [
                SizedBox(
                  width: periodW,
                  child: Center(
                    child: Text(
                      '节',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.tertiaryLabel,
                      ),
                    ),
                  ),
                ),
                for (var d = 1; d <= 7; d++)
                  SizedBox(
                    width: dayWidth,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: d == todayWeekday
                            ? AppTheme.blue.withValues(alpha: 0.1)
                            : null,
                        borderRadius: d == todayWeekday
                            ? const BorderRadius.vertical(
                                top: Radius.circular(11),
                              )
                            : null,
                      ),
                      child: Text(
                        _days[d - 1],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: d == todayWeekday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: d == todayWeekday
                              ? AppTheme.blue
                              : AppTheme.secondaryLabel,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final row in periods)
            SizedBox(
              height: cellH,
              child: Row(
                children: [
                  SizedBox(
                    width: periodW,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTapPeriod(row.period),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                row.displayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryLabel,
                                ),
                              ),
                              if (row.timeRange.isNotEmpty)
                                Text(
                                  row.timeRange,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.tertiaryLabel,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (var d = 1; d <= 7; d++)
                    SizedBox(
                      width: dayWidth,
                      height: cellH,
                      child: Material(
                        color: d == todayWeekday
                            ? AppTheme.blue.withValues(alpha: 0.04)
                            : Colors.transparent,
                        child: InkWell(
                          onTap: () => onTapCell(d, row.period),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isMySubject(subjectAt(d, row.period))
                                    ? AppTheme.blue
                                    : AppTheme.separator
                                        .withValues(alpha: 0.25),
                                width: isMySubject(subjectAt(d, row.period))
                                    ? 1.5
                                    : 1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _Cell(subject: subjectAt(d, row.period)),
                          ),
                        ),
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

class _Cell extends StatelessWidget {
  const _Cell({required this.subject});

  final String? subject;

  @override
  Widget build(BuildContext context) {
    final s = subject?.trim() ?? '';
    if (s.isEmpty) {
      return Center(
        child: Icon(
          AppIcons.plus,
          size: 14,
          color: AppTheme.quaternaryLabel,
        ),
      );
    }
    final c = TimetableScreen.colorFor(s);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        s,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.15,
          color: c.withValues(alpha: 1),
        ),
      ),
    );
  }
}
