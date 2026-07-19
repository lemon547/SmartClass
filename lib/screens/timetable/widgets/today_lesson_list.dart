import 'package:flutter/material.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';
import 'package:smart_class/theme/app_icons.dart';

/// 手机端今日课程列表（我的课表默认视图）
class TodayLessonList extends StatelessWidget {
  const TodayLessonList({
    super.key,
    required this.lessons,
    required this.today,
    required this.onTapLesson,
  });

  final List<TodayTeachingLesson> lessons;
  final DateTime today;
  final void Function(TodayTeachingLesson lesson) onTapLesson;

  @override
  Widget build(BuildContext context) {
    final dateLine =
        '${today.month}月${today.day}日 周${'一二三四五六日'[today.weekday - 1]}';
    final sorted = [...lessons]
      ..sort((a, b) {
        final c = a.period.compareTo(b.period);
        if (c != 0) return c;
        return a.classTitle.compareTo(b.classTitle);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(
          dateLine,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: TtStyle.title,
          ),
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          const EmptySchedule(message: '今日暂无课程')
        else
          for (final lesson in sorted) ...[
            _TodayLessonTile(
              lesson: lesson,
              onTap: () => onTapLesson(lesson),
            ),
            const SizedBox(height: 10),
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 28),
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

class _TodayLessonTile extends StatelessWidget {
  const _TodayLessonTile({required this.lesson, required this.onTap});

  final TodayTeachingLesson lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = subjectTint(lesson.subject);
    final time = lesson.timeRange.isNotEmpty
        ? lesson.timeRange
        : (lesson.startTime.isNotEmpty
            ? (lesson.endTime.isNotEmpty
                ? '${lesson.startTime}-${lesson.endTime}'
                : lesson.startTime)
            : '');
    final startOnly = time.contains('-')
        ? time.split('-').first.trim()
        : (time.isNotEmpty ? time : lesson.periodLabel);
    final location = lesson.location.trim();

    return Material(
      color: tint.$1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  startOnly,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tint.$2,
                    height: 1.2,
                  ),
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
                        color: tint.$2,
                      ),
                    ),
                    if (lesson.classTitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lesson.classTitle.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: tint.$2.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: TextStyle(
                          fontSize: 12,
                          color: tint.$2.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: tint.$2.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
