import 'package:flutter/material.dart';
import 'package:smart_class/screens/timetable/widgets/tt_style.dart';

/// 折叠式科目筛选：显示「科目：语文 ▼」，点击弹出底部选择
class SubjectFilter extends StatelessWidget {
  const SubjectFilter({
    super.key,
    required this.label,
    required this.current,
    required this.options,
    required this.onChanged,
    this.allowAll = true,
    this.allLabel = '全部科目',
    this.compact = false,
  });

  final String label;
  final String? current;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool allowAll;
  final String allLabel;
  /// 芯片样式：只显示「语文 ▼」，不显示「科目：」
  final bool compact;

  Future<void> _openSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TtStyle.title,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: options.length + (allowAll ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (allowAll && i == 0) {
                        return ListTile(
                          title: Text(allLabel),
                          trailing: current == null
                              ? const Icon(
                                  Icons.check,
                                  color: TtStyle.accent,
                                  size: 20,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            onChanged(null);
                          },
                        );
                      }
                      final s = options[allowAll ? i - 1 : i];
                      final selected = current == s;
                      final tint = subjectTint(s);
                      return ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: tint.$1,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: tint.$2.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        title: Text(s),
                        trailing: selected
                            ? const Icon(
                                Icons.check,
                                color: TtStyle.accent,
                                size: 20,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          onChanged(s);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = current ?? allLabel;
    if (compact) {
      return Material(
        color: TtStyle.accentSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: TtStyle.accent,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: TtStyle.accent,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSheet(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label：$display',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: TtStyle.title,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: TtStyle.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
