import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/shell_screen.dart';
import 'package:smart_class/theme/app_theme.dart';

class SmartClassApp extends StatelessWidget {
  const SmartClassApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    AppTheme.mode = themeCtrl.mode;

    return MaterialApp(
      title: '班主任助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: ShellScreen(key: ValueKey(themeCtrl.mode.name)),
    );
  }
}
