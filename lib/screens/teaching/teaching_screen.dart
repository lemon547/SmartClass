import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/grades/grades_screen.dart';
import 'package:smart_class/screens/seating/seating_screen.dart';
import 'package:smart_class/screens/timetable/teacher_timetable_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/class_switcher_sheet.dart';

/// 教学 Tab：教学工具入口（课表需点进，不直接铺满整页）
class TeachingScreen extends StatelessWidget {
  const TeachingScreen({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    final toolTiles = <Widget>[
      GroupedTile(
        title: '课表',
        subtitle: '我的课表与班级课表',
        leading: Icon(AppIcons.calendar, color: AppTheme.blue),
        onTap: () => _push(context, const TeacherTimetableScreen()),
      ),
      if (ctrl.isFeatureVisible(ClassFeatureIds.grades))
        GroupedTile(
          title: '成绩',
          subtitle: '考试与成绩录入',
          leading: const Icon(AppIcons.chart, color: Color(0xFFFF9500)),
          onTap: () => _push(context, const GradesScreen()),
        ),
      if (ctrl.isFeatureVisible(ClassFeatureIds.seating))
        GroupedTile(
          title: '座位表',
          subtitle: '本班座位安排',
          leading: const Icon(AppIcons.users, color: Color(0xFF34C759)),
          onTap: () => _push(context, const SeatingScreen()),
        ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const Text(
              '教学',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '课表、成绩与座位等教学工具',
              style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => showClassSwitcherSheet(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      ctrl.currentClass?.displayTitle ?? '未选班级',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.secondaryLabel,
                      ),
                    ),
                    Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: AppTheme.tertiaryLabel,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GroupedSection(
              padding: EdgeInsets.zero,
              children: toolTiles,
            ),
          ],
        ),
      ),
    );
  }
}
