import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 周次范围 + 次要操作（调整课表）
class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader({
    super.key,
    required this.rangeLabel,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String rangeLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Text(
            rangeLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TtStyle.title,
            ),
          ),
          const Spacer(),
          if (secondaryLabel != null && onSecondary != null)
            TextButton(
              onPressed: onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: TtStyle.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(44, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                secondaryLabel!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}
