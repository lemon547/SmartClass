import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/services/ai_action_proposal.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// AI 草稿审阅页（行业常见：审阅 → 编辑 → 明确确认后才写入）。
class AiActionConfirmScreen extends StatefulWidget {
  const AiActionConfirmScreen({super.key, required this.proposal});

  final AiActionProposal proposal;

  /// 返回写入结果说明；取消则 null。
  static Future<String?> push(
    BuildContext context,
    AiActionProposal proposal,
  ) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AiActionConfirmScreen(proposal: proposal),
      ),
    );
  }

  @override
  State<AiActionConfirmScreen> createState() => _AiActionConfirmScreenState();
}

class _AiActionConfirmScreenState extends State<AiActionConfirmScreen> {
  late final List<_TodoRow> _todos;
  late final List<_PresetRow> _presets;
  bool _busy = false;
  String? _bannerError;

  bool get _isTodo => widget.proposal is AiTodoDraftProposal;

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    if (p is AiTodoDraftProposal) {
      _todos = [
        for (final t in p.titles) _TodoRow(TextEditingController(text: t)),
      ];
      if (_todos.isEmpty) _todos.add(_TodoRow(TextEditingController()));
      _presets = [];
    } else if (p is AiPointPresetDraftProposal) {
      _todos = [];
      _presets = [
        for (final x in p.presets)
          _PresetRow(
            reason: TextEditingController(text: x.reason),
            delta: TextEditingController(text: '${x.delta}'),
          ),
      ];
      if (_presets.isEmpty) {
        _presets.add(
          _PresetRow(
            reason: TextEditingController(),
            delta: TextEditingController(text: '1'),
          ),
        );
      }
    } else {
      _todos = [];
      _presets = [];
    }
  }

  @override
  void dispose() {
    for (final r in _todos) {
      r.dispose();
    }
    for (final r in _presets) {
      r.dispose();
    }
    super.dispose();
  }

  Set<String> get _openTodoTitles {
    final ctrl = context.read<ClassController>();
    return {
      for (final t in ctrl.todos)
        if (!t.done) t.title.trim(),
    };
  }

  Map<String, int> get _existingPresetDeltas {
    final ctrl = context.read<ClassController>();
    return {for (final p in ctrl.pointPresets) p.reason: p.delta};
  }

  void _addRow() {
    setState(() {
      if (_isTodo) {
        _todos.add(_TodoRow(TextEditingController()));
      } else {
        _presets.add(
          _PresetRow(
            reason: TextEditingController(),
            delta: TextEditingController(text: '1'),
          ),
        );
      }
    });
  }

  void _removeTodo(int i) {
    if (_todos.length <= 1) {
      _todos[i].ctrl.clear();
      setState(() {});
      return;
    }
    setState(() => _todos.removeAt(i).dispose());
  }

  void _removePreset(int i) {
    if (_presets.length <= 1) {
      _presets[i].reason.clear();
      _presets[i].delta.text = '1';
      setState(() {});
      return;
    }
    setState(() => _presets.removeAt(i).dispose());
  }

  Future<void> _confirm() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _bannerError = null;
      for (final r in _todos) {
        r.error = null;
      }
      for (final r in _presets) {
        r.error = null;
      }
    });

    try {
      final ctrl = context.read<ClassController>();
      if (_isTodo) {
        var hasError = false;
        final titles = <String>[];
        final seen = <String>{};
        for (final row in _todos) {
          final t = row.ctrl.text.trim();
          if (t.isEmpty) continue;
          if (!seen.add(t)) {
            row.error = '与列表内其他项重复';
            hasError = true;
            continue;
          }
          titles.add(t);
        }
        if (hasError) {
          setState(() {});
          return;
        }
        if (titles.isEmpty) {
          setState(() => _bannerError = '请至少填写一条待办');
          return;
        }
        final r = await ctrl.addTodos(titles);
        if (!mounted) return;
        final msg = StringBuffer('已写入待办 ${r.added} 条');
        if (r.skipped > 0) {
          msg.write('，跳过 ${r.skipped} 条（空项或已有同名未完成）');
        }
        Navigator.pop(context, msg.toString());
        return;
      }

      var hasError = false;
      final out = <PointReasonPreset>[];
      final seen = <String>{};
      for (final row in _presets) {
        final reason = row.reason.text.trim();
        final deltaRaw = row.delta.text.trim();
        if (reason.isEmpty && deltaRaw.isEmpty) continue;
        if (reason.isEmpty) {
          row.error = '请填写理由';
          hasError = true;
          continue;
        }
        final delta = int.tryParse(deltaRaw);
        if (delta == null) {
          row.error = '分值须为整数';
          hasError = true;
          continue;
        }
        if (delta == 0) {
          row.error = '分值不能为 0';
          hasError = true;
          continue;
        }
        if (!seen.add(reason)) {
          row.error = '与列表内其他理由重复';
          hasError = true;
          continue;
        }
        out.add(PointReasonPreset(reason: reason, delta: delta));
      }
      if (hasError) {
        setState(() {});
        return;
      }
      if (out.isEmpty) {
        setState(() => _bannerError = '请至少填写一条有效规则');
        return;
      }

      final r = await ctrl.mergePointPresets(out);
      if (!mounted) return;
      final msg = StringBuffer('已更新积分规则：新增 ${r.added}');
      if (r.updated > 0) msg.write('，覆盖 ${r.updated}');
      if (r.skipped > 0) msg.write('，跳过 ${r.skipped}');
      Navigator.pop(context, msg.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _bannerError = '写入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openTitles = _isTodo ? _openTodoTitles : const <String>{};
    final existing = _isTodo ? const <String, int>{} : _existingPresetDeltas;
    final filledCount = _isTodo
        ? _todos.where((r) => r.ctrl.text.trim().isNotEmpty).length
        : _presets
            .where((r) => r.reason.text.trim().isNotEmpty)
            .length;
    final overwriteCount = _isTodo
        ? 0
        : _presets.where((r) {
            final reason = r.reason.text.trim();
            return reason.isNotEmpty && existing.containsKey(reason);
          }).length;
    final skipHintCount = _isTodo
        ? _todos
            .where((r) => openTitles.contains(r.ctrl.text.trim()))
            .length
        : 0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: PageAppBar(
        title: Text(_isTodo ? '审阅待办草稿' : '审阅积分规则'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _SummaryCard(
                  isTodo: _isTodo,
                  count: filledCount,
                  overwriteCount: overwriteCount,
                  skipHintCount: skipHintCount,
                ),
                const SizedBox(height: 16),
                Text(
                  _isTodo ? '待办列表' : '规则列表',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isTodo)
                  for (var i = 0; i < _todos.length; i++)
                    _TodoEditor(
                      index: i,
                      row: _todos[i],
                      willSkip: openTitles.contains(_todos[i].ctrl.text.trim()),
                      enabled: !_busy,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removeTodo(i),
                    )
                else
                  for (var i = 0; i < _presets.length; i++)
                    _PresetEditor(
                      index: i,
                      row: _presets[i],
                      previousDelta:
                          existing[_presets[i].reason.text.trim()],
                      enabled: !_busy,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removePreset(i),
                    ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _busy ? null : _addRow,
                  icon: const Icon(AppIcons.plus, size: 18),
                  label: Text(_isTodo ? '添加一项' : '添加规则'),
                ),
                if (_bannerError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _bannerError!,
                    style: TextStyle(
                      color: AppTheme.destructive,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _BottomBar(
            busy: _busy,
            confirmEnabled: filledCount > 0 && !_busy,
            onCancel: _busy ? null : () => Navigator.pop(context),
            onConfirm: _busy ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

class _TodoRow {
  _TodoRow(this.ctrl);
  final TextEditingController ctrl;
  String? error;

  void dispose() => ctrl.dispose();
}

class _PresetRow {
  _PresetRow({required this.reason, required this.delta});
  final TextEditingController reason;
  final TextEditingController delta;
  String? error;

  void dispose() {
    reason.dispose();
    delta.dispose();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.isTodo,
    required this.count,
    required this.overwriteCount,
    required this.skipHintCount,
  });

  final bool isTodo;
  final int count;
  final int overwriteCount;
  final int skipHintCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTodo ? '写入前请确认' : '仅更新快捷规则，不改学生分数',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            isTodo
                ? '将尝试写入 $count 条待办。确认前不会保存。'
                : '将合并 $count 条规则到本班快捷加减分。确认前不会保存。',
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppTheme.secondaryLabel,
            ),
          ),
          if (skipHintCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '其中 $skipHintCount 条与未完成待办同名，写入时会自动跳过。',
              style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
            ),
          ],
          if (overwriteCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '其中 $overwriteCount 条理由已存在，确认后将覆盖原分值。',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB85C1A)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodoEditor extends StatelessWidget {
  const _TodoEditor({
    required this.index,
    required this.row,
    required this.willSkip,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _TodoRow row;
  final bool willSkip;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: row.error != null
              ? Border.all(color: AppTheme.destructive.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IndexBadge(index: index + 1),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.ctrl,
                    enabled: enabled,
                    onChanged: (_) => onChanged(),
                    decoration: const InputDecoration(
                      hintText: '待办内容',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  onPressed: enabled ? onRemove : null,
                  icon: Icon(AppIcons.trash, color: AppTheme.tertiaryLabel),
                  tooltip: '移除',
                ),
              ],
            ),
            if (willSkip)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 2),
                child: Text(
                  '已有同名未完成待办 · 将跳过',
                  style: TextStyle(fontSize: 12, color: AppTheme.tertiaryLabel),
                ),
              ),
            if (row.error != null)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 2),
                child: Text(
                  row.error!,
                  style: TextStyle(fontSize: 12, color: AppTheme.destructive),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetEditor extends StatelessWidget {
  const _PresetEditor({
    required this.index,
    required this.row,
    required this.previousDelta,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _PresetRow row;
  final int? previousDelta;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: row.error != null
              ? Border.all(color: AppTheme.destructive.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _IndexBadge(index: index + 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: row.reason,
                        enabled: enabled,
                        onChanged: (_) => onChanged(),
                        decoration: const InputDecoration(
                          labelText: '理由',
                          hintText: '如：迟到、发言积极',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                      TextField(
                        controller: row.delta,
                        enabled: enabled,
                        onChanged: (_) => onChanged(),
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                        ],
                        decoration: const InputDecoration(
                          labelText: '分值',
                          hintText: '正数为加分，负数为扣分',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: enabled ? onRemove : null,
                  icon: Icon(AppIcons.trash, color: AppTheme.tertiaryLabel),
                  tooltip: '移除',
                ),
              ],
            ),
            if (previousDelta != null)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 2),
                child: Text(
                  '将覆盖现有规则（当前 ${previousDelta! > 0 ? '+' : ''}$previousDelta）',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB85C1A),
                  ),
                ),
              ),
            if (row.error != null)
              Padding(
                padding: const EdgeInsets.only(left: 34, top: 2),
                child: Text(
                  row.error!,
                  style: TextStyle(fontSize: 12, color: AppTheme.destructive),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.separator.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$index',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryLabel,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.busy,
    required this.confirmEnabled,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool busy;
  final bool confirmEnabled;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: confirmEnabled ? onConfirm : null,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('确认写入'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
