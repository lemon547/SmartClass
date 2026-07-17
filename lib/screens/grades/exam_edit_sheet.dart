import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/data/class_repository.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';

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

/// 新建 / 编辑考试信息
Future<void> showExamEditSheet(
  BuildContext context, {
  Exam? existing,
}) async {
  final ctrl = context.read<ClassController>();
  final title = TextEditingController(text: existing?.title ?? '');
  final note = TextEditingController(text: existing?.note ?? '');
  final full = TextEditingController(
    text: _numText(existing?.fullScore ?? 100),
  );
  final pass = TextEditingController(
    text: _numText(existing?.passScore ?? 60),
  );
  var category = existing?.category ??
      (ctrl.examCategories.isNotEmpty ? ctrl.examCategories.first : '月考');
  var categories = List<String>.from(ctrl.examCategories);
  if (!categories.contains(category)) categories = [...categories, category];
  var examDate =
      existing?.examDate ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
  final subjects = List<String>.from(
    existing?.subjects ?? ClassRepository.defaultExamSubjects,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? '新建考试' : '编辑考试',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '如：2025 秋期末考',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '类别（可自由添加）',
                    style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categories)
                        ChoiceChip(
                          label: Text(c),
                          selected: category == c,
                          onSelected: (_) => setState(() => category = c),
                        ),
                      ActionChip(
                        avatar:
                            Icon(AppIcons.plus, size: 16, color: AppTheme.blue),
                        label: const Text('添加类别'),
                        onPressed: () async {
                          final added = await _promptText(
                            ctx,
                            title: '添加考试类别',
                            placeholder: '如：期中考、摸底考',
                          );
                          if (added == null) return;
                          await ctrl.addExamCategory(added);
                          setState(() {
                            if (!categories.contains(added)) {
                              categories = [...categories, added];
                            }
                            category = added;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('考试日期'),
                    subtitle: Text(examDate),
                    trailing: const Icon(AppIcons.calendar),
                    onTap: () async {
                      final now = DateTime.now();
                      final initial = DateTime.tryParse(examDate) ?? now;
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: initial,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 2),
                      );
                      if (picked != null) {
                        setState(() {
                          examDate = DateFormat('yyyy-MM-dd').format(picked);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: full,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '单科满分'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pass,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '及格分'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '科目（可增删）',
                    style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in subjects)
                        InputChip(
                          label: Text(s),
                          onDeleted: () => setState(() => subjects.remove(s)),
                        ),
                      ActionChip(
                        avatar:
                            Icon(AppIcons.plus, size: 16, color: AppTheme.blue),
                        label: const Text('添加科目'),
                        onPressed: () async {
                          final added = await _promptText(
                            ctx,
                            title: '添加科目',
                            placeholder: '如：信息技术',
                          );
                          if (added == null) return;
                          setState(() {
                            if (!subjects.contains(added)) subjects.add(added);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: '备注'),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () async {
                      if (title.text.trim().isEmpty) return;
                      if (subjects.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请至少添加一个科目')),
                        );
                        return;
                      }
                      await ctrl.saveExam(
                        id: existing?.id,
                        title: title.text,
                        category: category,
                        examDate: examDate,
                        subjects: subjects,
                        fullScore: double.tryParse(full.text) ?? 100,
                        passScore: double.tryParse(pass.text) ?? 60,
                        note: note.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
