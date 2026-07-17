import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('作业检查'),
        actions: [
          IconButton(
            onPressed: () => _add(context),
            icon: const Icon(AppIcons.plus),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              '日期 ${ctrl.selectedDate}',
              style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13),
            ),
          ),
          if (ctrl.homework.isEmpty)
            Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('暂无作业，点右上角添加',
                    style: TextStyle(color: AppTheme.tertiaryLabel)),
              ),
            )
          else
            for (final hw in ctrl.homework) ...[
              GroupedSection(
                header: hw.title,
                children: [
                  GroupedTile(
                    title: '完成 ${hw.doneSet.length} / ${ctrl.students.length}',
                    trailing: IconButton(
                      icon: Icon(AppIcons.trash,
                          color: AppTheme.destructive, size: 20),
                      onPressed: () => ctrl.deleteHomework(hw.id),
                    ),
                  ),
                  for (final s in ctrl.students)
                    GroupedTile(
                      title: s.name,
                      trailing: Icon(
                        hw.doneSet.contains(s.id)
                            ? AppIcons.circleCheck
                            : AppIcons.circle,
                        color: hw.doneSet.contains(s.id)
                            ? AppTheme.blue
                            : AppTheme.quaternaryLabel,
                      ),
                      onTap: () => ctrl.toggleHomeworkDone(hw, s.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _HomeworkAddScreen()),
    );
  }
}

class _HomeworkAddScreen extends StatefulWidget {
  const _HomeworkAddScreen();

  @override
  State<_HomeworkAddScreen> createState() => _HomeworkAddScreenState();
}

class _HomeworkAddScreenState extends State<_HomeworkAddScreen> {
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    await context.read<ClassController>().saveHomework(_title.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(
        title: const Text('添加作业'),
        actions: [TextButton(onPressed: _save, child: const Text('添加'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(hintText: '如：语文第3课生字'),
            autofocus: true,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('添加')),
        ],
      ),
    );
  }
}
