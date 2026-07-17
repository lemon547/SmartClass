import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smart_class/models/models.dart';
import 'package:smart_class/providers/class_controller.dart';
import 'package:smart_class/screens/students/student_detail_screen.dart';
import 'package:smart_class/theme/app_icons.dart';
import 'package:smart_class/theme/app_theme.dart';
import 'package:smart_class/theme/mascot_assets.dart';
import 'package:smart_class/widgets/apple_widgets.dart';
import 'package:smart_class/widgets/paddi_mascot.dart';

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
                    onPressed: () => _showRosterActions(context),
                    icon: Icon(AppIcons.listPlus, color: AppTheme.blue),
                    tooltip: '导入档案',
                  ),
                  IconButton(
                    onPressed: () => _editStudent(context),
                    icon: Icon(AppIcons.plus, color: AppTheme.blue),
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
                      child: PaddiEmptyHint(
                        message: ctrl.students.isEmpty
                            ? '点右上角添加学生'
                            : '没有匹配结果',
                        asset: MascotAssets.sleepy,
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
    if (s.gender == '男' || s.gender == '女') parts.add(s.gender);
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

  Future<void> _showRosterActions(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('学生档案'),
        message: const Text('可用 WPS / Excel 编辑后导入'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadTemplate(context);
            },
            child: const Text('下载示例表格'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _importExcel(context);
            },
            child: const Text('导入 Excel'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _batchAdd(context);
            },
            child: const Text('粘贴名单'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    try {
      final path = await ctrl.exportStudentTemplateFile();
      await Clipboard.setData(ClipboardData(text: path));
      if (!context.mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('示例表格已生成'),
          content: Text(
            '可用 WPS 或 Excel 打开编辑。\n\n$path\n\n路径已复制到剪贴板。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }

  Future<void> _importExcel(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
        return;
      }

      final result = await ctrl.importStudentsFromBytes(
        bytes,
        fileName: file.name,
      );
      if (!context.mounted) return;

      final parts = <String>[
        if (result.added > 0) '新增 ${result.added} 人',
        if (result.updated > 0) '更新 ${result.updated} 人',
      ];
      final msg = parts.isEmpty
          ? (result.warnings.isNotEmpty
              ? result.warnings.join('\n')
              : '没有导入任何学生')
          : parts.join('，');
      final detail = result.warnings.isEmpty
          ? msg
          : '$msg\n${result.warnings.join('\n')}';

      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(result.total > 0 ? '导入完成' : '未能导入'),
          content: Text(detail),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  Future<void> _batchAdd(BuildContext context) async {
    final ctrl = context.read<ClassController>();
    final text = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('批量添加',
                        style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(AppIcons.close, color: AppTheme.blue),
                  ),
                ],
              ),
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
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
    final address = TextEditingController(text: student?.address ?? '');
    var gender = (student?.gender == '男' || student?.gender == '女')
        ? student!.gender
        : '';
    final selectedRoles = Student.splitRoles(student?.role ?? '').toSet();
    var roleOptions = List<String>.from(ctrl.rolePresets);
    for (final r in selectedRoles) {
      if (!roleOptions.contains(r)) roleOptions.add(r);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student == null ? '添加学生' : '编辑学生',
                            style: Theme.of(ctx).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(AppIcons.close, color: AppTheme.blue),
                        ),
                      ],
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                                controller: name,
                                decoration:
                                    const InputDecoration(labelText: '姓名')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: no,
                                decoration:
                                    const InputDecoration(labelText: '学号')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: group,
                                decoration:
                                    const InputDecoration(labelText: '小组')),
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
                                decoration:
                                    const InputDecoration(labelText: '家长电话'),
                                keyboardType: TextInputType.phone),
                            const SizedBox(height: 10),
                            TextField(
                                controller: address,
                                decoration:
                                    const InputDecoration(labelText: '家庭住址'),
                                minLines: 1,
                                maxLines: 2),
                            const SizedBox(height: 10),
                            TextField(
                                controller: note,
                                decoration:
                                    const InputDecoration(labelText: '备注')),
                            const SizedBox(height: 12),
                            Text('班委（可多选）',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.tertiaryLabel)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilterChip(
                                  label: const Text('无'),
                                  selected: selectedRoles.isEmpty,
                                  onSelected: (_) =>
                                      setState(() => selectedRoles.clear()),
                                ),
                                for (final r in roleOptions)
                                  FilterChip(
                                    label: Text(r),
                                    selected: selectedRoles.contains(r),
                                    onSelected: (on) => setState(() {
                                      if (on) {
                                        selectedRoles.add(r);
                                      } else {
                                        selectedRoles.remove(r);
                                      }
                                    }),
                                  ),
                                ActionChip(
                                  avatar: Icon(AppIcons.plus,
                                      size: 16, color: AppTheme.blue),
                                  label: const Text('添加班委'),
                                  onPressed: () async {
                                    final added =
                                        await _promptCustomRole(ctx);
                                    if (added == null || added.isEmpty) {
                                      return;
                                    }
                                    await ctrl.addRolePreset(added);
                                    setState(() {
                                      if (!roleOptions.contains(added)) {
                                        roleOptions = [
                                          ...roleOptions,
                                          added
                                        ];
                                      }
                                      selectedRoles.add(added);
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('性别',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.tertiaryLabel)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final g in ['男', '女'])
                                  ChoiceChip(
                                    label: Text(g),
                                    selected: gender == g,
                                    onSelected: (_) =>
                                        setState(() => gender = g),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ),
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
                          role: Student.joinRoles(selectedRoles),
                          birthday: birthday.text,
                          address: address.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
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

  Future<String?> _promptCustomRole(BuildContext context) async {
    final text = TextEditingController();
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('添加班委'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: text,
            placeholder: '如：宣传委员',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    final value = text.text.trim();
    text.dispose();
    if (ok != true || value.isEmpty) return null;
    return value;
  }
}
