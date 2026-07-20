import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    mode = AppThemeMode.fromStorage(_prefs.getString(_key));
    AppTheme.mode = mode;
  }

  static const _key = 'app_theme_mode';

  final SharedPreferences _prefs;
  AppThemeMode mode = AppThemeMode.day;

  String get fabMascotAsset => MascotAssets.fab;

  FabMascotOption get fabMascotOption => MascotAssets.assistant;

  Future<void> setMode(AppThemeMode next) async {
    if (mode == next) return;
    mode = next;
    AppTheme.mode = next;
    await _prefs.setString(_key, next.storageKey);
    notifyListeners();
  }
}
