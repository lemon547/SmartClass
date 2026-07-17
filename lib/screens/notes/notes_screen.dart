import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('班级记事'),
        actions: [
          IconButton(
            onPressed: () => _edit(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          GroupedSection(
            children: [
              if (ctrl.notes.isEmpty)
                Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('记录班会、通知、家长沟通要点',
                      style: TextStyle(color: AppTheme.tertiaryLabel)),
                )
              else
                for (final n in ctrl.notes)
                  Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppTheme.destructive,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(AppIcons.trash, color: Colors.white),
                    ),
                    onDismissed: (_) => ctrl.deleteNote(n.id),
                    child: GroupedTile(
                      title: n.title,
                      subtitle:
                          '${DateFormat('M/d HH:mm').format(n.createdAt)}${n.content.isEmpty ? '' : ' · ${n.content}'}',
                      onTap: () => _edit(context, id: n.id, title: n.title, content: n.content),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context, {
    String? id,
    String title = '',
    String content = '',
  }) async {
    final ctrl = context.read<ClassController>();
    final t = TextEditingController(text: title);
    final c = TextEditingController(text: content);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
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
              Text(id == null ? '新建记事' : '编辑记事',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                  controller: t,
                  decoration: const InputDecoration(labelText: '标题')),
              const SizedBox(height: 8),
              TextField(
                controller: c,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '内容'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (t.text.trim().isEmpty) return;
                  await ctrl.saveNote(
                      id: id, title: t.text, content: c.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }
}
