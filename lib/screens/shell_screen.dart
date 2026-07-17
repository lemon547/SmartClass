import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/attendance/attendance_screen.dart';
import 'package:smart_class/screens/home/home_screen.dart';
import 'package:smart_class/screens/more/more_screen.dart';
import 'package:smart_class/screens/points/points_screen.dart';
import 'package:smart_class/screens/students/students_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final theme = context.watch<ThemeController>();
    AppTheme.mode = theme.mode;

    if (ctrl.loading && ctrl.students.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (ctrl.error != null && ctrl.students.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.alert, color: AppTheme.destructive, size: 40),
                const SizedBox(height: 12),
                Text(ctrl.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: ctrl.load, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
    }

    // 主题切换时换 key，强制重建页面，贴纸才会出现
    final k = theme.mode.name;
    final pages = [
      HomeScreen(key: ValueKey('home-$k')),
      StudentsScreen(key: ValueKey('students-$k')),
      PointsScreen(key: ValueKey('points-$k')),
      AttendanceScreen(key: ValueKey('att-$k')),
      MoreScreen(key: ValueKey('more-$k')),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.students),
            selectedIcon: Icon(AppIcons.students),
            label: '学生',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.points),
            selectedIcon: Icon(AppIcons.points),
            label: '积分',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.attendance),
            selectedIcon: Icon(AppIcons.attendance),
            label: '考勤',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.more),
            selectedIcon: Icon(AppIcons.more),
            label: '更多',
          ),
        ],
      ),
    );
  }
}
