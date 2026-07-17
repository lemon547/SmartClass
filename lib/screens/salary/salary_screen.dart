import 'package:flutter/material.dart';
import 'package:smart_class/theme/app_icons.dart';
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
      appBar: PageAppBar(
        title: const Text('每月工资'),
        actions: [
          IconButton(
            tooltip: '导入导出',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '工资',
              downloadTemplate: () =>
                  context.read<ClassController>().exportSalaryTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importSalaryFromBytes(bytes),
            ),
            icon: const Icon(AppIcons.moreVert),
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

  void _edit(BuildContext context, {SalaryRecord? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SalaryEditScreen(existing: existing),
      ),
    );
  }
}

class _SalaryEditScreen extends StatefulWidget {
  const _SalaryEditScreen({this.existing});
  final SalaryRecord? existing;

  @override
  State<_SalaryEditScreen> createState() => _SalaryEditScreenState();
}

class _SalaryEditScreenState extends State<_SalaryEditScreen> {
  late final TextEditingController _ym;
  late final TextEditingController _title;
  late final TextEditingController _base;
  late final TextEditingController _allowance;
  late final TextEditingController _deduction;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final now = DateTime.now();
    _ym = TextEditingController(
      text: e?.yearMonth ?? DateFormat('yyyy-MM').format(now),
    );
    _title = TextEditingController(text: e?.title ?? '月工资');
    _base = TextEditingController(
      text: e == null ? '' : e.baseAmount.toStringAsFixed(0),
    );
    _allowance = TextEditingController(
      text: e == null ? '' : e.allowance.toStringAsFixed(0),
    );
    _deduction = TextEditingController(
      text: e == null ? '' : e.deduction.toStringAsFixed(0),
    );
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _ym.dispose();
    _title.dispose();
    _base.dispose();
    _allowance.dispose();
    _deduction.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final now = DateTime.now();
    final b = double.tryParse(_base.text.trim()) ?? 0;
    final a = double.tryParse(_allowance.text.trim()) ?? 0;
    final d = double.tryParse(_deduction.text.trim()) ?? 0;
    final net = SalaryRecord.computeNet(base: b, allowance: a, deduction: d);
    final e = widget.existing;
    final record = SalaryRecord(
      id: e?.id ?? const Uuid().v4(),
      yearMonth: _ym.text.trim().isEmpty
          ? DateFormat('yyyy-MM').format(now)
          : _ym.text.trim(),
      title: _title.text.trim(),
      baseAmount: b,
      allowance: a,
      deduction: d,
      netAmount: net,
      paidAt: e?.paidAt ?? DateFormat('yyyy-MM-dd').format(now),
      note: _note.text.trim(),
      createdAt: e?.createdAt ?? now,
    );
    await context.read<ClassController>().upsertSalary(record);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.existing == null ? '记工资' : '编辑工资'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          TextField(
            controller: _ym,
            decoration: const InputDecoration(
              labelText: '月份',
              hintText: 'yyyy-MM',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _base,
            decoration: const InputDecoration(labelText: '基本工资'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _allowance,
            decoration: const InputDecoration(labelText: '补贴 / 津贴'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deduction,
            decoration: const InputDecoration(labelText: '扣款'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: '备注'),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
