import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/widgets/subject_filter.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 「我的授课」筛选入口：默认收起，点击展开科目 / 班级
class MyTeachingSummary extends StatefulWidget {
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
  State<MyTeachingSummary> createState() => _MyTeachingSummaryState();
}

class _MyTeachingSummaryState extends State<MyTeachingSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject?.trim();
    final hasSubject = subject != null && subject.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (!hasSubject) {
                  widget.onEditSubject();
                  return;
                }
                setState(() => _expanded = !_expanded);
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: hasSubject
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: TtStyle.title,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '本周${widget.lessonCount}节',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: TtStyle.muted,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              '设置授课科目',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: TtStyle.accent,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: TtStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                SubjectFilter(
                  label: '科目',
                  current: widget.subject,
                  options: widget.subjectOptions,
                  allowAll: false,
                  allLabel: '未设置',
                  compact: true,
                  onChanged: (v) {
                    if (v != null) {
                      widget.onSelectSubject(v);
                    } else {
                      widget.onEditSubject();
                    }
                  },
                ),
                const SizedBox(width: 8),
                _FilterChipButton(
                  label: widget.aggregateAll ? '全部班级' : '仅本班',
                  onTap: () =>
                      widget.onToggleAggregate(!widget.aggregateAll),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TtStyle.accentSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: TtStyle.accent,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: TtStyle.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 班级课表顶栏：班级名 + 科目筛选
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: TtStyle.title,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: TtStyle.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (subjects.isNotEmpty)
            SubjectFilter(
              label: '科目',
              current: filterSubject,
              options: subjects,
              compact: true,
              onChanged: onFilterChanged,
            ),
        ],
      ),
    );
  }
}
