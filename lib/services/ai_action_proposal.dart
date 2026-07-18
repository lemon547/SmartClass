import 'dart:convert';

import 'package:smart_class/models/models.dart';

/// AI 提议写入：仅草稿，确认前不落库。
sealed class AiActionProposal {
  const AiActionProposal();

  String get type;
  String get confirmButtonLabel;
  String get resultNoun;
  String get previewSummary;

  Map<String, dynamic> toJson();

  static AiActionProposal? fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString().trim();
    final items = json['items'];
    if (items is! List || items.isEmpty) return null;

    if (type == 'todo_draft') {
      final titles = <String>[];
      for (final e in items) {
        if (e is Map) {
          final t = (e['title'] ?? '').toString().trim();
          if (t.isNotEmpty) titles.add(t);
        } else {
          final t = e.toString().trim();
          if (t.isNotEmpty) titles.add(t);
        }
      }
      if (titles.isEmpty) return null;
      return AiTodoDraftProposal(titles: titles);
    }

    if (type == 'point_preset_draft') {
      final presets = <PointReasonPreset>[];
      for (final e in items) {
        if (e is! Map) continue;
        final reason = (e['reason'] ?? '').toString().trim();
        final delta = _asInt(e['delta']);
        if (reason.isEmpty || delta == null || delta == 0) continue;
        presets.add(PointReasonPreset(reason: reason, delta: delta));
      }
      if (presets.isEmpty) return null;
      return AiPointPresetDraftProposal(presets: presets);
    }
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString().trim());
  }
}

final class AiTodoDraftProposal extends AiActionProposal {
  const AiTodoDraftProposal({required this.titles});

  final List<String> titles;

  @override
  String get type => 'todo_draft';

  @override
  String get confirmButtonLabel => '审阅待办草稿';

  @override
  String get resultNoun => '待办';

  @override
  String get previewSummary {
    final n = titles.length;
    return '草稿 · $n 条待办待确认';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'items': [
          for (final t in titles) {'title': t},
        ],
      };
}

final class AiPointPresetDraftProposal extends AiActionProposal {
  const AiPointPresetDraftProposal({required this.presets});

  final List<PointReasonPreset> presets;

  @override
  String get type => 'point_preset_draft';

  @override
  String get confirmButtonLabel => '审阅积分规则';

  @override
  String get resultNoun => '积分规则';

  @override
  String get previewSummary {
    final n = presets.length;
    return '草稿 · $n 条规则待确认';
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'items': [
          for (final p in presets) {'reason': p.reason, 'delta': p.delta},
        ],
      };
}

/// 从 AI 回复中拆出展示正文 + 可选提案（提案不自动写库）。
class ParsedAiReply {
  const ParsedAiReply({required this.displayText, this.proposal});

  final String displayText;
  final AiActionProposal? proposal;

  static ParsedAiReply parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const ParsedAiReply(displayText: '');
    }

    // 优先：<<<ACTION ... ACTION>>>
    final fenced = RegExp(
      r'<<<ACTION\s*([\s\S]*?)\s*ACTION>>>',
      caseSensitive: false,
    ).firstMatch(text);
    if (fenced != null) {
      final proposal = _tryParseObject(fenced.group(1) ?? '');
      final display = text.replaceRange(fenced.start, fenced.end, '').trim();
      return ParsedAiReply(
        displayText: display.isEmpty ? '已拟好草稿，请确认后再写入。' : display,
        proposal: proposal,
      );
    }

    // 其次：文末 JSON 对象（含 type + items）
    final start = text.lastIndexOf('{');
    if (start >= 0) {
      final end = text.lastIndexOf('}');
      if (end > start) {
        final chunk = text.substring(start, end + 1);
        final proposal = _tryParseObject(chunk);
        if (proposal != null) {
          final display = text.substring(0, start).trim();
          return ParsedAiReply(
            displayText:
                display.isEmpty ? '已拟好草稿，请确认后再写入。' : display,
            proposal: proposal,
          );
        }
      }
    }

    return ParsedAiReply(displayText: text);
  }

  static AiActionProposal? _tryParseObject(String raw) {
    try {
      var t = raw.trim();
      if (t.startsWith('```')) {
        t = t.replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
        t = t.replaceFirst(RegExp(r'\s*```$'), '');
      }
      final decoded = jsonDecode(t);
      if (decoded is! Map) return null;
      return AiActionProposal.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
