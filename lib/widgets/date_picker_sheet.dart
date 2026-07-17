import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// iOS 风格日期选择：底部弹出，无系统 Material 对话框
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = DateTime(
    (firstDate ?? DateTime(2020)).year,
    (firstDate ?? DateTime(2020)).month,
    (firstDate ?? DateTime(2020)).day,
  );
  final last = DateTime(
    (lastDate ?? DateTime.now().add(const Duration(days: 365))).year,
    (lastDate ?? DateTime.now().add(const Duration(days: 365))).month,
    (lastDate ?? DateTime.now().add(const Duration(days: 365))).day,
  );
  var selected = _clampDate(initialDate, first, last);
  var month = DateTime(selected.year, selected.month);

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          void setMonth(DateTime m) {
            setModal(() => month = DateTime(m.year, m.month));
          }

          void setSelected(DateTime d) {
            setModal(() => selected = d);
          }

          final today = DateTime.now();
          final todayOnly = DateTime(today.year, today.month, today.day);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.quaternaryLabel,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('yyyy年M月').format(month),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('M月d日 EEEE', 'zh_CN').format(selected),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _isSameDay(selected, todayOnly) ||
                                todayOnly.isBefore(first) ||
                                todayOnly.isAfter(last)
                            ? null
                            : () => setSelected(todayOnly),
                        child: const Text('今天'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        onPressed: month.isAfter(
                          DateTime(first.year, first.month),
                        )
                            ? () => setMonth(
                                  DateTime(month.year, month.month - 1),
                                )
                            : null,
                        icon: Icon(
                          AppIcons.chevronLeft,
                          color: month.isAfter(DateTime(first.year, first.month))
                              ? AppTheme.blue
                              : AppTheme.quaternaryLabel,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('yyyy年M月').format(month),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: month.isBefore(
                          DateTime(last.year, last.month),
                        )
                            ? () => setMonth(
                                  DateTime(month.year, month.month + 1),
                                )
                            : null,
                        icon: Icon(
                          AppIcons.chevronRight,
                          color:
                              month.isBefore(DateTime(last.year, last.month))
                                  ? AppTheme.blue
                                  : AppTheme.quaternaryLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _MonthGrid(
                    month: month,
                    selected: selected,
                    first: first,
                    last: last,
                    today: todayOnly,
                    onSelect: setSelected,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.first,
    required this.last,
    required this.today,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday = 0
    final leading = (firstOfMonth.weekday + 6) % 7;
    final cells = <DateTime?>[];

    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var r = 0; r < cells.length ~/ 7; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _DayCell(
                      date: cells[r * 7 + c],
                      selected: selected,
                      first: first,
                      last: last,
                      today: today,
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.first,
    required this.last,
    required this.today,
    required this.onSelect,
  });

  final DateTime? date;
  final DateTime selected;
  final DateTime first;
  final DateTime last;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    if (date == null) return const SizedBox(height: 40);

    final enabled = !date!.isBefore(first) && !date!.isAfter(last);
    final isSelected = _isSameDay(date!, selected);
    final isToday = _isSameDay(date!, today);

    return SizedBox(
      height: 40,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onSelect(date!) : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.blue : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: AppTheme.blue, width: 1.5)
                    : null,
              ),
              child: Text(
                '${date!.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: !enabled
                      ? AppTheme.quaternaryLabel
                      : isSelected
                          ? Colors.white
                          : AppTheme.label,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
  final d = DateTime(value.year, value.month, value.day);
  if (d.isBefore(first)) return first;
  if (d.isAfter(last)) return last;
  return d;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 考勤页周条：点选日期，左右切换周
class WeekDateStrip extends StatelessWidget {
  const WeekDateStrip({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onOpenCalendar,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback? onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => onChanged(selected.subtract(const Duration(days: 7))),
                icon: Icon(AppIcons.chevronLeft, color: AppTheme.blue, size: 20),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (final d in days)
                      Expanded(
                        child: _WeekDayChip(
                          date: d,
                          selected: _isSameDay(d, selected),
                          isToday: _isSameDay(d, today),
                          onTap: () => onChanged(d),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onOpenCalendar,
                icon: Icon(AppIcons.calendar, color: AppTheme.blue, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  static const _week = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(
                _week[date.weekday - 1],
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppTheme.blue : AppTheme.tertiaryLabel,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppTheme.blue : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : isToday
                            ? AppTheme.blue
                            : AppTheme.label,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
