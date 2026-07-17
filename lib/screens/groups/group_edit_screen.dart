import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class GroupEditScreen extends StatefulWidget {
  const GroupEditScreen({super.key, this.groupName});

  /// 为空表示新建小组
  final String? groupName;

  static Future<void> push(BuildContext context, {String? groupName}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GroupEditScreen(groupName: groupName)),
    );
  }

  @override
  State<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends State<GroupEditScreen> {
  late final TextEditingController _name;
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<ClassController>();
    _name = TextEditingController(text: widget.groupName ?? '');
    if (widget.groupName != null) {
      _selected = ctrl
          .studentsInGroup(widget.groupName!)
          .map((s) => s.id)
          .toSet();
    } else {
      _selected = {};
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<Student> _selectableStudents(ClassController ctrl) {
    final ungrouped = ctrl.ungroupedStudents;
    if (widget.groupName == null) return ungrouped;
    final inGroup = ctrl.studentsInGroup(widget.groupName!);
    final ids = <String>{};
    final list = <Student>[];
    for (final s in [...inGroup, ...ungrouped]) {
      if (ids.add(s.id)) list.add(s);
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> _save() async {
    final err = await context.read<ClassController>().saveGroupMembers(
          previousName: widget.groupName,
          name: _name.text,
          studentIds: _selected.toList(),
        );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final name = widget.groupName;
    if (name == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('解散小组'),
        content: Text('确定解散「$name」？组员将变为未分组。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('解散'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<ClassController>().deleteGroup(name);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final selectable = _selectableStudents(ctrl);
    final isEdit = widget.groupName != null;

    return Scaffold(
      appBar: PageAppBar(
        title: Text(isEdit ? '编辑小组' : '添加小组'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(AppIcons.trash),
              onPressed: _delete,
              tooltip: '解散小组',
            ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '小组名称',
              hintText: '如：第一组',
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          Text(
            '选择成员',
            style: TextStyle(color: AppTheme.tertiaryLabel),
          ),
          const SizedBox(height: 4),
          Text(
            '从未分组学生中选择（已在本组的学生可取消勾选以移出）',
            style: TextStyle(fontSize: 13, color: AppTheme.tertiaryLabel),
          ),
          const SizedBox(height: 12),
          if (selectable.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isEdit ? '暂无可选学生' : '暂无未分组学生',
                  style: TextStyle(color: AppTheme.tertiaryLabel),
                ),
              ),
            )
          else
            GroupedSection(
              padding: EdgeInsets.zero,
              children: [
                for (final s in selectable)
                  GroupedTile(
                    title: s.name,
                    subtitle: s.studentNo.isEmpty ? null : '学号 ${s.studentNo}',
                    trailing: Icon(
                      _selected.contains(s.id)
                          ? AppIcons.circleCheck
                          : AppIcons.circle,
                      color: _selected.contains(s.id)
                          ? AppTheme.blue
                          : AppTheme.tertiaryLabel,
                    ),
                    onTap: () => setState(() {
                      if (_selected.contains(s.id)) {
                        _selected.remove(s.id);
                      } else {
                        _selected.add(s.id);
                      }
                    }),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
