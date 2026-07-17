import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';
import 'package:uuid/uuid.dart';

/// 每月工资（个人级）
class SalaryScreen extends StatelessWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.salaryRecords;
    final yearTotal = list.fold<double>(0, (a, b) => a + b.netAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('每月工资'),
        actions: [
          IconButton(
            tooltip: 'Excel',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '工资',
              downloadTemplate: () =>
                  context.read<ClassController>().exportSalaryTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importSalaryFromBytes(bytes),
            ),
            icon: const Icon(Icons.table_chart_outlined),
          ),
          IconButton(
            tooltip: '记一笔',
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '累计实发',
                  style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
                ),
                Text(
                  '¥${yearTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontSize: 32,
                        height: 1.2,
                      ),
                ),
              ],
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('还没有工资记录，点右上角添加本月工资。'),
            )
          else
            GroupedSection(
              header: '明细',
              children: [
                for (final r in list)
                  GroupedTile(
                    title: r.title.trim().isEmpty
                        ? '${r.yearMonth} 工资'
                        : r.title,
                    subtitle:
                        '基本 ${r.baseAmount.toStringAsFixed(0)} · 补贴 ${r.allowance.toStringAsFixed(0)} · 扣款 ${r.deduction.toStringAsFixed(0)}',
                    trailing: Text(
                      '¥${r.netAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.label,
                      ),
                    ),
                    onTap: () => _edit(context, existing: r),
                    onLongPress: () => _confirmDelete(context, r),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SalaryRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('删除这条记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ClassController>().deleteSalary(r.id);
    }
  }

  Future<void> _edit(BuildContext context, {SalaryRecord? existing}) async {
    final ctrl = context.read<ClassController>();
    final now = DateTime.now();
    final ym = TextEditingController(
      text: existing?.yearMonth ?? DateFormat('yyyy-MM').format(now),
    );
    final title = TextEditingController(text: existing?.title ?? '月工资');
    final base = TextEditingController(
      text: existing == null ? '' : existing.baseAmount.toStringAsFixed(0),
    );
    final allowance = TextEditingController(
      text: existing == null ? '' : existing.allowance.toStringAsFixed(0),
    );
    final deduction = TextEditingController(
      text: existing == null ? '' : existing.deduction.toStringAsFixed(0),
    );
    final note = TextEditingController(text: existing?.note ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  existing == null ? '记工资' : '编辑工资',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ym,
                  decoration: const InputDecoration(
                    labelText: '月份',
                    hintText: 'yyyy-MM',
                  ),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '标题'),
                ),
                TextField(
                  controller: base,
                  decoration: const InputDecoration(labelText: '基本工资'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: allowance,
                  decoration: const InputDecoration(labelText: '补贴 / 津贴'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: deduction,
                  decoration: const InputDecoration(labelText: '扣款'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: '备注'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true) return;
    final b = double.tryParse(base.text.trim()) ?? 0;
    final a = double.tryParse(allowance.text.trim()) ?? 0;
    final d = double.tryParse(deduction.text.trim()) ?? 0;
    final net = SalaryRecord.computeNet(base: b, allowance: a, deduction: d);
    final record = SalaryRecord(
      id: existing?.id ?? const Uuid().v4(),
      yearMonth: ym.text.trim().isEmpty
          ? DateFormat('yyyy-MM').format(now)
          : ym.text.trim(),
      title: title.text.trim(),
      baseAmount: b,
      allowance: a,
      deduction: d,
      netAmount: net,
      paidAt: existing?.paidAt ?? DateFormat('yyyy-MM-dd').format(now),
      note: note.text.trim(),
      createdAt: existing?.createdAt ?? now,
    );
    await ctrl.upsertSalary(record);
  }
}
