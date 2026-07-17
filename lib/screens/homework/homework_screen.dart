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
      appBar: AppBar(
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

  Future<void> _add(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final title = TextEditingController();
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
              Text('添加作业', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(hintText: '如：语文第3课生字'),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  await ctrl.saveHomework(title.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('添加'),
              ),
            ],
          ),
        );
      },
    );
  }
}
