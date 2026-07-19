import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    mode = AppThemeMode.fromStorage(_prefs.getString(_key));
    AppTheme.mode = mode;
    fabMascotId = _prefs.getString(_fabKey) ?? MascotAssets.defaultFabId;
  }

  static const _key = 'app_theme_mode';
  static const _fabKey = 'ai_fab_mascot_id';

  final SharedPreferences _prefs;
  AppThemeMode mode = AppThemeMode.day;
  String fabMascotId = MascotAssets.defaultFabId;

  String get fabMascotAsset => MascotAssets.assetForId(fabMascotId);

  FabMascotOption get fabMascotOption => MascotAssets.optionById(fabMascotId);

  Future<void> setMode(AppThemeMode next) async {
    if (mode == next) return;
    mode = next;
    AppTheme.mode = next;
    await _prefs.setString(_key, next.storageKey);
    notifyListeners();
  }

  Future<void> setFabMascotId(String id) async {
    final next = MascotAssets.optionById(id).id;
    if (fabMascotId == next) return;
    fabMascotId = next;
    await _prefs.setString(_fabKey, next);
    notifyListeners();
  }
}
