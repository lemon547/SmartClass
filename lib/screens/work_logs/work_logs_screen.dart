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

/// 工作留痕：安全教育 / 主题班会 / 学生谈话 / 心理关注 / 家长沟通 / 家访
class WorkLogsScreen extends StatefulWidget {
  const WorkLogsScreen({super.key, this.initialCategory});
  final WorkLogCategory? initialCategory;

  @override
  State<WorkLogsScreen> createState() => _WorkLogsScreenState();
}

class _WorkLogsScreenState extends State<WorkLogsScreen> {
  WorkLogCategory? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.workLogsOf(_filter);

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('工作留痕'),
        actions: [
          IconButton(
            tooltip: '导入导出',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '工作留痕',
              downloadTemplate: () =>
                  context.read<ClassController>().exportWorkLogTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importWorkLogFromBytes(bytes),
            ),
            icon: const Icon(AppIcons.moreVert),
          ),
          IconButton(
            tooltip: '新建记录',
            onPressed: () => _edit(context, category: _filter),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('全部 (${ctrl.workLogs.length})'),
                    selected: _filter == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final c in WorkLogCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${c.label} (${ctrl.workLogCount(c)})'),
                      selected: _filter == c,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.notebook,
                              size: 40, color: AppTheme.quaternaryLabel),
                          const SizedBox(height: 12),
                          Text(
                            _filter == null
                                ? '还没有工作留痕'
                                : '暂无「${_filter!.label}」记录',
                            style: TextStyle(color: AppTheme.tertiaryLabel),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '按类别记录班会、谈话、家访等，便于台账备查',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.quaternaryLabel,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                _edit(context, category: _filter),
                            icon: const Icon(AppIcons.plus, size: 18),
                            label: const Text('新建记录'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 88, top: 4),
                    children: [
                      GroupedSection(
                        header: _filter?.label ?? '全部记录',
                        footer: '点按编辑，长按删除',
                        children: [
                          for (final w in list)
                            GroupedTile(
                              title: w.title,
                              subtitle: [
                                w.category.label,
                                w.date,
                                if (w.studentIdList.isNotEmpty)
                                  _studentNames(ctrl, w.studentIdList),
                              ].join(' · '),
                              trailing: Icon(AppIcons.chevronRight,
                                  size: 18, color: AppTheme.quaternaryLabel),
                              onTap: () => _edit(context, existing: w),
                              onLongPress: () => _delete(context, w),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, category: _filter),
        icon: const Icon(AppIcons.plus),
        label: const Text('留痕'),
      ),
    );
  }

  String _studentNames(ClassController ctrl, List<String> ids) {
    final names = [
      for (final id in ids) ctrl.studentById(id)?.name ?? '',
    ].where((e) => e.isNotEmpty).toList();
    if (names.isEmpty) return '${ids.length} 人';
    if (names.length <= 2) return names.join('、');
    return '${names.take(2).join('、')} 等${names.length}人';
  }

  Future<void> _delete(BuildContext context, WorkLog w) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${w.title}」？'),
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
      await context.read<ClassController>().deleteWorkLog(w.id);
    }
  }

  void _edit(BuildContext context, {WorkLog? existing, WorkLogCategory? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WorkLogEditScreen(
          existing: existing,
          initialCategory: category,
        ),
      ),
    );
  }
}

class _WorkLogEditScreen extends StatefulWidget {
  const _WorkLogEditScreen({this.existing, this.initialCategory});
  final WorkLog? existing;
  final WorkLogCategory? initialCategory;

  @override
  State<_WorkLogEditScreen> createState() => _WorkLogEditScreenState();
}

class _WorkLogEditScreenState extends State<_WorkLogEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late WorkLogCategory _cat;
  late DateTime _date;
  late Set<String> _selectedStudents;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _contentCtrl = TextEditingController(text: e?.content ?? '');
    _cat = e?.category ?? widget.initialCategory ?? WorkLogCategory.classMeeting;
    _date = e != null ? (DateTime.tryParse(e.date) ?? DateTime.now()) : DateTime.now();
    _selectedStudents = {...?e?.studentIdList};
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  bool _needsStudent(WorkLogCategory c) =>
      c == WorkLogCategory.studentTalk ||
      c == WorkLogCategory.mentalCare ||
      c == WorkLogCategory.parentComm ||
      c == WorkLogCategory.homeVisit;

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    await context.read<ClassController>().saveWorkLog(
          id: widget.existing?.id,
          category: _cat,
          title: _titleCtrl.text,
          content: _contentCtrl.text,
          date: DateFormat('yyyy-MM-dd').format(_date),
          studentIds: _selectedStudents.toList(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.existing == null ? '新建留痕' : '编辑留痕'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text('类别', style: TextStyle(color: AppTheme.tertiaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in WorkLogCategory.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: _cat == c,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _cat = c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(labelText: '标题', hintText: _cat.hint),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('日期'),
            subtitle: Text(DateFormat('yyyy-MM-dd').format(_date)),
            trailing: const Icon(AppIcons.calendar),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          TextField(
            controller: _contentCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '内容记录',
              hintText: '过程、要点、结果与后续跟进',
              alignLabelWithHint: true,
            ),
          ),
          if (_needsStudent(_cat) && ctrl.students.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('关联学生（可选）',
                style: TextStyle(color: AppTheme.tertiaryLabel)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in ctrl.students)
                  FilterChip(
                    label: Text(s.name),
                    selected: _selectedStudents.contains(s.id),
                    showCheckmark: false,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedStudents.add(s.id);
                      } else {
                        _selectedStudents.remove(s.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
