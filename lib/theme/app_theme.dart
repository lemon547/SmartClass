import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主题模式。
///
/// 白天 / 夜间 / 护眼：改色板。
/// 懒羊羊：不改全局配色（与白天相同），只开启立绘贴纸皮肤。
enum AppThemeMode {
  day,
  night,
  eyeCare,
  paddi;

  String get label => switch (this) {
        AppThemeMode.day => '白天模式',
        AppThemeMode.night => '夜间模式',
        AppThemeMode.eyeCare => '护眼模式',
        AppThemeMode.paddi => '懒羊羊皮肤',
      };

  String get hint => switch (this) {
        AppThemeMode.day => '清爽浅色',
        AppThemeMode.night => '深色护眼',
        AppThemeMode.eyeCare => '绿豆沙背景',
        AppThemeMode.paddi => '少量贴纸点缀，图标与配色照常',
      };

  static AppThemeMode fromStorage(String? raw) => switch (raw) {
        'night' => AppThemeMode.night,
        'eyeCare' => AppThemeMode.eyeCare,
        'paddi' => AppThemeMode.paddi,
        _ => AppThemeMode.day,
      };

  String get storageKey => name;
}

/// 色板随 [mode] 切换。懒羊羊模式复用白天色，避免整页变黄变丑。
class AppTheme {
  static AppThemeMode mode = AppThemeMode.day;

  /// 是否展示懒羊羊立绘贴纸（素材皮肤，不是换色）
  static bool get showMascot => mode == AppThemeMode.paddi;

  /// 配色用的有效模式：懒羊羊 → 白天
  static AppThemeMode get _palette =>
      mode == AppThemeMode.paddi ? AppThemeMode.day : mode;

  static bool get isDark => _palette == AppThemeMode.night;

  static Color get bg => switch (_palette) {
        AppThemeMode.day => const Color(0xFFF2F2F7),
        AppThemeMode.night => const Color(0xFF000000),
        AppThemeMode.eyeCare => const Color(0xFFC7EDCC),
        AppThemeMode.paddi => const Color(0xFFF2F2F7),
      };

  static Color get surface => switch (_palette) {
        AppThemeMode.day => const Color(0xFFFFFFFF),
        AppThemeMode.night => const Color(0xFF1C1C1E),
        AppThemeMode.eyeCare => const Color(0xFFE8F5E9),
        AppThemeMode.paddi => const Color(0xFFFFFFFF),
      };

  static Color get navBar => switch (_palette) {
        AppThemeMode.day => const Color(0xF9F9F9F9),
        AppThemeMode.night => const Color(0xF91C1C1E),
        AppThemeMode.eyeCare => const Color(0xF9C7EDCC),
        AppThemeMode.paddi => const Color(0xF9F9F9F9),
      };

  static Color get label => switch (_palette) {
        AppThemeMode.day => const Color(0xFF000000),
        AppThemeMode.night => const Color(0xFFFFFFFF),
        AppThemeMode.eyeCare => const Color(0xFF1B3A22),
        AppThemeMode.paddi => const Color(0xFF000000),
      };

  static Color get secondaryLabel => switch (_palette) {
        AppThemeMode.day => const Color(0xFF3C3C43),
        AppThemeMode.night => const Color(0xFFEBEBF5),
        AppThemeMode.eyeCare => const Color(0xFF2E5A38),
        AppThemeMode.paddi => const Color(0xFF3C3C43),
      };

  static Color get tertiaryLabel => switch (_palette) {
        AppThemeMode.day => const Color(0x993C3C43),
        AppThemeMode.night => const Color(0x99EBEBF5),
        AppThemeMode.eyeCare => const Color(0x992E5A38),
        AppThemeMode.paddi => const Color(0x993C3C43),
      };

  static Color get quaternaryLabel => switch (_palette) {
        AppThemeMode.day => const Color(0x2E3C3C43),
        AppThemeMode.night => const Color(0x2EEBEBF5),
        AppThemeMode.eyeCare => const Color(0x2E2E5A38),
        AppThemeMode.paddi => const Color(0x2E3C3C43),
      };

  static Color get separator => switch (_palette) {
        AppThemeMode.day => const Color(0x5C3C3C43),
        AppThemeMode.night => const Color(0x5C545458),
        AppThemeMode.eyeCare => const Color(0x5C6B9B72),
        AppThemeMode.paddi => const Color(0x5C3C3C43),
      };

  static Color get fill => switch (_palette) {
        AppThemeMode.day => const Color(0x14747480),
        AppThemeMode.night => const Color(0x29787880),
        AppThemeMode.eyeCare => const Color(0x146B9B72),
        AppThemeMode.paddi => const Color(0x14747480),
      };

  static Color get blue => switch (_palette) {
        AppThemeMode.day => const Color(0xFF007AFF),
        AppThemeMode.night => const Color(0xFF0A84FF),
        AppThemeMode.eyeCare => const Color(0xFF2E7D4F),
        AppThemeMode.paddi => const Color(0xFF007AFF),
      };

  static Color get onAccent => Colors.white;

  static Color get destructive => switch (_palette) {
        AppThemeMode.day => const Color(0xFFFF3B30),
        AppThemeMode.night => const Color(0xFFFF453A),
        AppThemeMode.eyeCare => const Color(0xFFB54A3C),
        AppThemeMode.paddi => const Color(0xFFFF3B30),
      };

  /// 状态栏 / 导航栏与页面背景一致（透明状态栏 + 深色/浅色图标）
  static SystemUiOverlayStyle get systemOverlayStyle {
    final dark = isDark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: navBar,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    );
  }

  static ThemeData get theme {
    final dark = isDark;
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: blue,
      onPrimary: onAccent,
      secondary: secondaryLabel,
      onSecondary: dark ? Colors.black : Colors.white,
      surface: surface,
      onSurface: label,
      error: destructive,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: fill,
      dividerColor: separator,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: bg,
        foregroundColor: label,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayStyle,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: label,
          letterSpacing: -0.41,
        ),
        iconTheme: IconThemeData(color: blue, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: onAccent,
          elevation: 0,
          minimumSize: const Size.fromHeight(50),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        // iOS 风格：无描边、标签不浮到边框上（避免蓝框「选中」丑样式）
        floatingLabelBehavior: FloatingLabelBehavior.never,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: tertiaryLabel, fontSize: 17),
        labelStyle: TextStyle(color: tertiaryLabel, fontSize: 17),
        floatingLabelStyle: TextStyle(color: tertiaryLabel, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: destructive, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: destructive, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fill,
        selectedColor: blue.withValues(alpha: 0.22),
        labelStyle: TextStyle(fontSize: 14, color: label),
        secondaryLabelStyle: TextStyle(color: blue),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        backgroundColor: navBar,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: selected ? blue : tertiaryLabel,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? blue : tertiaryLabel,
          );
        }),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: label,
          letterSpacing: 0.37,
          height: 1.12,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: label,
          letterSpacing: -0.45,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: label,
          letterSpacing: -0.41,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: label,
          letterSpacing: -0.41,
          height: 1.29,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: label,
          letterSpacing: -0.24,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: tertiaryLabel,
          letterSpacing: -0.08,
        ),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: tertiaryLabel,
          letterSpacing: -0.08,
        ),
      ),
    );
  }

  static ThemeData get light => theme;
}
