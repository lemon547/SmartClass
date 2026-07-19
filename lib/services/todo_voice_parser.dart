import 'dart:convert';

import 'package:smart_class/providers/ai_settings_controller.dart';

/// 语音/口语待办 → 干净标题（本地规则 + 可选 AI）
class TodoVoiceParser {
  TodoVoiceParser._();

  /// 去掉「提醒我」「帮我记一下」等口语前缀，保留核心动作。
  static String localClean(String raw) {
    var t = raw.trim();
    if (t.isEmpty) return t;

    const prefixes = [
      '提醒我',
      '帮我提醒',
      '帮我记一下',
      '帮我记',
      '记一下',
      '记得',
      '请帮我',
      '麻烦',
      '我想',
      '我要',
    ];
    for (final p in prefixes) {
      if (t.startsWith(p)) {
        t = t.substring(p.length).trim();
        break;
      }
    }
    // 「下午通知家长…」→ 保留动作，时间挂到末尾
    final timeHint = _extractTimeHint(t);
    if (timeHint != null) {
      t = t.replaceFirst(timeHint.$1, '').trim();
      if (t.isEmpty) t = raw.trim();
      if (!t.contains(timeHint.$2)) {
        t = '$t · ${timeHint.$2}';
      }
    }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 返回 (原文片段, 规范化时间标签)
  static (String, String)? _extractTimeHint(String t) {
    const patterns = <(String, String)>[
      ('今天下午', '今天下午'),
      ('今天上午', '今天上午'),
      ('今天晚上', '今天晚上'),
      ('明天下午', '明天下午'),
      ('明天上午', '明天上午'),
      ('明天晚上', '明天晚上'),
      ('后天', '后天'),
      ('下午', '今天下午'),
      ('上午', '今天上午'),
      ('晚上', '今天晚上'),
      ('明天', '明天'),
    ];
    for (final p in patterns) {
      if (t.contains(p.$1)) return p;
    }
    return null;
  }

  /// 有 API Key 时用 AI 整理；失败则回退本地规则。
  static Future<String> polish(
    String raw, {
    AiSettingsController? aiSettings,
  }) async {
    final local = localClean(raw);
    if (raw.trim().isEmpty) return '';
    if (aiSettings == null || !aiSettings.hasApiKey) return local;

    try {
      final ai = aiSettings.createService(maxTokens: 120);
      final reply = await ai.chat(
        system: '''你是班主任待办助手。把口语转成一条简洁待办标题。
只返回 JSON：{"title":"..."}
规则：去掉「提醒我」等废话；保留动作与对象；若有时间，用「标题 · 时间」拼在一行。
不要解释。''',
        user: raw.trim(),
        temperature: 0.2,
        jsonObject: true,
      );
      final data = jsonDecode(reply);
      if (data is Map && data['title'] is String) {
        final title = (data['title'] as String).trim();
        if (title.isNotEmpty) return title;
      }
    } catch (_) {
      // 回退本地
    }
    return local;
  }
}
