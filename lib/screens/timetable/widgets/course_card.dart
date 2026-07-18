import 'package:flutter/material.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 课表格内课程块：标题 14/w600，副标题 11
class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.lessons,
    required this.showClass,
    required this.showTodo,
  });

  final List<TodayTeachingLesson> lessons;
  final bool showClass;
  final bool showTodo;

  @override
  Widget build(BuildContext context) {
    final lesson = lessons.first;
    final tint = subjectTint(lesson.subject);
    final subtitle = _subtitle(lessons, showClass: showClass);

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(5, 6, 5, 4),
          decoration: BoxDecoration(
            color: tint.$1,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.subject,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tint.$2,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tint.$2.withValues(alpha: 0.78),
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showTodo)
          const Positioned(
            top: 4,
            right: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: TtStyle.todoDot,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 7, height: 7),
            ),
          ),
      ],
    );
  }

  static String _subtitle(
    List<TodayTeachingLesson> lessons, {
    required bool showClass,
  }) {
    if (showClass) {
      final titles = lessons
          .map((e) => e.classTitle.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (titles.isNotEmpty) return titles.join('、');
    }
    final loc = lessons.first.location.trim();
    if (loc.isNotEmpty) return loc;
    return '';
  }
}
