import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/date_picker_sheet.dart';

String _numText(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : '$v';

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String placeholder,
}) async {
  final text = TextEditingController();
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: text,
          placeholder: placeholder,
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  final value = text.text.trim();
  text.dispose();
  if (ok != true || value.isEmpty) return null;
  return value;
}

class ExamEditScreen extends StatefulWidget {
  const ExamEditScreen({super.key, this.existing});
  final Exam? existing;

  /// 从编辑页删除考试时返回此标记，详情页应一并关闭
  static const deletedToken = '__exam_deleted__';

  /// 返回保存后的考试 id；删除返回 [deletedToken]；取消为 null
  static Future<String?> push(BuildContext context, {Exam? existing}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ExamEditScreen(existing: existing),
      ),
    );
  }

  @override
  State<ExamEditScreen> createState() => _ExamEditScreenState();
}

class _ExamEditScreenState extends State<ExamEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _full;
  late final TextEditingController _pass;
  late String _category;
  late List<String> _categories;
  late String _examDate;
  late List<String> _subjects;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final ctrl = context.read<ClassController>();
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _full = TextEditingController(text: _numText(e?.fullScore ?? 100));
    _pass = TextEditingController(text: _numText(e?.passScore ?? 60));
    _category = e?.category ??
        (ctrl.examCategories.isNotEmpty ? ctrl.examCategories.first : '月考');
    _categories = List<String>.from(ctrl.examCategories);
    if (!_categories.contains(_category)) {
      _categories = [..._categories, _category];
    }
    _examDate = e?.examDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    _subjects = List<String>.from(
      e?.subjects ?? ClassRepository.defaultExamSubjects,
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _full.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写考试名称')),
      );
      return;
    }
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个科目')),
      );
      return;
    }
    final ctrl = context.read<ClassController>();
    final id = await ctrl.saveExam(
      id: widget.existing?.id,
      title: _title.text,
      category: _category,
      examDate: _examDate,
      subjects: _subjects,
      fullScore: double.tryParse(_full.text) ?? 100,
      passScore: double.tryParse(_pass.text) ?? 60,
      note: _note.text,
    );
    if (mounted) Navigator.pop(context, id);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除「${existing.title}」？'),
        content: const Text('成绩记录与已上传的考试资料将一并删除。'),
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
    if (ok != true || !mounted) return;
    await context.read<ClassController>().deleteExam(existing.id);
    if (mounted) Navigator.pop(context, ExamEditScreen.deletedToken);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.existing == null ? '新建成绩报告' : '编辑考试'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: '名称',
              hintText: '如：2025 秋期末考',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          Text(
            '类别',
            style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _categories)
                ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _category = c),
                ),
              ActionChip(
                avatar: Icon(AppIcons.plus, size: 16, color: AppTheme.blue),
                label: const Text('添加类别'),
                onPressed: () async {
                  final ctrl = context.read<ClassController>();
                  final added = await _promptText(
                    context,
                    title: '添加考试类别',
                    placeholder: '如：期中考、摸底考',
                  );
                  if (added == null) return;
                  await ctrl.addExamCategory(added);
                  setState(() {
                    if (!_categories.contains(added)) {
                      _categories = [..._categories, added];
                    }
                    _category = added;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('考试日期'),
            subtitle: Text(_examDate),
            trailing: const Icon(AppIcons.calendar),
            onTap: () async {
              final now = DateTime.now();
              final initial = DateTime.tryParse(_examDate) ?? now;
              final picked = await showAppDatePicker(
                context,
                initialDate: initial,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                setState(() {
                  _examDate = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            },
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _full,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '单科满分'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _pass,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '及格分'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '科目（默认为语数英，可增删）',
            style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _subjects)
                InputChip(
                  label: Text(s),
                  onDeleted: () => setState(() => _subjects.remove(s)),
                ),
              ActionChip(
                avatar: Icon(AppIcons.plus, size: 16, color: AppTheme.blue),
                label: const Text('添加科目'),
                onPressed: () async {
                  final added = await _promptText(
                    context,
                    title: '添加科目',
                    placeholder: '如：信息技术',
                  );
                  if (added == null) return;
                  setState(() {
                    if (!_subjects.contains(added)) _subjects.add(added);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: '备注'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
          if (widget.existing != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: AppTheme.destructive),
              child: const Text('删除考试'),
            ),
          ],
        ],
      ),
    );
  }
}
