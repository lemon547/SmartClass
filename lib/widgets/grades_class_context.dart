import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

/// 成绩模块唯一班级入口：一行文案，点按切换（不重复塞进分组标题）
class GradesClassContext extends StatelessWidget {
  const GradesClassContext({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final title = ctrl.currentClass?.displayTitle ?? ctrl.profile.displayTitle;
    final n = ctrl.students.length;

    return InkWell(
      onTap: () => showClassSwitcherSheet(context),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                compact ? title : '$title · $n 人',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: AppTheme.tertiaryLabel,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              AppIcons.chevronRight,
              size: 14,
              color: AppTheme.quaternaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}
