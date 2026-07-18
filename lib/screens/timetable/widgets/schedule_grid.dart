import 'package:flutter/material.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/screens/timetable/widgets/course_card.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 周课表网格：固定左侧时间栏、顶部星期吸附、横向滑动星期、今日蓝点
class ScheduleGrid extends StatefulWidget {
  const ScheduleGrid({
    super.key,
    required this.periods,
    required this.weekFullLabels,
    required this.weekStart,
    required this.todayWeekday,
    required this.verticalScroll,
    required this.lessonsAt,
    required this.showClassOnBlock,
    required this.hasTodo,
    required this.onTap,
  });

  final List<TimetablePeriod> periods;
  final List<String> weekFullLabels;
  final DateTime weekStart;
  final int todayWeekday;
  final ScrollController verticalScroll;
  final List<TodayTeachingLesson> Function(int weekday, int period) lessonsAt;
  final bool showClassOnBlock;
  final bool Function(List<TodayTeachingLesson> lessons) hasTodo;
  final void Function(
    int weekday,
    int period,
    List<TodayTeachingLesson> lessons,
  ) onTap;

  @override
  State<ScheduleGrid> createState() => _ScheduleGridState();
}

class _ScheduleGridState extends State<ScheduleGrid> {
  final _hHeader = ScrollController();
  final _hBody = ScrollController();
  bool _syncing = false;
  bool _didAutoScroll = false;

  @override
  void initState() {
    super.initState();
    _hHeader.addListener(() => _syncFrom(_hHeader, _hBody));
    _hBody.addListener(() => _syncFrom(_hBody, _hHeader));
  }

  @override
  void dispose() {
    _hHeader.dispose();
    _hBody.dispose();
    super.dispose();
  }

  void _syncFrom(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) return;
    if ((from.offset - to.offset).abs() < 0.5) return;
    _syncing = true;
    to.jumpTo(from.offset.clamp(0.0, to.position.maxScrollExtent));
    _syncing = false;
  }

  void _scrollTodayIntoView(double dayW) {
    if (_didAutoScroll || !_hBody.hasClients) return;
    _didAutoScroll = true;
    final idx = (widget.todayWeekday - 1).clamp(0, 6);
    final target = (idx * dayW) - dayW * 0.5;
    final max = _hBody.position.maxScrollExtent;
    if (max <= 0) return;
    _hBody.jumpTo(target.clamp(0.0, max));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - TtStyle.periodW;
        final dayW = (available / 5).clamp(TtStyle.dayMinW, 88.0);
        final daysWidth = dayW * 7;
        final bodyH = TtStyle.cellH * widget.periods.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollTodayIntoView(dayW);
        });

        return Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: TtStyle.periodW),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (_) => false,
                      child: SingleChildScrollView(
                        controller: _hHeader,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: daysWidth,
                          child: Row(
                            children: [
                              for (var d = 1; d <= 7; d++)
                                SizedBox(
                                  width: dayW,
                                  child: _DayHeader(
                                    label: widget.weekFullLabels[d - 1],
                                    date: widget.weekStart
                                        .add(Duration(days: d - 1)),
                                    isToday: d == widget.todayWeekday,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 0.5, color: TtStyle.line),
            Expanded(
              child: SingleChildScrollView(
                controller: widget.verticalScroll,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  height: bodyH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: TtStyle.periodW,
                        child: Column(
                          children: [
                            for (final row in widget.periods)
                              SizedBox(
                                height: TtStyle.cellH,
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: TtStyle.line,
                                        width: 0.5,
                                      ),
                                      bottom: BorderSide(
                                        color: TtStyle.line,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: _PeriodSide(period: row),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _hBody,
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: SizedBox(
                            width: daysWidth,
                            height: bodyH,
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i < widget.periods.length;
                                    i++)
                                  SizedBox(
                                    height: TtStyle.cellH,
                                    child: Row(
                                      children: [
                                        for (var d = 1; d <= 7; d++)
                                          SizedBox(
                                            width: dayW,
                                            height: TtStyle.cellH,
                                            child: _ScheduleCell(
                                              lessons: widget.lessonsAt(
                                                d,
                                                widget.periods[i].period,
                                              ),
                                              showClass:
                                                  widget.showClassOnBlock,
                                              showTodo: widget.hasTodo(
                                                widget.lessonsAt(
                                                  d,
                                                  widget.periods[i].period,
                                                ),
                                              ),
                                              onTap: () => widget.onTap(
                                                d,
                                                widget.periods[i].period,
                                                widget.lessonsAt(
                                                  d,
                                                  widget.periods[i].period,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.date,
    required this.isToday,
  });

  final String label;
  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isToday ? TtStyle.accent : TtStyle.secondary,
            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isToday)
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 3),
                decoration: const BoxDecoration(
                  color: TtStyle.accent,
                  shape: BoxShape.circle,
                ),
              ),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                color: isToday ? TtStyle.accent : TtStyle.muted,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PeriodSide extends StatelessWidget {
  const _PeriodSide({required this.period});
  final TimetablePeriod period;

  @override
  Widget build(BuildContext context) {
    final range = period.timeRange;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${period.period}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.1,
              color: TtStyle.title,
            ),
          ),
          const Text(
            '节',
            style: TextStyle(fontSize: 10, color: TtStyle.muted, height: 1.1),
          ),
          if (range.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              range.split('-').first.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: TtStyle.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({
    required this.lessons,
    required this.showClass,
    required this.showTodo,
    required this.onTap,
  });

  final List<TodayTeachingLesson> lessons;
  final bool showClass;
  final bool showTodo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = lessons.isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: TtStyle.line, width: 0.5),
              bottom: BorderSide(color: TtStyle.line, width: 0.5),
            ),
          ),
          child: !has
              ? const SizedBox.expand()
              : Padding(
                  padding: const EdgeInsets.all(3),
                  child: CourseCard(
                    lessons: lessons,
                    showClass: showClass,
                    showTodo: showTodo,
                  ),
                ),
        ),
      ),
    );
  }
}
