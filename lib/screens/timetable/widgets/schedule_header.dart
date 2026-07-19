import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';
import 'package:smart_class/theme/app_icons.dart';

/// 周导航：&lt; 日期范围 &gt;，偏离本周时显示「回到今天」
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.rangeLabel,
    this.showJumpToday = false,
    this.onJumpToday,
    this.onPrevWeek,
    this.onNextWeek,
  });

  final String rangeLabel;
  final bool showJumpToday;
  final VoidCallback? onJumpToday;
  final VoidCallback? onPrevWeek;
  final VoidCallback? onNextWeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Column(
        children: [
          Row(
            children: [
              if (onPrevWeek != null)
                IconButton(
                  tooltip: '上一周',
                  onPressed: onPrevWeek,
                  icon: const Icon(AppIcons.chevronLeft, size: 20),
                  color: TtStyle.accent,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              Expanded(
                child: Text(
                  rangeLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TtStyle.title,
                  ),
                ),
              ),
              if (onNextWeek != null)
                IconButton(
                  tooltip: '下一周',
                  onPressed: onNextWeek,
                  icon: const Icon(AppIcons.chevronRight, size: 20),
                  color: TtStyle.accent,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (showJumpToday && onJumpToday != null)
            TextButton(
              onPressed: onJumpToday,
              style: TextButton.styleFrom(
                foregroundColor: TtStyle.accent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                minimumSize: const Size(44, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('回到今天', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
