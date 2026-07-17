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
      appBar: PageAppBar(
        title: const Text('积分兑换'),
        actions: [
          IconButton(
            tooltip: '导入导出',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '奖品',
              downloadTemplate: () =>
                  context.read<ClassController>().exportRewardTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importRewardFromBytes(bytes),
            ),
            icon: const Icon(AppIcons.moreVert),
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

  void _editReward(BuildContext context, {RewardItem? reward}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RewardEditScreen(reward: reward),
      ),
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

class _RewardEditScreen extends StatefulWidget {
  const _RewardEditScreen({this.reward});
  final RewardItem? reward;

  @override
  State<_RewardEditScreen> createState() => _RewardEditScreenState();
}

class _RewardEditScreenState extends State<_RewardEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _stock;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.reward?.name ?? '');
    _cost = TextEditingController(text: '${widget.reward?.cost ?? 10}');
    _stock = TextEditingController(text: '${widget.reward?.stock ?? 20}');
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = int.tryParse(_cost.text) ?? 0;
    final s = int.tryParse(_stock.text) ?? 0;
    if (_name.text.trim().isEmpty || c <= 0) return;
    await context.read<ClassController>().saveReward(
          id: widget.reward?.id,
          name: _name.text,
          cost: c,
          stock: s,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.reward == null ? '添加奖品' : '编辑奖品'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cost,
            decoration: const InputDecoration(labelText: '所需积分'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _stock,
            decoration: const InputDecoration(labelText: '库存'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
          if (widget.reward != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await context
                    .read<ClassController>()
                    .deleteReward(widget.reward!.id);
                if (mounted) Navigator.pop(context);
              },
              child: Text('删除奖品',
                  style: TextStyle(color: AppTheme.destructive)),
            ),
          ],
        ],
      ),
    );
  }
}
