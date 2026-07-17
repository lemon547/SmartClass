import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:uuid/uuid.dart';

class LessonEditScreen extends StatefulWidget {
  const LessonEditScreen({super.key, this.existing});

  final LessonUnit? existing;

  static Future<void> push(BuildContext context, {LessonUnit? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LessonEditScreen(existing: existing)),
    );
  }

  @override
  State<LessonEditScreen> createState() => _LessonEditScreenState();
}

class _LessonEditScreenState extends State<LessonEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _subject;
  late final TextEditingController _chapter;
  late final TextEditingController _note;
  late LessonStatus _status;
  late String _planned;
  late String _taught;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _subject = TextEditingController(text: e?.subject ?? '');
    _chapter = TextEditingController(text: e?.chapter ?? '');
    _note = TextEditingController(text: e?.progressNote ?? '');
    _status = e?.status ?? LessonStatus.planned;
    _planned = e?.plannedDate ?? '';
    _taught = e?.taughtDate ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _chapter.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    final ctrl = context.read<ClassController>();
    final now = DateTime.now();
    final e = widget.existing;
    await ctrl.saveLessonUnit(
      LessonUnit(
        id: e?.id ?? const Uuid().v4(),
        title: _title.text.trim(),
        subject: _subject.text.trim(),
        chapter: _chapter.text.trim(),
        progressNote: _note.text.trim(),
        status: _status,
        plannedDate: _planned,
        taughtDate: _taught,
        sortOrder: e?.sortOrder ?? ctrl.lessonUnits.length,
        createdAt: e?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (d) => CupertinoAlertDialog(
        title: const Text('删除该课时？'),
        content: const Text('将同时删除已上传的课件文件。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(d, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<ClassController>().deleteLessonUnit(e.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.existing == null ? '添加课时' : '编辑课时'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '课题 / 课时名'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: '科目'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _chapter,
            decoration: const InputDecoration(labelText: '章节'),
          ),
          const SizedBox(height: 16),
          Text('进度', style: TextStyle(color: AppTheme.secondaryLabel)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in LessonStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('计划日期'),
            subtitle: Text(_planned.isEmpty ? '未设置' : _planned),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_planned) ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (d != null) {
                setState(() => _planned = DateFormat('yyyy-MM-dd').format(d));
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('实际授课日'),
            subtitle: Text(_taught.isEmpty ? '未设置' : _taught),
            trailing: const Icon(Icons.event_available_outlined),
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_taught) ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 2),
              );
              if (d != null) {
                setState(() => _taught = DateFormat('yyyy-MM-dd').format(d));
              }
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: '进度备注'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
          if (widget.existing != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _delete,
              child: Text('删除课时', style: TextStyle(color: AppTheme.destructive)),
            ),
          ],
        ],
      ),
    );
  }
}
