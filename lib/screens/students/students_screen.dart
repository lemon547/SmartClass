import 'package:flutter/cupertino.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/students/student_detail_screen.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/widgets/apple_widgets.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ClassController>();
    final list = ctrl.searchStudents(_query);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LargeTitle(
              '学生',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _batchAdd(context),
                    icon: Icon(AppIcons.listPlus,
                        color: AppTheme.blue),
                    tooltip: '批量添加',
                  ),
                  IconButton(
                    onPressed: () => _editStudent(context),
                    icon: Icon(AppIcons.plus,
                        color: AppTheme.blue),
                  ),
                ],
              ),
            ),
            SearchField(
              controller: _search,
              hint: '搜索姓名、学号、小组',
              onChanged: (v) => setState(() => _query = v),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        ctrl.students.isEmpty ? '点右上角添加学生' : '没有匹配结果',
                        style: TextStyle(color: AppTheme.tertiaryLabel),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        GroupedSection(
                          header: '${list.length} 人',
                          children: [
                            for (final s in list)
                              Dismissible(
                                key: ValueKey(s.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppTheme.destructive,
                                  child: const Icon(AppIcons.trash,
                                      color: Colors.white),
                                ),
                                confirmDismiss: (_) => _confirmDelete(s),
                                onDismissed: (_) =>
                                    ctrl.removeStudent(s.id),
                                child: GroupedTile(
                                  title: s.name,
                                  subtitle: _subtitle(s),
                                  leading: StudentAvatar(name: s.name),
                                  trailing: Text(
                                    '${s.points}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: AppTheme.tertiaryLabel,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          StudentDetailScreen(studentId: s.id),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Student s) {
    final parts = <String>[];
    if (s.role.isNotEmpty) parts.add(s.role);
    if (s.studentNo.isNotEmpty) parts.add(s.studentNo);
    if (s.groupName.isNotEmpty) parts.add(s.groupName);
    if (s.gender != '未知') parts.add(s.gender);
    if (s.birthday.isNotEmpty) parts.add('生日 ${s.birthday}');
    return parts.isEmpty ? '查看详情' : parts.join(' · ');
  }

  Future<bool> _confirmDelete(Student s) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('删除 ${s.name}？'),
        content: const Text('相关记录将一并删除。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _batchAdd(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final text = TextEditingController();
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
              Text('批量添加', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '每行一个姓名，粘贴花名册即可',
                style: TextStyle(color: AppTheme.tertiaryLabel, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: text,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(hintText: '张三\n李四\n王五'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final names = text.text.split(RegExp(r'[\n,，、]'));
                  await ctrl.batchAddStudents(names);
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

  Future<void> _editStudent(BuildContext context, {Student? student}) async {
    final ctrl = context.read<ClassController>();
    final name = TextEditingController(text: student?.name ?? '');
    final no = TextEditingController(text: student?.studentNo ?? '');
    final phone = TextEditingController(text: student?.phone ?? '');
    final note = TextEditingController(text: student?.note ?? '');
    final group = TextEditingController(text: student?.groupName ?? '');
    final birthday = TextEditingController(text: student?.birthday ?? '');
    var gender = student?.gender ?? '未知';
    var role = student?.role ?? '';
    const roles = ['', '班长', '副班长', '学习委员', '纪律委员', '体育委员', '文艺委员', '生活委员', '组长'];

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
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      student == null ? '添加学生' : '编辑学生',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: '姓名')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: no,
                        decoration: const InputDecoration(labelText: '学号')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: group,
                        decoration: const InputDecoration(labelText: '小组')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: birthday,
                        decoration: const InputDecoration(
                          labelText: '生日（月-日）',
                          hintText: '如 03-15',
                        )),
                    const SizedBox(height: 10),
                    TextField(
                        controller: phone,
                        decoration: const InputDecoration(labelText: '家长电话'),
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 10),
                    TextField(
                        controller: note,
                        decoration: const InputDecoration(labelText: '备注')),
                    const SizedBox(height: 12),
                    Text('班委',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.tertiaryLabel)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in roles)
                          ChoiceChip(
                            label: Text(r.isEmpty ? '无' : r),
                            selected: role == r,
                            onSelected: (_) => setState(() => role = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final g in ['男', '女', '未知'])
                          ChoiceChip(
                            label: Text(g),
                            selected: gender == g,
                            onSelected: (_) => setState(() => gender = g),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty) return;
                        await ctrl.saveStudent(
                          id: student?.id,
                          name: name.text,
                          studentNo: no.text,
                          phone: phone.text,
                          note: note.text,
                          gender: gender,
                          groupName: group.text,
                          role: role,
                          birthday: birthday.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
