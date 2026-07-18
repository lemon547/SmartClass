import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_class/services/deepseek_ai_service.dart';

/// AI 体验档位：在约 ¥100/月预算内尽量好用、少浪费。
enum AiExperiencePlan {
  /// 推荐：Flash + 默认关思考 + 智能带班级数据
  experience100,

  /// 省钱：始终短答、不思考
  saver,

  /// 满血：Pro + 可开思考（费得多）
  fullPower,
}

class AiSettingsController extends ChangeNotifier {
  AiSettingsController(this._prefs) {
    _apiKey = _prefs.getString(_keyApi) ?? '';
    _model = _prefs.getString(_keyModel) ?? DeepSeekAiService.modelFlash;
    _thinkingEnabled = _prefs.getBool(_keyThinking) ?? false;
    _deepAnalyze = _prefs.getBool(_keyDeep) ?? false;
    final planName = _prefs.getString(_keyPlan);
    _plan = AiExperiencePlan.values.firstWhere(
      (e) => e.name == planName,
      orElse: () => AiExperiencePlan.experience100,
    );
    _seedFromLocalIfNeeded();
    _ensureRecommendedDefaults();
  }

  static const _keyApi = 'deepseek_api_key';
  static const _keyModel = 'deepseek_model';
  static const _keyThinking = 'deepseek_thinking';
  static const _keyDeep = 'deepseek_deep_analyze';
  static const _keyPlan = 'deepseek_experience_plan';

  final SharedPreferences _prefs;

  String _apiKey = '';
  String _model = DeepSeekAiService.modelFlash;
  bool _thinkingEnabled = false;
  bool _deepAnalyze = false;
  AiExperiencePlan _plan = AiExperiencePlan.experience100;

  String get apiKey => _apiKey;
  String get model => _model;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  bool get thinkingEnabled => _thinkingEnabled;
  bool get deepAnalyze => _deepAnalyze;
  AiExperiencePlan get plan => _plan;

  /// 设置页展示用：sk-****尾部
  String get maskedApiKey {
    final k = _apiKey.trim();
    if (k.length < 12) return k.isEmpty ? '未配置' : '已配置';
    return '${k.substring(0, 6)}…${k.substring(k.length - 4)}';
  }

  String get planTitle => switch (_plan) {
        AiExperiencePlan.experience100 => '体验优先（约¥100/月）',
        AiExperiencePlan.saver => '尽量省钱',
        AiExperiencePlan.fullPower => '满血优先',
      };

  String get planSubtitle => switch (_plan) {
        AiExperiencePlan.experience100 =>
          '日常 Flash 又快又省；聊天里点「深度」才用满血 Pro。问本班才带数据。',
        AiExperiencePlan.saver => '更短回答、不思考；适合偶尔问问。',
        AiExperiencePlan.fullPower => '始终 Pro，可开思考；更聪明但更费余额。',
      };

  /// 设置页一句人话说明当前会怎么扣费。
  String get runtimeHint {
    final deep = _deepAnalyze;
    return switch (_plan) {
      AiExperiencePlan.experience100 => deep
          ? '本轮：满血 Pro + 思考（较费，答完建议关掉）'
          : '本轮：Flash 快答 · 约¥100/月很宽裕',
      AiExperiencePlan.saver => '本轮：最省模式',
      AiExperiencePlan.fullPower => deep
          ? '本轮：Pro + 思考'
          : '本轮：Pro（思考关）',
    };
  }

  /// 按档位选模型：体验优先日常 Flash；点「深度」才临时上 Pro+思考。
  DeepSeekAiService createService({
    bool? forceThinking,
    int? maxTokens,
  }) {
    final deep = forceThinking ?? (_thinkingEnabled || _deepAnalyze);
    final String model;
    final bool think;
    final int tokens;
    switch (_plan) {
      case AiExperiencePlan.experience100:
        // 预算内最好体验：平时快又省；深度分析才动用满血额度
        model = deep
            ? DeepSeekAiService.modelPro
            : DeepSeekAiService.modelFlash;
        think = deep;
        tokens = deep ? 1400 : 900;
      case AiExperiencePlan.saver:
        model = DeepSeekAiService.modelFlash;
        think = false;
        tokens = 600;
      case AiExperiencePlan.fullPower:
        model = DeepSeekAiService.modelPro;
        think = deep || _thinkingEnabled;
        tokens = 1600;
    }
    return DeepSeekAiService(
      apiKey: _apiKey,
      model: model,
      thinkingEnabled: think,
      maxTokens: maxTokens ?? tokens,
    );
  }

  Future<void> setApiKey(String value) async {
    _apiKey = value.trim();
    await _prefs.setString(_keyApi, _apiKey);
    notifyListeners();
  }

  Future<void> setModel(String value) async {
    final next =
        value.trim().isEmpty ? DeepSeekAiService.modelFlash : value.trim();
    if (next == _model) return;
    _model = next;
    await _prefs.setString(_keyModel, _model);
    notifyListeners();
  }

  Future<void> setThinkingEnabled(bool value) async {
    if (_thinkingEnabled == value) return;
    _thinkingEnabled = value;
    await _prefs.setBool(_keyThinking, value);
    notifyListeners();
  }

  Future<void> setDeepAnalyze(bool value) async {
    if (_deepAnalyze == value) return;
    _deepAnalyze = value;
    await _prefs.setBool(_keyDeep, value);
    notifyListeners();
  }

  /// 一键套用预算体验方案（给对象用的推荐档）。
  Future<void> applyExperiencePlan(AiExperiencePlan plan) async {
    _plan = plan;
    await _prefs.setString(_keyPlan, plan.name);
    switch (plan) {
      case AiExperiencePlan.experience100:
        _model = DeepSeekAiService.modelFlash;
        _thinkingEnabled = false;
        _deepAnalyze = false;
      case AiExperiencePlan.saver:
        _model = DeepSeekAiService.modelFlash;
        _thinkingEnabled = false;
        _deepAnalyze = false;
      case AiExperiencePlan.fullPower:
        _model = DeepSeekAiService.modelPro;
        _thinkingEnabled = true;
        _deepAnalyze = true;
    }
    await _prefs.setString(_keyModel, _model);
    await _prefs.setBool(_keyThinking, _thinkingEnabled);
    await _prefs.setBool(_keyDeep, _deepAnalyze);
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    _apiKey = '';
    await _prefs.remove(_keyApi);
    notifyListeners();
  }

  void _seedFromLocalIfNeeded() {
    if (_apiKey.trim().isNotEmpty) return;
    // 可用 --dart-define=DEEPSEEK_API_KEY=sk-… 注入；平时在「我的 → AI 助手」填写。
    // 本地文件 lib/config/local_ai_key.dart 已 gitignore，勿提交 Key。
    const fromEnv = String.fromEnvironment('DEEPSEEK_API_KEY');
    final seed = fromEnv.trim();
    if (seed.isEmpty) return;
    _apiKey = seed;
    _prefs.setString(_keyApi, seed);
  }

  /// 旧版 deepseek-chat → Flash；未设过方案时默认体验优先。
  void _ensureRecommendedDefaults() {
    final legacy = _model == 'deepseek-chat' || _model == 'deepseek-reasoner';
    if (legacy) {
      _model = DeepSeekAiService.modelFlash;
      _prefs.setString(_keyModel, _model);
    }
    if (_prefs.getString(_keyPlan) == null) {
      _plan = AiExperiencePlan.experience100;
      _prefs.setString(_keyPlan, _plan.name);
      if (!_prefs.containsKey(_keyThinking)) {
        _thinkingEnabled = false;
        _prefs.setBool(_keyThinking, false);
      }
    }
  }
}
