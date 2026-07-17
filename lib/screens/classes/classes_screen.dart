import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/class_edit_screen.dart';
import 'package:smart_class/screens/classes/class_features_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 多班级管理：按学校归类，支持切换 / 新增 / 编辑 / 删除
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final bySchool = <String, List<ManagedClass>>{};
    for (final c in ctrl.classes) {
      bySchool.putIfAbsent(c.schoolLabel, () => []).add(c);
    }
    final schools = bySchool.keys.toList()
      ..sort((a, b) {
        if (a == '未填写学校') return 1;
        if (b == '未填写学校') return -1;
        return a.compareTo(b);
      });

    return Scaffold(
      appBar: PageAppBar(
        title: const Text('班级'),
        actions: [
          IconButton(
            tooltip: '添加班级',
            onPressed: () => _editClass(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          for (final school in schools) ...[
            GroupedSection(
              header: school,
              footer: '${bySchool[school]!.length} 个班级',
              children: [
                for (final c in bySchool[school]!)
                  GroupedTile(
                    title: c.displayTitle,
                    subtitle: [
                      c.roleLabel,
                      if (c.groupName.trim().isNotEmpty) c.groupName.trim(),
                      if (c.id == ctrl.currentClass?.id) '当前',
                    ].join(' · '),
                    trailing: c.id == ctrl.currentClass?.id
                        ? Icon(Icons.check_circle,
                            color: AppTheme.blue, size: 22)
                        : null,
                    onTap: () async {
                      if (c.id != ctrl.currentClass?.id) {
                        await ctrl.switchClass(c.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已切换到 ${c.displayTitle}'),
                            ),
                          );
                        }
                      }
                    },
                    onLongPress: () => _classActions(context, c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (ctrl.classes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('暂无班级，请点击右上角添加'),
            ),
        ],
      ),
    );
  }

  Future<void> _classActions(BuildContext context, ManagedClass c) async {
    final ctrl = context.read<ClassController>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('切换到此班'),
              onTap: () async {
                Navigator.pop(ctx);
                await ctrl.switchClass(c.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(ctx);
                _editClass(context, existing: c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('本班功能'),
              onTap: () async {
                Navigator.pop(ctx);
                if (c.id != ctrl.currentClass?.id) {
                  await ctrl.switchClass(c.id);
                }
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ClassFeaturesScreen(),
                  ),
                );
              },
            ),
            if (ctrl.classes.length > 1)
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: AppTheme.destructive),
                title:
                    Text('删除', style: TextStyle(color: AppTheme.destructive)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: const Text('删除班级？'),
                      content: Text(
                        '将删除「${c.displayTitle}」及其学生、考勤、成绩等全部数据，且不可恢复。',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(d, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(d, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await ctrl.deleteManagedClass(c.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editClass(BuildContext context, {ManagedClass? existing}) async {
    final ctrl = context.read<ClassController>();
    final result = await Navigator.of(context).push<ClassEditResult>(
      MaterialPageRoute(
        builder: (_) => ClassEditScreen(
          existing: existing,
          defaultRows: existing?.seatRows ?? ctrl.profile.seatRows,
          defaultCols: existing?.seatCols ?? ctrl.profile.seatCols,
          knownSchools: [
            for (final c in ctrl.classes)
              if (c.school.trim().isNotEmpty) c.school.trim(),
          ]..sort(),
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    if (existing == null) {
      await ctrl.createManagedClass(
        name: result.name,
        school: result.school,
        grade: result.grade,
        groupName: result.groupName,
        teacherRole: result.role,
        subject: result.subject,
        seatRows: result.seatRows,
        seatCols: result.seatCols,
      );
    } else {
      await ctrl.updateManagedClass(
        existing.copyWith(
          name: result.name,
          school: result.school,
          grade: result.grade,
          groupName: result.groupName,
          teacherRole: result.role,
          subject: result.subject,
          seatRows: result.seatRows,
          seatCols: result.seatCols,
        ),
      );
    }
  }
}
