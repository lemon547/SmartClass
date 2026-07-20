import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/daily/daily_screen.dart';
import 'package:smart_class/screens/home/home_screen.dart';
import 'package:smart_class/screens/more/more_screen.dart';
import 'package:smart_class/screens/teaching/teaching_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/lazy_sheep_fab.dart';

/// 底部 Tab：首页 / 教学 / 班级 / 我的
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

    final k = theme.mode.name;

    final slotPages = <Widget?>[
      _visited.contains(0) ? HomeScreen(key: ValueKey('home-$k')) : null,
      _visited.contains(1) ? TeachingScreen(key: ValueKey('teach-$k')) : null,
      _visited.contains(2) ? DailyScreen(key: ValueKey('daily-$k')) : null,
      _visited.contains(3) ? MoreScreen(key: ValueKey('more-$k')) : null,
    ];

    return Scaffold(
      body: LazySheepFabOverlay(
        child: IndexedStack(
          index: index,
          children: [
            for (var i = 0; i < slotPages.length; i++)
              slotPages[i] ?? const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() {
            _visited.add(i);
            index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(AppIcons.home),
            selectedIcon: Icon(AppIcons.homeSelected),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.teach),
            selectedIcon: Icon(AppIcons.teachSelected),
            label: '教学',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.classes),
            selectedIcon: Icon(AppIcons.classesSelected),
            label: '班级',
          ),
          NavigationDestination(
            icon: Icon(AppIcons.more),
            selectedIcon: Icon(AppIcons.moreSelected),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
