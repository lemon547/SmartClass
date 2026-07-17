import 'package:flutter/material.dart';
import 'package:smart_class/screens/classes/class_switcher_screen.dart';

/// 打开班级切换全屏页（首页、班级中心等共用）
Future<void> showClassSwitcherSheet(BuildContext context) {
  return ClassSwitcherScreen.open(context);
}
