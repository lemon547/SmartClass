import 'package:flutter/material.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 课表格内课程块：科目 + 班级 + 节次，尽量不截断
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
    final classLine = showClass ? _classLine(lessons) : '';

    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(5, 7, 5, 5),
          decoration: BoxDecoration(
            color: tint.$1,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.subject,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: tint.$2,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              if (classLine.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  classLine,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: tint.$2.withValues(alpha: 0.82),
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                lesson.periodLabel.isNotEmpty
                    ? lesson.periodLabel
                    : '第${lesson.period}节',
                maxLines: 1,
                style: TextStyle(
                  color: tint.$2.withValues(alpha: 0.65),
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
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

  static String _classLine(List<TodayTeachingLesson> lessons) {
    final titles = lessons
        .map((e) => e.classTitle.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (titles.isEmpty) {
      final loc = lessons.first.location.trim();
      return loc;
    }
    if (titles.length == 1) return titles.first;
    // 多班：换行列出，避免「班、高一…」截断
    return titles.join('\n');
  }
}
