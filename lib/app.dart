import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/app_info.dart';
import 'package:smart_class/providers/theme_controller.dart';
import 'package:smart_class/screens/splash_screen.dart';
import 'package:smart_class/theme/app_theme.dart';

class SmartClassApp extends StatelessWidget {
  const SmartClassApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    AppTheme.mode = themeCtrl.mode;

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemOverlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashGate(),
    );
  }
}
