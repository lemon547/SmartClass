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
      appBar: PageAppBar(
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

  void _edit(
    BuildContext context, {
    String? id,
    String title = '',
    String content = '',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditScreen(id: id, title: title, content: content),
      ),
    );
  }
}

class _NoteEditScreen extends StatefulWidget {
  const _NoteEditScreen({this.id, this.title = '', this.content = ''});
  final String? id;
  final String title;
  final String content;

  @override
  State<_NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<_NoteEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.title);
    _content = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    await context.read<ClassController>().saveNote(
          id: widget.id,
          title: _title.text,
          content: _content.text,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: Text(widget.id == null ? '新建记事' : '编辑记事'),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '内容'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
