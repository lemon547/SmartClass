import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';

/// 班费收支 — 参考班主任管理大师「班费收支登记」
class FundScreen extends StatelessWidget {
  const FundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('班费'),
        actions: [
          IconButton(
            tooltip: 'Excel',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '班费',
              downloadTemplate: () =>
                  context.read<ClassController>().exportFundTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importFundFromBytes(bytes),
            ),
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            onPressed: () => _edit(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                QuietStat(label: '余额', value: '${ctrl.fundBalance}'),
                QuietStat(label: '笔数', value: '${ctrl.fundRecords.length}'),
              ],
            ),
          ),
          GroupedSection(
            header: '收支明细',
            footer: '金额为正表示收入，为负表示支出。长按可删除。',
            children: [
              if (ctrl.fundRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text('暂无记录',
                      style: TextStyle(color: AppTheme.tertiaryLabel)),
                )
              else
                for (final r in ctrl.fundRecords)
                  GroupedTile(
                    title: r.title,
                    subtitle: [
                      r.date,
                      if (r.note.isNotEmpty) r.note,
                    ].join(' · '),
                    trailing: Text(
                      '${r.amount > 0 ? '+' : ''}${r.amount}',
                      style: TextStyle(
                        fontSize: 17,
                        color: r.amount >= 0
                            ? AppTheme.blue
                            : AppTheme.destructive,
                      ),
                    ),
                    onTap: () => _edit(
                      context,
                      id: r.id,
                      title: r.title,
                      amount: r.amount,
                      date: r.date,
                      note: r.note,
                    ),
                    onLongPress: () => _delete(context, r.id, r.title),
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
      await context.read<ClassController>().deleteFundRecord(id);
    }
  }

  Future<void> _edit(
    BuildContext context, {
    String? id,
    String title = '',
    int amount = 0,
    String date = '',
    String note = '',
  }) async {
    final ctrl = context.read<ClassController>();
    final titleCtrl = TextEditingController(text: title);
    final amountCtrl = TextEditingController(
      text: amount == 0 ? '' : amount.toString(),
    );
    final noteCtrl = TextEditingController(text: note);
    var picked = date.isNotEmpty
        ? (DateTime.tryParse(date) ?? DateTime.now())
        : DateTime.now();

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
                  Text(id == null ? '记一笔' : '编辑',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: '说明'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: '金额（正收入 / 负支出）',
                      hintText: '如 200 或 -50',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: '备注（可选）'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('日期'),
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
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () async {
                      final a = int.tryParse(amountCtrl.text.trim());
                      if (titleCtrl.text.trim().isEmpty || a == null) return;
                      await ctrl.saveFundRecord(
                        id: id,
                        title: titleCtrl.text,
                        amount: a,
                        date: DateFormat('yyyy-MM-dd').format(picked),
                        note: noteCtrl.text,
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
