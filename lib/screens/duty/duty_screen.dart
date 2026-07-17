import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/excel_import_sheet.dart';

class DutyScreen extends StatelessWidget {
  const DutyScreen({super.key});

  static const _days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('值日安排'),
        actions: [
          IconButton(
            tooltip: '导入导出',
            onPressed: () => showExcelImportActions(
              context: context,
              title: '值日',
              downloadTemplate: () =>
                  context.read<ClassController>().exportDutyTemplateFile(),
              importBytes: (bytes, _) =>
                  context.read<ClassController>().importDutyFromBytes(bytes),
            ),
            icon: const Icon(AppIcons.moreVert),
          ),
          TextButton(
            onPressed: ctrl.dutyList.isEmpty
                ? null
                : () async {
                    await ctrl.rotateDutyForward();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已整体后移一天（周一→周二…）')),
                      );
                    }
                  },
            child: const Text('轮换一周'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
        children: [
          for (var weekday = 1; weekday <= 7; weekday++) ...[
            GroupedSection(
              header: _days[weekday - 1],
              children: [
                ...ctrl.dutyList
                    .where((d) => d.weekday == weekday)
                    .map(
                      (d) => GroupedTile(
                        title: ctrl.studentById(d.studentId)?.name ?? '未知',
                        subtitle: d.task,
                        leading: StudentAvatar(
                          name: ctrl.studentById(d.studentId)?.name ?? '?',
                          size: 34,
                        ),
                        trailing: IconButton(
                          icon: Icon(AppIcons.circleMinus,
                              color: AppTheme.destructive),
                          onPressed: () => ctrl.removeDuty(d.id),
                        ),
                      ),
                    ),
                GroupedTile(
                  title: '添加值日生',
                  titleColor: AppTheme.blue,
                  leading: Icon(AppIcons.circlePlus,
                      color: AppTheme.blue),
                  onTap: () => _add(context, weekday),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, int weekday) async {
    final ctrl = context.read<ClassController>();
    if (ctrl.students.isEmpty) return;
    String? studentId = ctrl.students.first.id;
    final task = TextEditingController(text: '值日');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
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
                  Text('添加 ${_days[weekday - 1]} 值日',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: studentId,
                    items: [
                      for (final s in ctrl.students)
                        DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => studentId = v),
                    decoration: const InputDecoration(labelText: '学生'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: task,
                    decoration: const InputDecoration(labelText: '任务'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: studentId == null
                        ? null
                        : () async {
                            await ctrl.assignDuty(
                              weekday: weekday,
                              studentId: studentId!,
                              task: task.text.trim().isEmpty
                                  ? '值日'
                                  : task.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: const Text('添加'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
