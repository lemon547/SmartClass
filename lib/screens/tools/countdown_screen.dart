import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 倒数日 — 参考班小二「学期进度倒计时」
class CountdownScreen extends StatelessWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('倒数日'),
        actions: [
          IconButton(
            onPressed: () => _edit(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          GroupedSection(
            header: '重要日子',
            footer: '考试、家长会、放假等，到日子会显示「今天」。',
            children: [
              if (ctrl.countdowns.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('暂无倒数日',
                      style: TextStyle(color: AppTheme.tertiaryLabel)),
                )
              else
                for (final c in [...ctrl.countdowns]
                  ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft)))
                  GroupedTile(
                    title: c.title,
                    subtitle: c.targetDate,
                    trailing: Text(
                      c.daysLeft > 0
                          ? '还有 ${c.daysLeft} 天'
                          : (c.daysLeft == 0 ? '就是今天' : '已过 ${-c.daysLeft} 天'),
                      style: TextStyle(
                        fontSize: 15,
                        color: c.daysLeft <= 7 && c.daysLeft >= 0
                            ? AppTheme.blue
                            : AppTheme.secondaryLabel,
                      ),
                    ),
                    onTap: () => _edit(context, id: c.id, title: c.title, date: c.targetDate),
                    onLongPress: () => _delete(context, c.id, c.title),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, String id, String title) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「$title」？'),
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
      await context.read<ClassController>().deleteCountdown(id);
    }
  }

  Future<void> _edit(
    BuildContext context, {
    String? id,
    String title = '',
    String date = '',
  }) async {
    final ctrl = context.read<ClassController>();
    final titleCtrl = TextEditingController(text: title);
    var picked = date.isNotEmpty
        ? (DateTime.tryParse(date) ?? DateTime.now().add(const Duration(days: 30)))
        : DateTime.now().add(const Duration(days: 30));

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
                  Text(id == null ? '添加倒数日' : '编辑倒数日',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '名称，如期中考试'),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('目标日期'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(picked)),
                    trailing: const Icon(AppIcons.calendar),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: picked,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => picked = d);
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      await ctrl.saveCountdown(
                        id: id,
                        title: titleCtrl.text,
                        targetDate: DateFormat('yyyy-MM-dd').format(picked),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
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
