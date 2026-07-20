import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';
import 'package:smart_class/theme/app_icons.dart';

/// 日期导航：中间标题 + 左右切换；「今日」固定占位，出现时不挤动标题
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.title,
    this.showJumpToday = false,
    this.onJumpToday,
    this.onPrev,
    this.onNext,
    this.prevTooltip = '上一项',
    this.nextTooltip = '下一项',
  });

  /// 中间标题，如「7月20日 周一」或「7月20日－7月26日」
  final String title;
  final bool showJumpToday;
  final VoidCallback? onJumpToday;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final String prevTooltip;
  final String nextTooltip;

  static const _sideBtnW = 40.0;
  static const _todaySlotW = 44.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Row(
        children: [
          SizedBox(
            width: _sideBtnW,
            height: 40,
            child: onPrev == null
                ? null
                : IconButton(
                    tooltip: prevTooltip,
                    onPressed: onPrev,
                    icon: const Icon(AppIcons.chevronLeft, size: 20),
                    color: TtStyle.accent,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: TtStyle.title,
              ),
            ),
          ),
          // 固定宽度：有无「今日」都占同一格，标题位置不变
          SizedBox(
            width: _todaySlotW,
            height: 40,
            child: (showJumpToday && onJumpToday != null)
                ? TextButton(
                    onPressed: onJumpToday,
                    style: TextButton.styleFrom(
                      foregroundColor: TtStyle.accent,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(_todaySlotW, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('今日', style: TextStyle(fontSize: 13)),
                  )
                : null,
          ),
          SizedBox(
            width: _sideBtnW,
            height: 40,
            child: onNext == null
                ? null
                : IconButton(
                    tooltip: nextTooltip,
                    onPressed: onNext,
                    icon: const Icon(AppIcons.chevronRight, size: 20),
                    color: TtStyle.accent,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
          ),
        ],
      ),
    );
  }
}
