import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';

/// 倒数日：支持多条，点击添加/编辑，长按删除
class CountdownScreen extends StatelessWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final upcoming = ctrl.upcomingCountdowns;
    final past = ctrl.countdowns.where((c) => c.daysLeft < 0).toList()
      ..sort((a, b) => b.daysLeft.compareTo(a.daysLeft));

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('倒数日'),
        actions: [
          IconButton(
            tooltip: '导入导出',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '倒数日',
              downloadTemplate: () =>
                  context.read<ClassController>().exportCountdownTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importCountdownFromBytes(bytes),
            ),
            icon: const Icon(AppIcons.moreVert),
          ),
          IconButton(
            tooltip: '添加',
            onPressed: () => _edit(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28, top: 8),
        children: [
          if (ctrl.countdowns.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
              child: Column(
                children: [
                  Icon(AppIcons.hourglass,
                      size: 40, color: AppTheme.quaternaryLabel),
                  const SizedBox(height: 12),
                  Text(
                    '还没有倒数日',
                    style: TextStyle(color: AppTheme.tertiaryLabel),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '可添加考试、家长会、放假等多个日期',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.quaternaryLabel,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(AppIcons.plus, size: 18),
                    label: const Text('添加倒数日'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      await context.read<ClassController>().seedDemo();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已填充演示数据')),
                        );
                      }
                    },
                    child: const Text('一键填充示例数据'),
                  ),
                ],
              ),
            )
          else ...[
            if (upcoming.isNotEmpty)
              GroupedSection(
                header: '进行中 · ${upcoming.length}',
                footer: '点按编辑，长按删除。可添加任意多个。',
                children: [
                  for (final c in upcoming) _CountdownTile(item: c),
                ],
              ),
            if (past.isNotEmpty) ...[
              const SizedBox(height: 18),
              GroupedSection(
                header: '已过期 · ${past.length}',
                children: [
                  for (final c in past) _CountdownTile(item: c),
                ],
              ),
            ],
          ],
        ],
      ),
      floatingActionButton: ctrl.countdowns.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _edit(context),
              child: const Icon(AppIcons.plus),
            ),
    );
  }

  static Future<void> _edit(
    BuildContext context, {
    String? id,
    String title = '',
    String date = '',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CountdownEditScreen(id: id, title: title, date: date),
      ),
    );
  }

  static Future<void> delete(BuildContext context, CountdownItem c) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${c.title}」？'),
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
      await context.read<ClassController>().deleteCountdown(c.id);
    }
  }
}

class _CountdownEditScreen extends StatefulWidget {
  const _CountdownEditScreen({this.id, this.title = '', this.date = ''});
  final String? id;
  final String title;
  final String date;

  @override
  State<_CountdownEditScreen> createState() => _CountdownEditScreenState();
}

class _CountdownEditScreenState extends State<_CountdownEditScreen> {
  late final TextEditingController _title;
  late DateTime _picked;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
    _picked = widget.date.isNotEmpty
        ? (DateTime.tryParse(widget.date) ??
            DateTime.now().add(const Duration(days: 30)))
        : DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    await context.read<ClassController>().saveCountdown(
          id: widget.id,
          title: _title.text,
          targetDate: DateFormat('yyyy-MM-dd').format(_picked),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.id == null ? '添加倒数日' : '编辑倒数日'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          TextField(
            controller: _title,
            decoration:
                const InputDecoration(labelText: '名称，如期中考试、暑假'),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('目标日期'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_picked)),
            trailing: const Icon(AppIcons.calendar),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _picked,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _picked = d);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}

class _CountdownTile extends StatelessWidget {
  const _CountdownTile({required this.item});

  final CountdownItem item;

  @override
  Widget build(BuildContext context) {
    final days = item.daysLeft;
    final label = days > 0
        ? '$days'
        : (days == 0 ? '今' : '${-days}');
    final unit = days > 0 ? '天' : (days == 0 ? '天' : '天前');
    final accent = days >= 0 && days <= 7;

    return GroupedTile(
      title: item.title,
      subtitle: item.targetDate,
      leading: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent
              ? AppTheme.blue.withValues(alpha: 0.12)
              : AppTheme.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: days == 0 ? 16 : 18,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: accent ? AppTheme.blue : AppTheme.label,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: accent ? AppTheme.blue : AppTheme.tertiaryLabel,
              ),
            ),
          ],
        ),
      ),
      onTap: () => CountdownScreen._edit(
        context,
        id: item.id,
        title: item.title,
        date: item.targetDate,
      ),
      onLongPress: () => CountdownScreen.delete(context, item),
    );
  }
}
