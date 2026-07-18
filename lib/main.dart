import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_class/app.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/providers/ai_settings_controller.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final repository = ClassRepository();
  await repository.init();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ClassController(repository)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AiSettingsController(prefs),
        ),
      ],
      child: const SmartClassApp(),
    ),
  );
}
