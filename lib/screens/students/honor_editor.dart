import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:uuid/uuid.dart';

Future<void> showHonorEditor(
  BuildContext context, {
  required String studentId,
  StudentHonor? existing,
}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final date = TextEditingController(
    text: existing?.date.isNotEmpty == true
        ? existing!.date
        : DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final level = TextEditingController(text: existing?.level ?? '');
  final note = TextEditingController(text: existing?.note ?? '');
  final levels = ['校级', '区级', '市级', '省级', '国家级', '其他'];

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              existing == null ? '添加荣誉' : '编辑荣誉',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: '荣誉名称',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: date,
              decoration: const InputDecoration(
                labelText: '日期 YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: level,
              decoration: const InputDecoration(
                labelText: '级别（校/区/市等）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final l in levels)
                  ActionChip(
                    label: Text(l),
                    onPressed: () => level.text = l,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      );
    },
  );

  if (ok != true || !context.mounted) return;
  final ctrl = context.read<ClassController>();
  await ctrl.saveStudentHonor(
    StudentHonor(
      id: existing?.id ?? const Uuid().v4(),
      studentId: studentId,
      title: title.text.trim(),
      date: date.text.trim(),
      level: level.text.trim(),
      note: note.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
    ),
  );
}
