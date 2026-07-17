import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 积分规则编辑器：自由增删改「什么情况加减多少分」
class PointRulesScreen extends StatelessWidget {
  const PointRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final addRules =
        ctrl.pointPresets.where((p) => p.delta >= 0).toList();
    final subRules =
        ctrl.pointPresets.where((p) => p.delta < 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分规则'),
        actions: [
          IconButton(
            tooltip: '恢复默认',
            onPressed: () => _resetDefaults(context),
            icon: const Icon(AppIcons.undo),
          ),
          IconButton(
            tooltip: '添加规则',
            onPressed: () => _editRule(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88, top: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '加分、扣分时会用到这些规则。名称和分值都可自由修改。',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppTheme.tertiaryLabel,
              ),
            ),
          ),
          GroupedSection(
            header: '加分规则 · ${addRules.length}',
            footer: '例如：课堂发言 +2、作业优秀 +3',
            children: [
              if (addRules.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('暂无加分规则',
                      style: TextStyle(color: AppTheme.tertiaryLabel)),
                )
              else
                for (final r in addRules)
                  _RuleTile(rule: r, positive: true),
              GroupedTile(
                title: '添加加分规则',
                leading: Icon(AppIcons.circlePlus, color: AppTheme.blue),
                onTap: () => _editRule(context, preferPositive: true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GroupedSection(
            header: '扣分规则 · ${subRules.length}',
            footer: '例如：迟到 -1、未交作业 -2',
            children: [
              if (subRules.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('暂无扣分规则',
                      style: TextStyle(color: AppTheme.tertiaryLabel)),
                )
              else
                for (final r in subRules)
                  _RuleTile(rule: r, positive: false),
              GroupedTile(
                title: '添加扣分规则',
                leading: Icon(AppIcons.circleMinus,
                    color: AppTheme.destructive),
                onTap: () => _editRule(context, preferPositive: false),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editRule(context),
        icon: const Icon(AppIcons.plus),
        label: const Text('新规则'),
      ),
    );
  }

  static Future<void> _resetDefaults(BuildContext context) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('恢复默认规则？'),
        content: const Text('当前自定义规则会被默认的加分/扣分项替换。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().resetPointPresets();
    }
  }

  static Future<void> _editRule(
    BuildContext context, {
    PointReasonPreset? existing,
    bool preferPositive = true,
  }) async {
    final ctrl = context.read<ClassController>();
    final reasonCtrl =
        TextEditingController(text: existing?.reason ?? '');
    var positive = existing == null
        ? preferPositive
        : existing.delta >= 0;
    var amount = (existing?.delta.abs() ?? (preferPositive ? 2 : 1))
        .clamp(1, 99);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? '添加规则' : '编辑规则',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('加分'),
                        icon: Icon(AppIcons.circlePlus, size: 16),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('扣分'),
                        icon: Icon(AppIcons.circleMinus, size: 16),
                      ),
                    ],
                    selected: {positive},
                    onSelectionChanged: (s) =>
                        setState(() => positive = s.first),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: '规则名称',
                      hintText: '如：课堂发言、迟到、未交作业',
                    ),
                    textInputAction: TextInputAction.done,
                    autofocus: existing == null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        positive ? '加多少分' : '扣多少分',
                        style: const TextStyle(fontSize: 17),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setState(() {
                          if (amount > 1) amount--;
                        }),
                        icon: const Icon(AppIcons.circleMinus),
                      ),
                      Text(
                        '$amount',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() {
                          if (amount < 99) amount++;
                        }),
                        icon: const Icon(AppIcons.circlePlus),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in const [1, 2, 3, 5, 10])
                        ActionChip(
                          label: Text('$n'),
                          onPressed: () => setState(() => amount = n),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      final reason = reasonCtrl.text.trim();
                      if (reason.isEmpty) return;
                      final next = PointReasonPreset(
                        reason: reason,
                        delta: positive ? amount : -amount,
                      );
                      await ctrl.upsertPointPreset(
                        previousReason: existing?.reason,
                        preset: next,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                  if (existing != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        await ctrl.deletePointPreset(existing.reason);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(
                        '删除这条规则',
                        style: TextStyle(color: AppTheme.destructive),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.positive});

  final PointReasonPreset rule;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final delta = rule.delta;
    return GroupedTile(
      title: rule.reason,
      subtitle: positive ? '加分规则' : '扣分规则',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (positive ? const Color(0xFF34C759) : AppTheme.destructive)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${delta > 0 ? '+' : ''}$delta',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: positive
                ? const Color(0xFF248A3D)
                : AppTheme.destructive,
          ),
        ),
      ),
      onTap: () => PointRulesScreen._editRule(context, existing: rule),
      onLongPress: () async {
        final ok = await showCupertinoDialog<bool>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text('删除「${rule.reason}」？'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          await context
              .read<ClassController>()
              .deletePointPreset(rule.reason);
        }
      },
    );
  }
}
