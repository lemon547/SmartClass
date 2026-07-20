import 'package:flutter/material.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';
import 'package:smart_class/theme/app_icons.dart';

/// 我的课表：今日列表 + 本周按天分行（与今日同款卡片）
class MyScheduleList extends StatelessWidget {
  const MyScheduleList({
    super.key,
    required this.todayLessons,
    required this.todayLabel,
    required this.weekLessons,
    required this.weekStart,
    required this.todayWeekday,
    required this.onTapLesson,
  });

  final List<TodayTeachingLesson> todayLessons;
  final String todayLabel;
  final List<TodayTeachingLesson> weekLessons;
  final DateTime weekStart;
  final int todayWeekday;
  final void Function(TodayTeachingLesson lesson) onTapLesson;

  static const _weekNames = '一二三四五六日';

  @override
  Widget build(BuildContext context) {
    final todaySorted = _sortDay(todayLessons);
    // 本周其余天（不含今日，避免重复）
    final byDay = <int, List<TodayTeachingLesson>>{};
    for (final l in weekLessons) {
      if (l.weekday == todayWeekday) continue;
      byDay.putIfAbsent(l.weekday, () => []).add(l);
    }
    for (final e in byDay.entries) {
      e.value.sort((a, b) {
        final c = a.period.compareTo(b.period);
        if (c != 0) return c;
        return a.classTitle.compareTo(b.classTitle);
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _DayHeader(
          eyebrow: '今日',
          title: '周${_weekNames[todayWeekday - 1]}',
          date: todayLabel,
        ),
        const SizedBox(height: 10),
        if (todaySorted.isEmpty)
          const EmptySchedule(message: '今日暂无课程')
        else
          for (final lesson in todaySorted) ...[
            LessonScheduleTile(
              lesson: lesson,
              tint: weekdayTint(todayWeekday),
              onTap: () => onTapLesson(lesson),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 12),
        const Text(
          '本周',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: TtStyle.title,
          ),
        ),
        const SizedBox(height: 10),
        if (byDay.isEmpty)
          const EmptySchedule(message: '本周暂无其他课程')
        else
          for (var wd = 1; wd <= 7; wd++)
            if (byDay.containsKey(wd)) ...[
              _DayHeader(
                title: '周${_weekNames[wd - 1]}',
                date: _monthDay(wd),
              ),
              const SizedBox(height: 8),
              for (final lesson in byDay[wd]!) ...[
                LessonScheduleTile(
                  lesson: lesson,
                  tint: weekdayTint(wd),
                  onTap: () => onTapLesson(lesson),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
            ],
      ],
    );
  }

  String _monthDay(int weekday) {
    final date = weekStart.add(Duration(days: weekday - 1));
    return '${date.month}月${date.day}日';
  }

  static List<TodayTeachingLesson> _sortDay(List<TodayTeachingLesson> lessons) {
    final sorted = [...lessons]
      ..sort((a, b) {
        final c = a.period.compareTo(b.period);
        if (c != 0) return c;
        return a.classTitle.compareTo(b.classTitle);
      });
    return sorted;
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.title,
    required this.date,
    this.eyebrow,
  });
  final String title;
  final String date;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: TtStyle.secondary,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: TtStyle.title,
                ),
              ),
            ],
          ),
        ),
        Text(
          date,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: TtStyle.secondary,
          ),
        ),
      ],
    );
  }
}

/// 紧凑空状态（无操作按钮）
class EmptySchedule extends StatelessWidget {
  const EmptySchedule({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(AppIcons.calendar, size: 28, color: TtStyle.emptyHint),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: TtStyle.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 课程行卡片（今日 / 本周共用）
class LessonScheduleTile extends StatelessWidget {
  const LessonScheduleTile({
    super.key,
    required this.lesson,
    required this.onTap,
    this.tint,
  });

  final TodayTeachingLesson lesson;
  final VoidCallback onTap;
  /// 按天配色（底色 + 文字）；不传则按科目
  final (Color bg, Color fg)? tint;

  @override
  Widget build(BuildContext context) {
    final colors = tint ?? subjectTint(lesson.subject);
    final bg = colors.$1;
    final fg = colors.$2;
    final time = lesson.timeRange.isNotEmpty
        ? lesson.timeRange
        : (lesson.startTime.isNotEmpty
            ? (lesson.endTime.isNotEmpty
                ? '${lesson.startTime}-${lesson.endTime}'
                : lesson.startTime)
            : '');
    final start = time.contains('-')
        ? time.split('-').first.trim()
        : (time.isNotEmpty ? time : lesson.periodLabel);
    final end = time.contains('-') ? time.split('-').last.trim() : '';
    final location = lesson.location.trim();
    final timeStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: fg.withValues(alpha: 0.75),
      height: 1.2,
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(start, style: timeStyle),
                    if (end.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(end, style: timeStyle),
                    ],
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
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if (lesson.classTitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson.classTitle.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: fg.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: fg.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
