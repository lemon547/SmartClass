import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    required this.at,
  });

  final String role; // user | assistant
  final String text;
  final DateTime at;

  Map<String, Object?> toJson() => {
        'role': role,
        'text': text,
        'at': at.toIso8601String(),
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: (json['role'] ?? 'assistant').toString(),
      text: (json['text'] ?? '').toString(),
      at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

/// 懒羊羊聊天记录：按班级保存在本机 SharedPreferences。
abstract final class AiChatHistoryStore {
  static const _prefix = 'ai_assistant_chat_v1_';
  static const maxMessages = 200;

  static String _key(String classId) => '$_prefix$classId';

  static Future<List<AiChatMessage>> load(String classId) async {
    if (classId.isEmpty) return const [];
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(classId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final e in list)
          if (e is Map<String, dynamic>)
            AiChatMessage.fromJson(e)
          else if (e is Map)
            AiChatMessage.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(String classId, List<AiChatMessage> messages) async {
    if (classId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final trimmed = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    final encoded = jsonEncode([for (final m in trimmed) m.toJson()]);
    await prefs.setString(_key(classId), encoded);
  }

  static Future<void> clear(String classId) async {
    if (classId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(classId));
  }
}
