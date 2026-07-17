import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 节次与作息：独立页面，管理每天几节课及每节名称、时间
class TimetablePeriodsScreen extends StatelessWidget {
  const TimetablePeriodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final periods = ctrl.timetablePeriods;

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('节次与作息'),
        actions: [
          IconButton(
            tooltip: '添加一节',
            onPressed: () => ctrl.addTimetablePeriod(),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _SummaryCard(periods: periods),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              '点按某一节可修改名称与上下课时间',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < periods.length; i++)
                  _TimelinePeriodTile(
                    period: periods[i],
                    isFirst: i == 0,
                    isLast: i == periods.length - 1,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PeriodEditScreen(periodNumber: periods[i].period),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (periods.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GroupedSection(
                children: [
                  GroupedTile(
                    title: '删除最后一节',
                    titleColor: AppTheme.destructive,
                    leading: Icon(AppIcons.trash, color: AppTheme.destructive),
                    onTap: () => _confirmDeleteLast(context, ctrl),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _confirmDeleteLast(
    BuildContext context,
    ClassController ctrl,
  ) async {
    final periods = ctrl.timetablePeriods;
    if (periods.length <= 1) return;
    final last = periods.last;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除最后一节'),
        content: Text('将删除「${last.displayLabel}」及其课表内容，至少保留一节。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: AppTheme.destructive)),
          ),
        ],
      ),
    );
    if (ok != true) return;
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
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.periods});

  final List<TimetablePeriod> periods;

  String _timeSpan() {
    if (periods.isEmpty) return '尚未设置';
    final first = periods.first;
    final last = periods.last;
    final start = first.startTime.trim();
    final end = last.endTime.trim().isNotEmpty
        ? last.endTime.trim()
        : last.startTime.trim();
    if (start.isEmpty && end.isEmpty) return '时间待设置';
    if (start.isNotEmpty && end.isNotEmpty) return '$start — $end';
    return start.isNotEmpty ? '$start 起' : '至 $end';
  }

  @override
  Widget build(BuildContext context) {
    final n = periods.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.blue.withValues(alpha: 0.14),
            AppTheme.blue.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blue.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: AppTheme.blue,
                    ),
                  ),
                  Text(
                    '节',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.blue.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每日课表节次',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(AppIcons.clock, size: 15, color: AppTheme.blue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _timeSpan(),
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryLabel,
                          ),
                        ),
                      ),
                    ],
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

class _TimelinePeriodTile extends StatelessWidget {
  const _TimelinePeriodTile({
    required this.period,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final TimetablePeriod period;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasTime = period.timeRange.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppTheme.blue.withValues(alpha: 0.2),
                    ),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.blue.withValues(alpha: 0.35),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppTheme.blue.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.separator.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${period.period}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                period.displayLabel,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.label,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.clock,
                                    size: 14,
                                    color: hasTime
                                        ? AppTheme.secondaryLabel
                                        : AppTheme.tertiaryLabel,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    hasTime ? period.timeRange : '未设置时间',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: hasTime
                                          ? AppTheme.secondaryLabel
                                          : AppTheme.tertiaryLabel,
                                    ),
                                  ),
                                ],
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 编辑单节：名称与上下课时间
class PeriodEditScreen extends StatefulWidget {
  const PeriodEditScreen({super.key, required this.periodNumber});

  final int periodNumber;

  @override
  State<PeriodEditScreen> createState() => _PeriodEditScreenState();
}

class _PeriodEditScreenState extends State<PeriodEditScreen> {
  late final TextEditingController _label;
  late String _start;
  late String _end;

  @override
  void initState() {
    super.initState();
    final row = context.read<ClassController>().periodAt(widget.periodNumber) ??
        TimetablePeriod(period: widget.periodNumber, label: '第${widget.periodNumber}节');
    _label = TextEditingController(text: row.label);
    _start = row.startTime;
    _end = row.endTime;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<ClassController>().saveTimetablePeriod(
          TimetablePeriod(
            period: widget.periodNumber,
            label: _label.text.trim(),
            startTime: _start,
            endTime: _end,
          ),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text('编辑第 ${widget.periodNumber} 节'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '可改为「早读」「午休」等自定义名称',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ),
          GroupedSection(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: '节次名称',
                    hintText: '如第1节、早读',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GroupedSection(
            header: '上课时间',
            children: [
              GroupedTile(
                title: '开始',
                subtitle: _start.isEmpty ? '未设置' : _start,
                leading: Icon(AppIcons.clock, color: AppTheme.blue),
                trailing: Icon(AppIcons.chevronRight,
                    size: 18, color: AppTheme.tertiaryLabel),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _parseTime(_start),
                  );
                  if (t != null) setState(() => _start = _formatTime(t));
                },
              ),
              GroupedTile(
                title: '结束',
                subtitle: _end.isEmpty ? '未设置' : _end,
                leading: Icon(AppIcons.clock, color: AppTheme.blue),
                trailing: Icon(AppIcons.chevronRight,
                    size: 18, color: AppTheme.tertiaryLabel),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _parseTime(_end),
                  );
                  if (t != null) setState(() => _end = _formatTime(t));
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
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
}
