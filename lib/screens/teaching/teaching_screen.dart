import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/teacher_timetable_screen.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 教学 Tab：标题 + 课表（我的课表 / 班级课表）
class TeachingScreen extends StatelessWidget {
  const TeachingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: const SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                '教学',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Expanded(
              child: TeacherTimetableScreen(
                embedded: true,
                initialTab: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
