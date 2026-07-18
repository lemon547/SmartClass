import 'package:smart_class/services/deepseek_ai_service.dart';
import 'package:smart_class/services/excel_grid.dart';

/// 表格网格只读辅助：样例、表头、列快照（三套 AI 导入共用）。
abstract final class AiImportGridHelpers {
  static List<String> columnSamples(
    ExcelGrid grid,
    int headerRowIndex,
    int column, {
    int limit = 12,
    bool Function(String value)? skip,
  }) {
    final out = <String>[];
    for (var r = headerRowIndex + 1;
        r < grid.rows.length && out.length < limit;
        r++) {
      final line = grid.rows[r];
      if (column < 0 || column >= line.length) continue;
      final v = line[column].trim();
      if (v.isEmpty) continue;
      if (skip != null && skip(v)) continue;
      out.add(v);
    }
    return out;
  }

  static List<String> headerLabels(ExcelGrid grid, int headerRowIndex) {
    if (headerRowIndex < 0 || headerRowIndex >= grid.rows.length) {
      return List.generate(grid.colCount, (i) => '列 $i');
    }
    final row = grid.rows[headerRowIndex];
    return List.generate(grid.colCount, (i) {
      final h = i < row.length ? row[i].trim() : '';
      return h.isEmpty ? '列 $i' : '列 $i · $h';
    });
  }

  static String headerCell(ExcelGrid grid, int headerRowIndex, int column) {
    if (headerRowIndex < 0 || headerRowIndex >= grid.rows.length) return '';
    final row = grid.rows[headerRowIndex];
    if (column < 0 || column >= row.length) return '';
    return row[column].trim();
  }

  static bool columnInRange(ExcelGrid grid, int? column) {
    if (column == null) return true;
    return column >= 0 && column < grid.colCount;
  }

  static String headerDump(
    ExcelGrid grid,
    int headerRowIndex, {
    int maxCols = 20,
    int sampleLimit = 3,
  }) {
    final width = grid.colCount;
    final buf = StringBuffer();
    for (var c = 0; c < width && c < maxCols; c++) {
      final samples = columnSamples(
        grid,
        headerRowIndex,
        c,
        limit: sampleLimit,
      );
      buf.writeln(
        '列$c「${headerCell(grid, headerRowIndex, c)}」'
        '样例=${samples.join('/')}',
      );
    }
    return buf.toString().trimRight();
  }

  /// 姓名列低多样性：几乎全相同 → 典型指错列（不写死业务词表）。
  static bool isLowDiversityNameColumn(List<String> samples) {
    if (samples.length < 4) return false;
    return samples.toSet().length == 1;
  }
}

/// Map → Validate → Repair（封顶）→ Escalate 的通用结果。
class AiMappingRepairResult<T> {
  const AiMappingRepairResult({
    required this.mapping,
    required this.mappingOk,
    required this.validationErrors,
    required this.warnings,
    required this.attempts,
  });

  final T mapping;
  final bool mappingOk;
  final List<String> validationErrors;
  final List<String> warnings;
  final int attempts;
}

/// 规范流水线核心：LLM 出映射 → 确定性校验 → 带历史纠错 → 封顶升级人工。
abstract final class AiMappingRepairLoop {
  static const defaultMaxAttempts = 3;

  static Future<AiMappingRepairResult<T>> run<T>({
    required DeepSeekAiService ai,
    required List<Map<String, String>> seedMessages,
    required T Function(Map<String, dynamic> json) parseMapping,
    required List<String> Function(T mapping) validate,
    required T fallbackMapping,
    required String jsonLabel,
    required String requiredFieldsHint,
    String Function(T mapping, List<String> errors)? repairUserMessage,
    int maxAttempts = defaultMaxAttempts,
  }) async {
    final messages = [...seedMessages];
    T? lastMapping;
    var lastErrors = <String>['尚未完成识别'];
    final warnings = <String>[];
    var attempts = 0;

    for (var i = 0; i < maxAttempts; i++) {
      attempts = i + 1;
      final raw = await ai.chatMessages(
        messages: messages,
        temperature: 0.1,
        jsonObject: true,
      );
      messages.add({'role': 'assistant', 'content': raw});

      Map<String, dynamic> json;
      try {
        json = ai.decodeJsonObjectMap(raw, label: jsonLabel);
      } catch (e) {
        lastErrors = ['JSON 无法解析：$e'];
        messages.add({
          'role': 'user',
          'content':
              '校验失败：返回内容不是合法 json 对象。请只输出一个完整 json，字段需含 $requiredFieldsHint。',
        });
        continue;
      }

      final mapping = parseMapping(json);
      lastMapping = mapping;
      final errors = validate(mapping);
      lastErrors = errors;
      if (errors.isEmpty) {
        if (i > 0) {
          warnings.add('AI 已根据校验反馈修正列映射（第 ${i + 1} 次）');
        }
        return AiMappingRepairResult(
          mapping: mapping,
          mappingOk: true,
          validationErrors: const [],
          warnings: warnings,
          attempts: attempts,
        );
      }

      if (i < maxAttempts - 1) {
        final body = repairUserMessage?.call(mapping, errors) ??
            '语义校验失败，请对照原始 TSV 整份重做并输出完整 json：\n'
                '${errors.map((e) => '- $e').join('\n')}';
        messages.add({'role': 'user', 'content': body});
      }
    }

    warnings.add(
      'AI 列映射经 $attempts 次仍未通过校验，请手动校正列映射后再确认导入。',
    );
    return AiMappingRepairResult(
      mapping: lastMapping ?? fallbackMapping,
      mappingOk: false,
      validationErrors: lastErrors,
      warnings: warnings,
      attempts: attempts,
    );
  }
}
