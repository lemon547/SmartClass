import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/classes/class_features_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

/// 多班级管理：按分组标签展示，支持切换 / 新增 / 编辑 / 删除
class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final grouped = <String, List<ManagedClass>>{};
    for (final c in ctrl.classes) {
      final key = c.groupName.trim().isEmpty ? '未分组' : c.groupName.trim();
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final keys = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
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
          for (final key in keys) ...[
            GroupedSection(
              header: key,
              children: [
                for (final c in grouped[key]!)
                  GroupedTile(
                    title: c.displayTitle,
                    subtitle:
                        '${c.roleLabel}${c.id == ctrl.currentClass?.id ? ' · 当前' : ''}',
                    trailing: c.id == ctrl.currentClass?.id
                        ? Icon(Icons.check_circle, color: AppTheme.blue, size: 22)
                        : null,
                    onTap: () async {
                      if (c.id != ctrl.currentClass?.id) {
                        await ctrl.switchClass(c.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已切换到 ${c.displayTitle}')),
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
                leading: Icon(Icons.delete_outline, color: AppTheme.destructive),
                title: Text('删除', style: TextStyle(color: AppTheme.destructive)),
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
    final name = TextEditingController(text: existing?.name ?? '');
    final grade = TextEditingController(text: existing?.grade ?? '');
    final group = TextEditingController(text: existing?.groupName ?? '');
    var role = existing?.teacherRole ?? TeacherRole.homeroom;
    final rows = TextEditingController(
      text: '${existing?.seatRows ?? ctrl.profile.seatRows}',
    );
    final cols = TextEditingController(
      text: '${existing?.seatCols ?? ctrl.profile.seatCols}',
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? '添加班级' : '编辑班级',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '班级名称'),
                    textInputAction: TextInputAction.next,
                  ),
                  TextField(
                    controller: grade,
                    decoration: const InputDecoration(labelText: '年级'),
                  ),
                  TextField(
                    controller: group,
                    decoration: const InputDecoration(
                      labelText: '分组标签',
                      hintText: '如：高一、任教',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('我的角色', style: TextStyle(color: AppTheme.secondaryLabel)),
                  const SizedBox(height: 6),
                  SegmentedButton<TeacherRole>(
                    segments: const [
                      ButtonSegment(
                        value: TeacherRole.homeroom,
                        label: Text('班主任'),
                      ),
                      ButtonSegment(
                        value: TeacherRole.subject,
                        label: Text('科任'),
                      ),
                    ],
                    selected: {role},
                    onSelectionChanged: (s) => setLocal(() => role = s.first),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rows,
                          decoration: const InputDecoration(labelText: '座位行'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: cols,
                          decoration: const InputDecoration(labelText: '座位列'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      if (name.text.trim().isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
                    child: Text(existing == null ? '创建' : '保存'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;
    final seatRows = int.tryParse(rows.text) ?? 6;
    final seatCols = int.tryParse(cols.text) ?? 8;
    if (existing == null) {
      await ctrl.createManagedClass(
        name: name.text,
        grade: grade.text,
        groupName: group.text,
        teacherRole: role,
        seatRows: seatRows.clamp(1, 20),
        seatCols: seatCols.clamp(1, 20),
      );
    } else {
      await ctrl.updateManagedClass(
        existing.copyWith(
          name: name.text.trim(),
          grade: grade.text.trim(),
          groupName: group.text.trim(),
          teacherRole: role,
          seatRows: seatRows.clamp(1, 20),
          seatCols: seatCols.clamp(1, 20),
        ),
      );
    }
  }
}
