import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_theme.dart';

/// AI 导入共用：源列下拉（表头 + 可选「无」）。
class AiImportColumnDropdown<T> extends StatelessWidget {
  const AiImportColumnDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.labelWidth = 72,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppTheme.secondaryLabel),
            ),
          ),
          Expanded(
            child: InputDecorator(
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  key: ValueKey<Object?>('$label-$value'),
                  value: value,
                  isExpanded: true,
                  isDense: true,
                  items: items,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 列映射卡片外壳：校验失败时红框提示。
class AiImportMappingCard extends StatelessWidget {
  const AiImportMappingCard({
    super.key,
    required this.child,
    this.needsManual = false,
    this.errors = const [],
    this.titleWhenOk = '列映射（可改）',
    this.titleWhenBad = '需要手动校正列映射',
    this.hintWhenOk = '改错列后会立即重算预览。',
  });

  final Widget child;
  final bool needsManual;
  final List<String> errors;
  final String titleWhenOk;
  final String titleWhenBad;
  final String hintWhenOk;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: needsManual
            ? Border.all(color: AppTheme.destructive.withValues(alpha: 0.35))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            needsManual ? titleWhenBad : titleWhenOk,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: needsManual ? AppTheme.destructive : AppTheme.label,
            ),
          ),
          if (needsManual && errors.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              errors.take(4).join('\n'),
              style: TextStyle(fontSize: 12, color: AppTheme.destructive),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              hintWhenOk,
              style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
