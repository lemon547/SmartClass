import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/features/class_features.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/home/home_screen.dart';
import 'package:smart_class/screens/more/more_screen.dart';
import 'package:smart_class/screens/points/points_screen.dart';
import 'package:smart_class/screens/students/students_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

/// 底部 Tab：首页 / 学生 /（积分）/ 我的；积分随本班功能显隐
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int index = 0;
  final _visited = <int>{0};

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final theme = context.watch<ThemeController>();
    AppTheme.mode = theme.mode;

    if (!ctrl.essentialReady && ctrl.students.isEmpty && ctrl.error == null) {
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

    final showPoints = ctrl.isFeatureVisible(ClassFeatureIds.points);
    final k = theme.mode.name;

    // logical slots: 0 home, 1 students, 2 points (optional), 3 more
    final slotPages = <Widget?>[
      _visited.contains(0) ? HomeScreen(key: ValueKey('home-$k')) : null,
      _visited.contains(1)
          ? StudentsScreen(key: ValueKey('students-$k'))
          : null,
      showPoints && _visited.contains(2)
          ? PointsScreen(key: ValueKey('points-$k'))
          : null,
      _visited.contains(3) ? MoreScreen(key: ValueKey('more-$k')) : null,
    ];

    final visibleSlots = <int>[
      0,
      1,
      if (showPoints) 2,
      3,
    ];

    // Map bar index -> slot
    var barIndex = visibleSlots.indexOf(index);
    if (barIndex < 0) {
      index = 0;
      barIndex = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < slotPages.length; i++)
            slotPages[i] ?? const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: barIndex,
        onDestinationSelected: (i) {
          final slot = visibleSlots[i];
          setState(() {
            _visited.add(slot);
            index = slot;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.home),
            label: '首页',
          ),
          const NavigationDestination(
            icon: Icon(AppIcons.students),
            selectedIcon: Icon(AppIcons.students),
            label: '学生',
          ),
          if (showPoints)
            const NavigationDestination(
              icon: Icon(AppIcons.points),
              selectedIcon: Icon(AppIcons.points),
              label: '积分',
            ),
          const NavigationDestination(
            icon: Icon(AppIcons.more),
            selectedIcon: Icon(AppIcons.more),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
