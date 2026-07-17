import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('积分兑换'),
        actions: [
          IconButton(
            tooltip: 'Excel',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '奖品',
              downloadTemplate: () =>
                  context.read<ClassController>().exportRewardTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importRewardFromBytes(bytes),
            ),
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            onPressed: () => _editReward(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          GroupedSection(
            header: '奖品',
            footer: '学生用积分兑换奖品，库存与积分会同步扣减。',
            children: [
              if (ctrl.rewards.isEmpty)
                Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('暂无奖品',
                      style: TextStyle(color: AppTheme.tertiaryLabel)),
                )
              else
                for (final r in ctrl.rewards)
                  GroupedTile(
                    title: r.name,
                    subtitle: '库存 ${r.stock} · 点按兑换，长按编辑',
                    trailing: Text(
                      '${r.cost} 分',
                      style: const TextStyle(fontSize: 17),
                    ),
                    onTap: () => _redeem(context, r.id),
                    onLongPress: () => _editReward(context, reward: r),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editReward(BuildContext context, {RewardItem? reward}) async {
    final ctrl = context.read<ClassController>();
    final name = TextEditingController(text: reward?.name ?? '');
    final cost = TextEditingController(text: '${reward?.cost ?? 10}');
    final stock = TextEditingController(text: '${reward?.stock ?? 20}');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
              Text(reward == null ? '添加奖品' : '编辑奖品',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 8),
              TextField(
                controller: cost,
                decoration: const InputDecoration(labelText: '所需积分'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stock,
                decoration: const InputDecoration(labelText: '库存'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final c = int.tryParse(cost.text) ?? 0;
                  final s = int.tryParse(stock.text) ?? 0;
                  if (name.text.trim().isEmpty || c <= 0) return;
                  await ctrl.saveReward(
                    id: reward?.id,
                    name: name.text,
                    cost: c,
                    stock: s,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
              if (reward != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    await ctrl.deleteReward(reward.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text('删除奖品',
                      style: TextStyle(color: AppTheme.destructive)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _redeem(BuildContext context, String rewardId) async {
    final ctrl = context.read<ClassController>();
    RewardItem? reward;
    for (final e in ctrl.rewards) {
      if (e.id == rewardId) {
        reward = e;
        break;
      }
    }
    if (reward == null || ctrl.students.isEmpty) return;
    final item = reward;
    String? studentId = ctrl.rankedByPoints.first.id;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('兑换 ${item.name}',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: studentId,
                    items: [
                      for (final s in ctrl.rankedByPoints)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name}（${s.points}分）'),
                        ),
                    ],
                    onChanged: (v) => setState(() => studentId = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: studentId == null
                        ? null
                        : () async {
                            final ok =
                                await ctrl.redeemReward(studentId!, item);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? '兑换成功' : '积分不足或库存不足'),
                              ),
                            );
                          },
                    child: Text('确认兑换（${item.cost} 分）'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
