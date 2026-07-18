import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/widgets/subject_filter.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 「我的授课」单行摘要：科目 · 节数 · 汇总，无卡片边框
class MyTeachingSummary extends StatelessWidget {
  const MyTeachingSummary({
    super.key,
    required this.subject,
    required this.lessonCount,
    required this.aggregateAll,
    required this.subjectOptions,
    required this.onSelectSubject,
    required this.onEditSubject,
    required this.onToggleAggregate,
  });

  final String? subject;
  final int lessonCount;
  final bool aggregateAll;
  final List<String> subjectOptions;
  final ValueChanged<String> onSelectSubject;
  final VoidCallback onEditSubject;
  final ValueChanged<bool> onToggleAggregate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SubjectFilter(
            label: '科目',
            current: subject,
            options: subjectOptions,
            allowAll: false,
            allLabel: '未设置',
            onChanged: (v) {
              if (v != null) {
                onSelectSubject(v);
              } else {
                onEditSubject();
              }
            },
          ),
          if (subject == null)
            TextButton(
              onPressed: onEditSubject,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('设置', style: TextStyle(fontSize: 13)),
            )
          else ...[
            Text(
              '· $lessonCount节',
              style: const TextStyle(fontSize: 13, color: TtStyle.secondary),
            ),
            const Spacer(),
            InkWell(
              onTap: () => onToggleAggregate(!aggregateAll),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  aggregateAll ? '全部班级' : '仅本班',
                  style: const TextStyle(
                    fontSize: 13,
                    color: TtStyle.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 班级课表顶栏：班级名 + 科目筛选（无边框、无图标）
class ClassScheduleBar extends StatelessWidget {
  const ClassScheduleBar({
    super.key,
    required this.title,
    required this.subjects,
    required this.filterSubject,
    required this.onSwitchClass,
    required this.onFilterChanged,
  });

  final String title;
  final List<String> subjects;
  final String? filterSubject;
  final VoidCallback onSwitchClass;
  final ValueChanged<String?> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: onSwitchClass,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TtStyle.title,
                  ),
                ),
              ),
            ),
          ),
          if (subjects.isNotEmpty)
            SubjectFilter(
              label: '科目',
              current: filterSubject,
              options: subjects,
              onChanged: onFilterChanged,
            ),
        ],
      ),
    );
  }
}
