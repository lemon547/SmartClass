import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';

/// 课程表：周一到周日 × 1–8 节，点按编辑（常见中小学课程表结构）
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  static const _days = ['一', '二', '三', '四', '五', '六', '日'];
  static const _periodCount = 8;

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

  static Color _colorFor(String subject) {
    if (subject.isEmpty) return AppTheme.fill;
    final i = subject.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    return _palette[i];
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final today = DateTime.now().weekday;
    final filled = ctrl.timetable.where((s) => s.subject.trim().isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('课程表'),
        actions: [
          IconButton(
            tooltip: 'Excel',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '课程表',
              downloadTemplate: () =>
                  context.read<ClassController>().exportTimetableTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importTimetableFromBytes(bytes),
            ),
            icon: const Icon(Icons.table_chart_outlined),
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
              '点按格子填写科目，留空可清除 · 今天已高亮',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dayW = ((constraints.maxWidth - 40) / 7).clamp(44.0, 72.0);
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _TimetableGrid(
                      dayWidth: dayW,
                      todayWeekday: today,
                      subjectAt: ctrl.subjectAt,
                      onTap: (w, p) => _edit(context, w, p),
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

  Future<void> _edit(BuildContext context, int weekday, int period) async {
    final ctrl = context.read<ClassController>();
    final text = TextEditingController(
      text: ctrl.subjectAt(weekday, period) ?? '',
    );
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
                '周${_days[weekday - 1]} · 第 $period 节',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                decoration: const InputDecoration(
                  hintText: '科目名称，如语文、数学',
                  labelText: '科目',
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const [
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
                  ])
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

class _TimetableGrid extends StatelessWidget {
  const _TimetableGrid({
    required this.dayWidth,
    required this.todayWeekday,
    required this.subjectAt,
    required this.onTap,
  });

  final double dayWidth;
  final int todayWeekday;
  final String? Function(int weekday, int period) subjectAt;
  final void Function(int weekday, int period) onTap;

  static const _days = TimetableScreen._days;
  static const _periodCount = TimetableScreen._periodCount;

  @override
  Widget build(BuildContext context) {
    const periodW = 36.0;
    const cellH = 52.0;
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
          for (var p = 1; p <= _periodCount; p++)
            SizedBox(
              height: cellH,
              child: Row(
                children: [
                  SizedBox(
                    width: periodW,
                    child: Center(
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.tertiaryLabel,
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
                          onTap: () => onTap(d, p),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppTheme.separator.withValues(alpha: 0.25),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _Cell(
                              subject: subjectAt(d, p),
                            ),
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
    final c = TimetableScreen._colorFor(s);
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
